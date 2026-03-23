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

    // Guard against re-entrant refresh calls (prevents crash during model rebuild)
    property bool refreshInProgress: false

    function refreshEvents() {
        // Prevent re-entrant calls -- if a signal fires while we're already
        // rebuilding, the deferred timer will pick it up instead.
        if (refreshInProgress) {
            return;
        }
        refreshInProgress = true;

        try {
            var now = new Date();
            var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
            var allEvents = [];
            var days = root.daysAhead;
            var maxEvents = Plasmoid.configuration.maxEvents || 50;

            // Deduplication: track events we've already added by a composite key
            // so multi-day or recurring events only appear once.
            var seen = {};

            for (var d = 0; d < days; d++) {
                var date = new Date(today);
                date.setDate(today.getDate() + d);

                var dayEvents = null;
                try {
                    dayEvents = calendarBackend.daysModel.eventsForDate(date);
                } catch (e) {
                    // daysModel may not be ready yet; skip this date
                    continue;
                }

                if (!dayEvents) continue;

                for (var i = 0; i < dayEvents.length; i++) {
                    var ev = dayEvents[i];
                    if (!ev) continue;

                    var title = ev.title || "";
                    var startDt = ev.startDateTime;
                    var endDt = ev.endDateTime;
                    var isAllDay = ev.isAllDay || false;

                    // Build dedup key: title + start ISO + end ISO + allDay flag.
                    // This prevents the same event from appearing on multiple
                    // days when eventsForDate returns it for each day it spans.
                    var startIso = "";
                    var endIso = "";
                    try {
                        startIso = startDt ? startDt.toISOString() : "";
                    } catch (e) {
                        startIso = "";
                    }
                    try {
                        endIso = endDt ? endDt.toISOString() : "";
                    } catch (e) {
                        endIso = "";
                    }

                    var dedupKey = title + "|" + startIso + "|" + endIso + "|" + isAllDay;
                    if (seen[dedupKey]) continue;
                    seen[dedupKey] = true;

                    // For the display date: use the event's actual start date if it
                    // falls within our range, otherwise use today (the event started
                    // before today but spans into our range).
                    var displayDate;
                    if (startDt && !isAllDay) {
                        var evStartDay = new Date(startDt.getFullYear(), startDt.getMonth(), startDt.getDate());
                        displayDate = evStartDay >= today ? evStartDay : new Date(today);
                    } else {
                        displayDate = new Date(date);
                    }

                    allEvents.push({
                        title: title,
                        description: ev.description || "",
                        startDateTime: startDt,
                        endDateTime: endDt,
                        isAllDay: isAllDay,
                        eventColor: ev.eventColor || "",
                        eventType: ev.eventType || "",
                        dateKey: displayDate.toLocaleDateString(Qt.locale(), Locale.ShortFormat),
                        dateObj: displayDate,
                        sortKey: isAllDay ? displayDate.getTime() : (startDt ? startDt.getTime() : displayDate.getTime())
                    });
                    if (allEvents.length >= maxEvents) break;
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

        } finally {
            refreshInProgress = false;
        }
    }

    // Refresh events when the calendar data updates.
    // Use the coalescing timer instead of calling refreshEvents() directly,
    // because agendaUpdated fires once per date and can burst rapidly
    // during Akonadi startup (the duplicate-after-reboot trigger).
    Connections {
        target: calendarBackend.daysModel
        function onAgendaUpdated(updatedDate) {
            refreshCoalesceTimer.restart();
        }
    }

    // Refresh when plugins change
    Connections {
        target: eventPluginsManager
        function onPluginsChanged() {
            refreshCoalesceTimer.restart();
        }
    }

    // Coalescing timer: absorbs rapid-fire agendaUpdated signals into a
    // single deferred refresh.  300 ms is enough for Akonadi to deliver
    // all pending dates after startup, while still feeling responsive.
    Timer {
        id: refreshCoalesceTimer
        interval: 300
        repeat: false
        onTriggered: root.refreshEvents()
    }

    // Periodic refresh (every 5 minutes) -- also handles midnight rollover.
    // We update calendarBackend.today so the DaysModel knows the current
    // date has changed, then refresh.
    Timer {
        id: periodicRefreshTimer
        interval: 300000
        running: true
        repeat: true
        onTriggered: {
            calendarBackend.today = new Date();
            root.refreshEvents();
        }
    }

    // Navigate the calendar backend through the date range to trigger
    // initial data loading from Akonadi plugins.
    Timer {
        id: initialLoadTimer
        interval: 200
        repeat: false
        running: true
        onTriggered: {
            var now = new Date();
            var endDate = new Date(now);
            endDate.setDate(now.getDate() + root.daysAhead);

            calendarBackend.today = now;

            // Display the current month to trigger loading
            calendarBackend.goToYearAndMonth(now.getFullYear(), now.getMonth() + 1);

            // If our range spans into next month(s), navigate there too
            if (endDate.getMonth() !== now.getMonth() || endDate.getFullYear() !== now.getFullYear()) {
                calendarBackend.goToYearAndMonth(endDate.getFullYear(), endDate.getMonth() + 1);
                // Navigate back to current month
                calendarBackend.goToYearAndMonth(now.getFullYear(), now.getMonth() + 1);
            }

            refreshCoalesceTimer.restart();
        }
    }

    switchWidth: Kirigami.Units.gridUnit * 12
    switchHeight: Kirigami.Units.gridUnit * 10

    toolTipMainText: i18n("Calendar Events")
    toolTipSubText: {
        // Guard: eventsList may be empty or stale during transitions
        if (!eventsLoaded || !eventsList || eventsList.length === 0) {
            return eventsLoaded ? i18n("No upcoming events") : i18n("Loading events...");
        }
        var next = eventsList[0];
        if (!next || !next.title) return i18n("No upcoming events");
        if (next.isAllDay) return next.title + " (" + i18n("All day") + ")";
        if (!next.startDateTime) return next.title;
        try {
            return next.title + " \u2013 " + Qt.formatTime(next.startDateTime, Qt.locale().timeFormat(Locale.ShortFormat));
        } catch (e) {
            return next.title;
        }
    }

    compactRepresentation: CompactRepresentation {
        eventCount: root.eventsList ? root.eventsList.length : 0
    }

    fullRepresentation: FullRepresentation {
        eventsList: root.eventsList
        eventsLoaded: root.eventsLoaded
        daysAhead: root.daysAhead

        onRefreshRequested: root.refreshEvents()
    }
}
