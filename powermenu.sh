#!/bin/bash

# Power Menu Script using YAD
# This script creates a GUI power menu with common system actions

# Check if YAD is installed
if ! command -v yad &> /dev/null; then
    zenity --error --text="YAD is not installed. Please install it first:\nsudo apt install yad"
    exit 1
fi

# Create the YAD dialog with power options using buttons
yad --title="Power Menu" \
    --window-icon="system-shutdown" \
    --width=250 \
    --height=50 \
    --center \
    --button="¤ Reboot:10" \
    --button="⚡ Shutdown:20" \
    --button="❌ Cancel:50"

# Get the exit code to determine which button was pressed
ret=$?

# Execute the selected action based on exit code
case $ret in
    10) # Reboot
        if yad --question --title="¤ Reboot" --text="Are you sure you want to reboot?"; then
            systemctl reboot
        fi
        ;;
    20) # Shutdown
        if yad --question --title="⚡ Shutdown" --text="Are you sure you want to shutdown?"; then
            systemctl poweroff
        fi
        ;;
    30) # Logout
        if yad --question --title="Confirm Logout" --text="Are you sure you want to logout?"; then
            # Try different logout methods based on desktop environment
            if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
                gnome-session-quit --logout --no-prompt
            elif [ "$XDG_CURRENT_DESKTOP" = "KDE" ]; then
                qdbus org.kde.ksmserver /KSMServer logout 0 0 0
            elif [ "$XDG_CURRENT_DESKTOP" = "XFCE" ]; then
                xfce4-session-logout --logout
            else
                # Generic logout method
                loginctl terminate-user "$USER"
            fi
        fi
        ;;
    40) # Lock Screen
        # Lock screen using various methods
        if command -v gnome-screensaver-command &> /dev/null; then
            gnome-screensaver-command --lock
        elif command -v xdg-screensaver &> /dev/null; then
            xdg-screensaver lock
        elif command -v loginctl &> /dev/null; then
            loginctl lock-session
        elif command -v xscreensaver-command &> /dev/null; then
            xscreensaver-command -lock
        else
            yad --error --text="No screen locker found"
        fi
        ;;
    50|252|1|*) # Cancel or dialog closed
        exit 0
        ;;
esac
