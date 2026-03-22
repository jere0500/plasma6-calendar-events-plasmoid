/*
    SPDX-FileCopyrightText: 2025 Calendar Events Widget Contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar

PlasmoidItem {
    id: root

    readonly property int daysAhead: Plasmoid.configuration.daysAhead || 14
    readonly property var enabledCalendarPlugins: {
        var plugins = Plasmoid.configuration.enabledPlugins;
        if (plugins && plugins.length > 0) {
            return plugins;
        }
        return ["pimevents"];
    }

    // Shared calendar infrastructure
    PlasmaCalendar.EventPluginsManager {
        id: eventPluginsManager
        enabledPlugins: root.enabledCalendarPlugins
    }

    PlasmaCalendar.Calendar {
        id: calendarBackend
        days: 7
        weeks: 6
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: new Date()

        Component.onCompleted: {
            daysModel.setPluginsManager(eventPluginsManager);
        }
    }

    // Collected events list (built from daysModel.eventsForDate)
    property var eventsList: []
    property bool eventsLoaded: false

    function refreshEvents() {
        var now = new Date();
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        var allEvents = [];
        var days = root.daysAhead;
        var maxEvents = Plasmoid.configuration.maxEvents || 50;

        for (var d = 0; d < days; d++) {
            var date = new Date(today);
            date.setDate(today.getDate() + d);
            var dayEvents = calendarBackend.daysModel.eventsForDate(date);

            if (dayEvents) {
                for (var i = 0; i < dayEvents.length; i++) {
                    var ev = dayEvents[i];
                    allEvents.push({
                        title: ev.title || "",
                        description: ev.description || "",
                        startDateTime: ev.startDateTime,
                        endDateTime: ev.endDateTime,
                        isAllDay: ev.isAllDay || false,
                        eventColor: ev.eventColor || "",
                        eventType: ev.eventType || "",
                        dateKey: date.toLocaleDateString(Qt.locale(), Locale.ShortFormat),
                        dateObj: new Date(date),
                        sortKey: ev.isAllDay ? date.getTime() : ev.startDateTime.getTime()
                    });
                    if (allEvents.length >= maxEvents) break;
                }
            }
            if (allEvents.length >= maxEvents) break;
        }

        // Sort: by date, then all-day first, then by start time
        allEvents.sort(function(a, b) {
            var dayDiff = a.dateObj.getTime() - b.dateObj.getTime();
            if (dayDiff !== 0) return dayDiff;
            if (a.isAllDay && !b.isAllDay) return -1;
            if (!a.isAllDay && b.isAllDay) return 1;
            return a.sortKey - b.sortKey;
        });

        root.eventsList = allEvents;
        root.eventsLoaded = true;
    }

    // Refresh events when the calendar data updates
    Connections {
        target: calendarBackend.daysModel
        function onAgendaUpdated(updatedDate) {
            root.refreshEvents();
        }
    }

    // Refresh when plugins change
    Connections {
        target: eventPluginsManager
        function onPluginsChanged() {
            refreshDelayTimer.restart();
        }
    }

    // Periodic refresh (every 5 minutes)
    Timer {
        id: periodicRefreshTimer
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.refreshEvents()
    }

    // Slight delay after plugin changes to let data load
    Timer {
        id: refreshDelayTimer
        interval: 500
        repeat: false
        onTriggered: root.refreshEvents()
    }

    // Also navigate the calendar backend through the date range to trigger data loading
    Timer {
        id: initialLoadTimer
        interval: 200
        repeat: false
        running: true
        onTriggered: {
            // Navigate through months that are in our range to trigger data loading
            var now = new Date();
            var endDate = new Date(now);
            endDate.setDate(now.getDate() + root.daysAhead);

            calendarBackend.today = now;

            // Make sure the current month is displayed to trigger loading
            calendarBackend.goToYearAndMonth(now.getFullYear(), now.getMonth() + 1);

            // If our range spans into next month(s), navigate there too
            if (endDate.getMonth() !== now.getMonth() || endDate.getFullYear() !== now.getFullYear()) {
                calendarBackend.goToYearAndMonth(endDate.getFullYear(), endDate.getMonth() + 1);
                // Navigate back to current month
                calendarBackend.goToYearAndMonth(now.getFullYear(), now.getMonth() + 1);
            }

            refreshDelayTimer.restart();
        }
    }

    switchWidth: Kirigami.Units.gridUnit * 12
    switchHeight: Kirigami.Units.gridUnit * 10

    toolTipMainText: i18n("Calendar Events")
    toolTipSubText: {
        if (!eventsLoaded) return i18n("Loading events...");
        if (eventsList.length === 0) return i18n("No upcoming events");
        var next = eventsList[0];
        if (next.isAllDay) return next.title + " (" + i18n("All day") + ")";
        return next.title + " - " + Qt.formatTime(next.startDateTime, Qt.locale().timeFormat(Locale.ShortFormat));
    }

    compactRepresentation: CompactRepresentation {
        eventCount: root.eventsList.length
    }

    fullRepresentation: FullRepresentation {
        eventsList: root.eventsList
        eventsLoaded: root.eventsLoaded
        daysAhead: root.daysAhead

        onRefreshRequested: root.refreshEvents()
    }
}
