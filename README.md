# Calendar Events Plasmoid

> AI-generated KDE Plasma 6 plasmoid displaying upcoming calendar events from KDE PIM calendars.

## Disclaimer

**This project was created by AI (Claude Opus 4.6).** While functional, it may have limitations:

- No author attribution (generic "Calendar Events Widget Contributors")
- Configuration may not integrate perfectly with your existing KDE setup
- No comprehensive error handling beyond basic QML protections
- Performance optimizations may need manual tuning

**Use at your own risk.** Review the code before production use.

## Features

- Displays upcoming events from your Akonadi/KDE PIM calendars
- Shows holiday and astronomical events (configurable)
- Supports low-resolution displays with graceful text elision
- Adapts to small widget sizes (minimum 10x8 grid units in popup)
- Automatic refresh every 5 minutes + on-demand
- Panel icon with event count badge

## Installation

```bash
# Install
./install.sh install

# Or manually
kpackagetool6 -t Plasma/Applet -i package/

# Update after changes
kpackagetool6 -t Plasma/Applet -u package/

# Uninstall
kpackagetool6 -t Plasma/Applet -r org.kde.plasma.calendarevents
```

## Usage

**Add to panel**:
1. Right-click panel → *Add plasma applet*
2. Search for "Calendar Events"
3. Double-click to view full popup

**Or standalone window**:
```bash
plasmawindowed org.kde.plasma.calendarevents
```

## Configuration

Right-click the widget → *Configure Widget*:

| Setting | Default | Range |
|--------|---------|-------|
| Days ahead | 14 | 1-90 |
| Max events | 50 | 5-200 |
| PIM Events | ✓ | - |
| Holidays | - | - |
| Astronomical | 0 | - |

At least one plugin must be enabled.

## Project Structure

```
package/
├── contents/
│   ├── ui/
│   │   ├── main.qml                # Entry point (PlasmoidItem)
│   │   ├── FullRepresentation.qml  # Popup event list view
│   │   ├── CompactRepresentation.qml  # Panel icon
│   │   └── configGeneral.qml       # Configuration UI
│   └── config/
│       ├── config.qml              # Config tab definitions
│       └── main.xml                # KConfig XT schema
├── metadata.json                   # Package manifest
└── install.sh                      # Installation helper
```

## Requirements

- KDE Plasma 6.0+
- Qt 6
- KDE frameworks (Kirigami components)
- Akonadi with at least one calendar resource

## Testing

```bash
# Test in standalone window
./install.sh test

# Alternative viewer
plasmoidviewer -a org.kde.plasma.calendarevents

# With QML debugging
QT_LOGGING_RULES="qt.qml.binding.removal.info=true" \
   plasmawindowed org.kde.plasma.calendarevents
```

## API Usage Example

From your QML code:

```qml
import org.kde.plasma.workspace.calendar as PlasmaCalendar

EventPluginsManager {
    enabledPlugins: ["pimevents"]
}

Calendar {
    daysModel.setPluginsManager(eventPluginsManager)
}

// Get upcoming events
var events = daysModel.eventsForDate(new Date())
```

## Contributing

This project is AI-generated and not actively maintained, fork, change, and distribute at your will
