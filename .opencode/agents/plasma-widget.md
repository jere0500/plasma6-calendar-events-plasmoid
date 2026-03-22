# Plasma 6 Calendar Events Widget Agent

## Project Context

This is a KDE Plasma 6 plasmoid (widget) that displays upcoming calendar events from KDE PIM (Akonadi) calendars. It is a **pure QML widget** (no C++ plugin) that uses Plasma's built-in calendar infrastructure.

## Technology Stack

- **KDE Plasma 6** (minimum API version 6.0)
- **Qt 6 / QML** (unversioned imports, no version numbers in import statements)
- **org.kde.plasma.workspace.calendar** module (Calendar, DaysModel, EventPluginsManager, EventDataDecorator)
- **KPackage** packaging (installed via `kpackagetool6`, no CMake compilation needed)
- Widget ID: `org.kde.plasma.calendarevents`

## Project Structure

```
package/
├── contents/
│   ├── ui/
│   │   ├── main.qml                # PlasmoidItem entry point
│   │   ├── FullRepresentation.qml  # Event list popup view
│   │   ├── CompactRepresentation.qml # Panel icon with badge
│   │   ├── EventItem.qml           # Single event delegate
│   │   └── configGeneral.qml       # Configuration UI
│   └── config/
│       ├── config.qml              # Config tabs
│       └── main.xml                # KConfig XT schema
└── metadata.json
```

## Plasma 6 QML Rules (CRITICAL)

1. **Root element MUST be `PlasmoidItem`** (not `Item`)
2. **Import statements MUST NOT have version numbers** in Plasma 6:
   ```qml
   // CORRECT for Plasma 6:
   import QtQuick
   import QtQuick.Layouts
   import org.kde.plasma.plasmoid
   import org.kde.plasma.components as PlasmaComponents
   import org.kde.plasma.extras as PlasmaExtras
   import org.kde.kirigami as Kirigami
   import org.kde.plasma.workspace.calendar as PlasmaCalendar
   
   // WRONG - do NOT use version numbers:
   // import QtQuick 2.0
   // import org.kde.plasma.plasmoid 2.0
   ```
3. **Use `Kirigami.Units`** instead of `PlasmaCore.Units` for spacing/sizing
4. **Use `Kirigami.Icon`** instead of `PlasmaCore.IconItem`
5. **Use `Kirigami.Theme`** for theme colors
6. **Config pages** should use appropriate QQC2/Kirigami form layouts

## Calendar Events API Reference

### EventPluginsManager
```qml
PlasmaCalendar.EventPluginsManager {
    id: eventPluginsManager
    enabledPlugins: ["pimevents"]  // Also: "holidaysevents", "astronomicalevents"
}
```
- `enabledPlugins: QStringList` - list of plugin IDs to activate
- `model: QAbstractListModel` (read-only) - model of available plugins
- Signal: `pluginsChanged()`

### Calendar Backend
```qml
PlasmaCalendar.Calendar {
    id: calendarBackend
    days: 7
    weeks: 6
    firstDayOfWeek: Qt.locale().firstDayOfWeek
    today: new Date()
    
    Component.onCompleted: {
        daysModel.setPluginsManager(eventPluginsManager)
    }
}
```
Properties:
- `displayedDate: QDateTime` (read/write)
- `today: QDateTime` (read/write)
- `daysModel: DaysModel` (read-only, constant)
- `year: int`, `month: int`, `monthName: QString` (read-only)
- Methods: `nextMonth()`, `previousMonth()`, `resetToToday()`, `goToMonth(int)`, `goToYear(int)`

### DaysModel (key for event access)
```qml
// Get events for a specific date:
var events = calendarBackend.daysModel.eventsForDate(someDate)
// Returns QVariantList of EventDataDecorator objects
```
- `eventsForDate(date: QDate): QVariantList` - returns list of EventDataDecorator
- `setPluginsManager(manager: EventPluginsManager)` - connect plugins
- Signal: `agendaUpdated(updatedDate: QDate)` - fires when events are ready for a date

### EventDataDecorator Properties
Each event object returned by `eventsForDate()` has these read-only properties:
- `title: QString` - event title/summary
- `description: QString` - event description
- `startDateTime: QDateTime` - start time
- `endDateTime: QDateTime` - end time
- `isAllDay: bool` - all-day event flag
- `isMinor: bool` - minor event flag
- `eventColor: QString` - calendar color (hex string)
- `eventType: QString` - type of event

## Available Calendar Plugins on System
Located at `/usr/lib/qt6/plugins/plasmacalendarplugins/`:
- `pimevents.so` - Akonadi/KDE PIM calendar events (Google Calendar, local calendars, etc.)
- `holidaysevents.so` - Holiday calendar events
- `astronomicalevents.so` - Astronomical events (moon phases, etc.)
- `alternatecalendar.so` - Alternate calendar system

## metadata.json Format
```json
{
    "KPlugin": {
        "Authors": [{ "Email": "...", "Name": "..." }],
        "Category": "Date and Time",
        "Description": "Shows upcoming calendar events from KDE PIM",
        "Icon": "office-calendar",
        "Id": "org.kde.plasma.calendarevents",
        "Name": "Calendar Events",
        "Version": "1.0"
    },
    "X-Plasma-API-Minimum-Version": "6.0",
    "KPackageStructure": "Plasma/Applet"
}
```

## Installation & Testing

```bash
# Install the widget (from project root)
kpackagetool6 -t Plasma/Applet -i package/

# Update after changes
kpackagetool6 -t Plasma/Applet -u package/

# Remove
kpackagetool6 -t Plasma/Applet -r org.kde.plasma.calendarevents

# Test in standalone window
plasmawindowed org.kde.plasma.calendarevents

# Alternative test viewer (if available)
plasmoidviewer -a org.kde.plasma.calendarevents
```

## Configuration System

### config/main.xml (KConfig XT schema)
Defines serialized configuration keys:
- `daysAhead: int` (default: 14) - how many days ahead to show events
- `enabledPlugins: StringList` (default: "pimevents") - which calendar plugins to use
- `showAllDayEvents: bool` (default: true)
- `maxEvents: int` (default: 50) - maximum events to display

### config/config.qml
Defines configuration tabs pointing to QML pages.

### ui/configGeneral.qml
The actual configuration form layout.

## Widget Behavior

1. **Compact view** (in panel): Shows a calendar icon; optionally shows today's event count as badge
2. **Full view** (popup on click): Shows a scrollable list of upcoming events:
   - Events grouped by date with date headers
   - Each event shows: colored dot (calendar color), time range, title
   - All-day events shown at top of each date group
   - "No upcoming events" placeholder when empty
3. Events auto-refresh when `agendaUpdated` signal fires
4. Clicking the widget header area can open the KDE calendar application

## Design Guidelines

- Follow KDE HIG (Human Interface Guidelines)
- Use `PlasmaExtras.Heading` for section headers
- Use `PlasmaComponents.Label` for text
- Use `Kirigami.Units.smallSpacing` / `Kirigami.Units.largeSpacing` for consistent spacing
- Use `Kirigami.Theme` colors for consistency with Plasma theme
- Support both horizontal and vertical panel placement
- Widget popup size: ~300x400 units default
