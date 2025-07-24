#!/bin/bash

# Thorium Browser Launcher Script
# Checks if Thorium browser exists, launches it or runs installer

THORIUM_PATH="/usr/bin/thorium-browser"
INSTALL_SCRIPT="/home/x/Thorium-Install.sh"

if [ -f "$THORIUM_PATH" ]; then
    echo "Thorium browser found. Launching..."
    exec nohup "$THORIUM_PATH"
else
    echo "Thorium browser not found. Running installer..."
    exec "$INSTALL_SCRIPT"
fi

