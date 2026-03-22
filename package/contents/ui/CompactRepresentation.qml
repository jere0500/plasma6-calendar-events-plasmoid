/*
    SPDX-FileCopyrightText: 2025 Calendar Events Widget Contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

MouseArea {
    id: compactRoot

    property int eventCount: 0

    hoverEnabled: true
    onClicked: root.expanded = !root.expanded

    Kirigami.Icon {
        id: calendarIcon
        anchors.fill: parent
        source: "office-calendar"
        active: compactRoot.containsMouse
    }

    // Event count badge - only when there are events
    Rectangle {
        id: badge
        visible: compactRoot.eventCount > 0
        width: Math.max(badgeLabel.implicitWidth + Kirigami.Units.smallSpacing * 2,
                        height)
        height: Math.max(badgeLabel.implicitHeight + Kirigami.Units.smallSpacing,
                         Kirigami.Units.iconSizes.small * 0.6)
        // Cap badge size relative to icon
        readonly property real maxSize: parent.height * 0.45
        scale: width > maxSize ? maxSize / width : 1.0

        anchors {
            top: parent.top
            right: parent.right
            topMargin: -Kirigami.Units.smallSpacing
            rightMargin: -Kirigami.Units.smallSpacing
        }

        radius: height / 2
        color: Kirigami.Theme.highlightColor

        Kirigami.Theme.colorSet: Kirigami.Theme.Selection

        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: compactRoot.eventCount > 99 ? "99+" : compactRoot.eventCount
            color: Kirigami.Theme.highlightedTextColor
            font.pixelSize: Math.max(parent.height * 0.6, 1)
            font.bold: true
        }
    }
}
