/*
    SPDX-FileCopyrightText: 2025 Calendar Events Widget Contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

Item {
    id: fullRoot

    property var eventsList: []
    property bool eventsLoaded: false
    property int daysAhead: 14

    signal refreshRequested()

    // Adaptive sizing: small minimum for low-res, sensible preferred
    Layout.minimumWidth: Kirigami.Units.gridUnit * 10
    Layout.minimumHeight: Kirigami.Units.gridUnit * 8
    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
    Layout.preferredHeight: Kirigami.Units.gridUnit * 24

    // Build a flat ListModel with date headers interleaved with events
    ListModel {
        id: displayModel
    }

    // Defer model rebuild so the ListView finishes its current frame before
    // we clear + repopulate.  This prevents the crash that occurred when
    // displayModel.clear() destroyed delegate items whose bindings were
    // still being evaluated (e.g. tooltip text, time labels).
    onEventsListChanged: rebuildTimer.restart()

    Timer {
        id: rebuildTimer
        interval: 0  // execute on next event-loop tick
        repeat: false
        onTriggered: rebuildModel()
    }

    function rebuildModel() {
        var newItems = [];

        var lastDateKey = "";
        var now = new Date();
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        var tomorrow = new Date(today);
        tomorrow.setDate(today.getDate() + 1);

        var list = fullRoot.eventsList;
        if (!list) list = [];

        for (var i = 0; i < list.length; i++) {
            var ev = list[i];
            if (!ev) continue;

            if (ev.dateKey !== lastDateKey) {
                var dateObj = ev.dateObj;
                var headerText;
                if (dateObj && dateObj.getTime() === today.getTime()) {
                    headerText = i18n("Today");
                } else if (dateObj && dateObj.getTime() === tomorrow.getTime()) {
                    headerText = i18n("Tomorrow");
                } else if (dateObj) {
                    headerText = dateObj.toLocaleDateString(Qt.locale(), Locale.LongFormat);
                } else {
                    headerText = "";
                }

                newItems.push({
                    isHeader: true,
                    headerText: headerText,
                    itemTitle: "",
                    itemDescription: "",
                    itemStartDateTime: "",
                    itemEndDateTime: "",
                    itemIsAllDay: false,
                    itemEventColor: ""
                });
                lastDateKey = ev.dateKey;
            }

            var startIso = "";
            var endIso = "";
            try { startIso = ev.startDateTime ? ev.startDateTime.toISOString() : ""; } catch(e) { startIso = ""; }
            try { endIso = ev.endDateTime ? ev.endDateTime.toISOString() : ""; } catch(e) { endIso = ""; }

            newItems.push({
                isHeader: false,
                headerText: "",
                itemTitle: ev.title || "",
                itemDescription: ev.description || "",
                itemStartDateTime: startIso,
                itemEndDateTime: endIso,
                itemIsAllDay: ev.isAllDay || false,
                itemEventColor: ev.eventColor || ""
            });
        }

        // Atomic swap: clear and repopulate in one batch.
        displayModel.clear();
        for (var j = 0; j < newItems.length; j++) {
            displayModel.append(newItems[j]);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header with title and refresh
        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    level: 1
                    text: i18n("Upcoming Events")
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh-symbolic"
                    display: PlasmaComponents.AbstractButton.IconOnly

                    PlasmaComponents.ToolTip.text: i18n("Refresh")
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

                    onClicked: fullRoot.refreshRequested()
                }
            }
        }

        // Loading state
        PlasmaComponents.BusyIndicator {
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2
            visible: !fullRoot.eventsLoaded
            running: visible
        }

        // Empty state
        PlasmaExtras.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: fullRoot.eventsLoaded && displayModel.count === 0
            iconName: "office-calendar"
            text: i18n("No upcoming events")
            explanation: i18n("Events from the next %1 days will appear here", fullRoot.daysAhead)
        }

        // Event list
        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: fullRoot.eventsLoaded && displayModel.count > 0

            PlasmaComponents.ScrollBar.horizontal.policy: PlasmaComponents.ScrollBar.AlwaysOff

            ListView {
                id: eventListView

                clip: true
                model: displayModel
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds

                // Cache delegates slightly beyond the visible area
                // so rapid model swaps don't create/destroy while painting.
                cacheBuffer: Math.max(height, Kirigami.Units.gridUnit * 10)

                delegate: Item {
                    id: delegateItem
                    width: eventListView.width
                    // Guard: if isHeader is undefined (model clearing), fall back to 0
                    implicitHeight: {
                        if (typeof delegateItem.isHeader === "undefined") return 0;
                        return delegateItem.isHeader ? headerCol.implicitHeight : eventItemDelegate.implicitHeight;
                    }

                    required property int index
                    required property bool isHeader
                    required property string headerText
                    required property string itemTitle
                    required property string itemDescription
                    required property string itemStartDateTime
                    required property string itemEndDateTime
                    required property bool itemIsAllDay
                    required property string itemEventColor

                    // Date section header
                    ColumnLayout {
                        id: headerCol
                        visible: delegateItem.isHeader
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: Kirigami.Units.smallSpacing
                            rightMargin: Kirigami.Units.smallSpacing
                        }
                        spacing: 0

                        // Separator line (not on very first item)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            visible: delegateItem.index > 0
                            color: Kirigami.Theme.textColor
                            opacity: 0.15
                            Layout.bottomMargin: Kirigami.Units.smallSpacing
                        }

                        PlasmaExtras.Heading {
                            Layout.fillWidth: true
                            level: 4
                            text: delegateItem.headerText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            opacity: 0.8
                            bottomPadding: Kirigami.Units.smallSpacing
                        }
                    }

                    // Event row
                    Item {
                        id: eventItemDelegate
                        visible: !delegateItem.isHeader
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                        }
                        implicitHeight: eventRow.implicitHeight + Kirigami.Units.smallSpacing

                        // Hover highlight
                        Rectangle {
                            anchors.fill: parent
                            color: Kirigami.Theme.highlightColor
                            opacity: eventMouse.containsMouse ? 0.1 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: Kirigami.Units.shortDuration }
                            }
                        }

                        MouseArea {
                            id: eventMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        RowLayout {
                            id: eventRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: Kirigami.Units.smallSpacing
                                rightMargin: Kirigami.Units.smallSpacing
                                topMargin: Math.round(Kirigami.Units.smallSpacing / 2)
                            }
                            spacing: Kirigami.Units.smallSpacing

                            // Color dot
                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: Math.round(eventTitleLabel.implicitHeight / 2 - height / 2)
                                Layout.preferredWidth: Kirigami.Units.smallSpacing * 2
                                Layout.preferredHeight: Layout.preferredWidth
                                radius: width / 2
                                color: {
                                    if (delegateItem.itemEventColor) {
                                        return Kirigami.ColorUtils.linearInterpolation(
                                            delegateItem.itemEventColor,
                                            Kirigami.Theme.textColor, 0.05);
                                    }
                                    return Kirigami.Theme.highlightColor;
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                // Time label
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    visible: !delegateItem.itemIsAllDay && delegateItem.itemStartDateTime !== ""
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.7
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    text: {
                                        if (delegateItem.itemIsAllDay || delegateItem.itemStartDateTime === "") return "";
                                        try {
                                            var fmt = Qt.locale().timeFormat(Locale.ShortFormat);
                                            var startDt = new Date(delegateItem.itemStartDateTime);
                                            var endDt = new Date(delegateItem.itemEndDateTime);
                                            if (isNaN(startDt.getTime())) return "";
                                            var result = Qt.formatTime(startDt, fmt);
                                            if (!isNaN(endDt.getTime())) {
                                                result += " \u2013 " + Qt.formatTime(endDt, fmt);
                                            }
                                            return result;
                                        } catch (e) {
                                            return "";
                                        }
                                    }
                                }

                                // All-day label
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    visible: delegateItem.itemIsAllDay
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.7
                                    maximumLineCount: 1
                                    text: i18n("All day")
                                }

                                // Title
                                PlasmaComponents.Label {
                                    id: eventTitleLabel
                                    Layout.fillWidth: true
                                    text: delegateItem.itemTitle
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        // Tooltip with safe accessors
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.visible: eventMouse.containsMouse && delegateItem.itemTitle !== ""
                        PlasmaComponents.ToolTip.text: {
                            if (!delegateItem.itemTitle) return "";
                            var lines = [];
                            lines.push(delegateItem.itemTitle);
                            if (delegateItem.itemIsAllDay) {
                                lines.push(i18n("All day"));
                            } else if (delegateItem.itemStartDateTime !== "") {
                                try {
                                    var fmt = Qt.locale().timeFormat(Locale.ShortFormat);
                                    var s = new Date(delegateItem.itemStartDateTime);
                                    var e = new Date(delegateItem.itemEndDateTime);
                                    if (!isNaN(s.getTime())) {
                                        var timeStr = Qt.formatTime(s, fmt);
                                        if (!isNaN(e.getTime())) {
                                            timeStr += " \u2013 " + Qt.formatTime(e, fmt);
                                        }
                                        lines.push(timeStr);
                                    }
                                } catch (err) {
                                    // Silently skip time display on error
                                }
                            }
                            if (delegateItem.itemDescription) {
                                lines.push(delegateItem.itemDescription);
                            }
                            return lines.join("\n");
                        }
                    }
                }
            }
        }
    }
}
