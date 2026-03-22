/*
    SPDX-FileCopyrightText: 2025 Calendar Events Widget Contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.workspace.calendar as PlasmaCalendar

KCM.SimpleKCM {
    id: configPage

    property alias cfg_daysAhead: daysAheadSpinBox.value
    property alias cfg_maxEvents: maxEventsSpinBox.value
    property var cfg_enabledPlugins: []

    // Load enabled plugins from saved config
    Component.onCompleted: {
        cfg_enabledPlugins = plasmoid.configuration.enabledPlugins || ["pimevents"];
    }

    PlasmaCalendar.EventPluginsManager {
        id: availablePluginsManager
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.SpinBox {
            id: daysAheadSpinBox
            Kirigami.FormData.label: i18n("Days ahead:")
            from: 1
            to: 90
            stepSize: 1
        }

        QQC2.SpinBox {
            id: maxEventsSpinBox
            Kirigami.FormData.label: i18n("Maximum events:")
            from: 5
            to: 200
            stepSize: 5
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Calendar Plugins")
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Enabled sources:")
            Kirigami.FormData.buddyFor: pimCheckBox
            spacing: Kirigami.Units.smallSpacing

            QQC2.CheckBox {
                id: pimCheckBox
                text: i18n("PIM Events (Akonadi calendars)")
                checked: cfg_enabledPlugins.indexOf("pimevents") >= 0
                onToggled: updatePluginList()
            }

            QQC2.CheckBox {
                id: holidaysCheckBox
                text: i18n("Holidays")
                checked: cfg_enabledPlugins.indexOf("holidaysevents") >= 0
                onToggled: updatePluginList()
            }

            QQC2.CheckBox {
                id: astronomicalCheckBox
                text: i18n("Astronomical Events")
                checked: cfg_enabledPlugins.indexOf("astronomicalevents") >= 0
                onToggled: updatePluginList()
            }
        }
    }

    function updatePluginList() {
        var plugins = [];
        if (pimCheckBox.checked) plugins.push("pimevents");
        if (holidaysCheckBox.checked) plugins.push("holidaysevents");
        if (astronomicalCheckBox.checked) plugins.push("astronomicalevents");

        // Ensure at least one plugin is enabled
        if (plugins.length === 0) {
            plugins.push("pimevents");
            pimCheckBox.checked = true;
        }

        cfg_enabledPlugins = plugins;
    }
}
