#!/bin/bash
# Helper script to install/update/remove the Calendar Events plasmoid
set -e

WIDGET_ID="org.kde.plasma.calendarevents"
PACKAGE_DIR="$(dirname "$0")/package"

case "${1:-install}" in
    install)
        echo "Installing $WIDGET_ID..."
        kpackagetool6 -t Plasma/Applet -i "$PACKAGE_DIR" 2>/dev/null || {
            echo "Already installed, updating instead..."
            kpackagetool6 -t Plasma/Applet -u "$PACKAGE_DIR"
        }
        echo "Done. Test with: plasmawindowed $WIDGET_ID"
        ;;
    update)
        echo "Updating $WIDGET_ID..."
        kpackagetool6 -t Plasma/Applet -u "$PACKAGE_DIR"
        echo "Done. You may need to restart plasmashell: kquitapp6 plasmashell && kstart plasmashell"
        ;;
    remove)
        echo "Removing $WIDGET_ID..."
        kpackagetool6 -t Plasma/Applet -r "$WIDGET_ID"
        echo "Done."
        ;;
    test)
        echo "Updating and testing $WIDGET_ID..."
        kpackagetool6 -t Plasma/Applet -u "$PACKAGE_DIR" 2>/dev/null || \
            kpackagetool6 -t Plasma/Applet -i "$PACKAGE_DIR"
        plasmawindowed "$WIDGET_ID"
        ;;
    *)
        echo "Usage: $0 {install|update|remove|test}"
        exit 1
        ;;
esac
