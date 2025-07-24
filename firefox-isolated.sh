#!/bin/bash

# Firefox Isolated Instance Script (Zenity Version)
# Downloads and runs Firefox AppImage in non-persistent mode

export GTK_THEME=Orchis:dark

set -e  # Exit on any error

# Configuration
APPIMAGE_URL="https://github.com/srevinsaju/Firefox-Appimage/releases/download/firefox-esr/firefox-esr-128.12.r20250616190003-x86_64.AppImage"
APPIMAGE_NAME="firefox-esr-128.12.r20250616190003-x86_64.AppImage"
WORK_DIR="/tmp/firefox-isolated"
APPIMAGE_PATH="$WORK_DIR/$APPIMAGE_NAME"

# Function to print output
print_status() {
    echo "[INFO] $1"
}

print_success() {
    echo "[SUCCESS] $1"
}

print_warning() {
    echo "[WARNING] $1"
}

print_error() {
    echo "[ERROR] $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    if ! command_exists zenity; then
        missing_deps+=("zenity")
    fi
    
    if ! command_exists curl && ! command_exists wget; then
        missing_deps+=("curl or wget")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_status "Install missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            if [[ "$dep" == "zenity" ]]; then
                print_status "  sudo apt install zenity"
            elif [[ "$dep" == "curl or wget" ]]; then
                print_status "  sudo apt install curl (or wget)"
            fi
        done
        exit 1
    fi
}

# Function to download Firefox AppImage with Zenity progress
download_firefox() {
    if [[ -f "$APPIMAGE_PATH" ]]; then
        print_status "Firefox AppImage already exists at $APPIMAGE_PATH"
        return 0
    fi

    print_status "Downloading Firefox AppImage with progress dialog..."
    
    # Download with Zenity progress
    if command_exists curl; then
        curl -L "$APPIMAGE_URL" -o "$APPIMAGE_PATH" 2>&1 | \
        stdbuf -oL tr '\r' '\n' | \
        grep -oE '[0-9]+\.[0-9]+' | \
        cut -d'.' -f1 | \
        zenity --progress \
            --title="Firefox Isolated" \
            --text="Downloading Firefox AppImage..." \
            --width=400 \
            --auto-close
        
        download_result=${PIPESTATUS[0]}
        
    elif command_exists wget; then
        # For wget, we'll use a different approach since it has different progress output
        zenity --progress \
            --title="Firefox Isolated - Download" \
            --text="Downloading Firefox AppImage..." \
            --width=400 \
            --pulsate \
            --auto-close &
        
        local zenity_pid=$!
        
        wget "$APPIMAGE_URL" -O "$APPIMAGE_PATH" 2>/dev/null
        download_result=$?
        
        kill $zenity_pid 2>/dev/null || true
        
    else
        print_error "Neither curl nor wget found. Please install one of them."
        zenity --error --text="Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    if [[ $download_result -eq 0 ]]; then
        print_success "Firefox AppImage downloaded successfully"
    else
        print_error "Failed to download Firefox AppImage"
        zenity --error --text="Failed to download Firefox AppImage"
        exit 1
    fi
}

# Function to make AppImage executable
make_executable() {
    print_status "Making AppImage executable..."
    chmod +x "$APPIMAGE_PATH"
    
    if [[ $? -eq 0 ]]; then
        print_success "AppImage made executable"
    else
        print_error "Failed to make AppImage executable"
        zenity --error --text="Failed to make AppImage executable"
        exit 1
    fi
}

# Function to create temporary profile
create_temp_profile() {
    local temp_profile="$WORK_DIR/profile"
    mkdir -p "$temp_profile"
    print_status "Created temporary profile directory: $temp_profile"
    echo "$temp_profile"
}

# Function to initialize temporary profile
initialize_profile() {
    local temp_profile="$1"
    
    print_status "Initializing temporary profile..."
    
    # Create basic profile structure
    mkdir -p "$temp_profile"
    
    # Create a minimal prefs.js to ensure Firefox recognizes the profile
    cat > "$temp_profile/prefs.js" << 'EOF'
// Firefox preferences for isolated instance
user_pref("browser.rights.3.shown", true);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("browser.migration.version", 1);
user_pref("browser.newtabpage.introShown", true);
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.clearOnShutdown.cache", true);
user_pref("privacy.clearOnShutdown.cookies", true);
user_pref("privacy.clearOnShutdown.downloads", true);
user_pref("privacy.clearOnShutdown.formdata", true);
user_pref("privacy.clearOnShutdown.history", true);
user_pref("privacy.clearOnShutdown.sessions", true);
EOF
    
    # Create times.json to mark profile as initialized
    cat > "$temp_profile/times.json" << EOF
{
  "created": $(date +%s)000,
  "firstUse": null
}
EOF
    
    print_success "Temporary profile initialized"
}

# Function to cleanup problematic directories
cleanup_problematic_dirs() {
    # Clean up any directories created due to previous issues
    local user_home="$HOME"
    
    print_status "Checking for any problematic directories..."
    
    # Look for directories that might have been created with escape sequences
    find "$user_home" -maxdepth 1 -type d -name "*INFO*" -o -name "*Created*" -o -name "*temporary*" 2>/dev/null | while IFS= read -r dir; do
        if [[ -d "$dir" && "$dir" != "$user_home" ]]; then
            print_status "Removing problematic directory: $(basename "$dir")"
            rm -rf "$dir"
        fi
    done
    
    print_success "Cleanup completed"
}

# Function to cleanup all files and AppImage portable directories
cleanup_all_files() {
    if [[ -d "$WORK_DIR" ]]; then
        print_status "Cleaning up all application files..."
        rm -rf "$WORK_DIR"
        print_success "Application directory cleaned up"
    fi
    
    # Clean up AppImage portable directories that may have been created in original location
    # These would be created alongside the AppImage if our environment override fails
    local appimage_dir=$(dirname "$APPIMAGE_PATH")
    local appimage_name=$(basename "$APPIMAGE_PATH")
    local appimage_base="${appimage_name%.*}"
    local portable_home="${appimage_dir}/${appimage_base}.home"
    local portable_config="${appimage_dir}/${appimage_base}.config"
    
    if [[ -d "$portable_home" ]]; then
        print_status "Cleaning up AppImage portable home directory..."
        rm -rf "$portable_home"
        print_success "Portable home directory cleaned up"
    fi
    
    if [[ -d "$portable_config" ]]; then
        print_status "Cleaning up AppImage portable config directory..."
        rm -rf "$portable_config"
        print_success "Portable config directory cleaned up"
    fi
    
    # Clean up any problematic directories created due to output issues
    cleanup_problematic_dirs
}

# Function to show cleanup dialog
show_cleanup_dialog() {
    if zenity --question \
        --title="Firefox Isolated" \
        --text="Firefox session ended.\n\nDelete Firefox AppImage and all application files?" \
        --width=400; then
        cleanup_all_files
    else
        print_status "Files kept in $WORK_DIR"
    fi
}

# Function to launch Firefox
launch_firefox() {
    local temp_profile="$1"
    
    print_status "Launching Firefox in isolated mode..."
    print_warning "This Firefox instance will not save any data (cookies, history, downloads, etc.)"
    
    # Store original HOME to restore later
    local original_home="$HOME"
    
    # Create a temporary home directory within our work directory to isolate AppImage
    local temp_home="$WORK_DIR/isolated_home"
    mkdir -p "$temp_home"
    
    # Set environment variables to redirect AppImage portable directories
    # This prevents the AppImage from creating .home and .config in the original location
    export HOME="$temp_home"
    export XDG_CONFIG_HOME="$temp_home/.config"
    export XDG_CACHE_HOME="$temp_home/.cache"
    export XDG_DATA_HOME="$temp_home/.local/share"
    
    # Ensure the override directories exist
    mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
    
    # Launch Firefox with the absolute path to the profile (not affected by HOME change)
    # Using --new-instance for better isolation
    "$APPIMAGE_PATH" --profile "$temp_profile" --new-instance /tmp/start-firefox.html
    
    # Restore original environment
    export HOME="$original_home"
    unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME
    
    print_success "Firefox session ended."
}

# Main execution
main() {
    print_status "Starting Firefox Isolated Instance Script"
    
    # Check dependencies
    check_dependencies
    
    # Create work directory
    mkdir -p "$WORK_DIR"
    
    # Download Firefox AppImage
    download_firefox
    
    # Make it executable
    make_executable
    
    # Create temporary profile
    TEMP_PROFILE=$(create_temp_profile)
    
    # Initialize the profile
    initialize_profile "$TEMP_PROFILE"
    
    # Launch Firefox
    launch_firefox "$TEMP_PROFILE"
    
    # Show cleanup dialog after Firefox closes
    show_cleanup_dialog
}

# Create a simple HTML start page to avoid file:// URLs
    cat > "/tmp/start-firefox.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>🦊 Firefox Isolated Session</title>
    <style>
        body { 
            fontfamily: Arial, sans-serif; 
            background: #222222; 
            color: #D6D6D6; 
            text-align: center; 
            padding: 50px; 
        }
        h1 { color: #D6D6D6; }
    </style>
</head>
<body>
    <h1> 🦊 Firefox Isolated Session</h1>
    <p>This is a temporary, isolated browsing session.</p>
    <p>No data will be saved when you close this browser.</p>
</body>
</html>

EOF

# Help function
show_help() {
    cat << EOF
Firefox Isolated Instance Script (Zenity Version)

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help     Show this help message
    -c, --clean    Remove downloaded AppImage and exit
    -v, --version  Show script version

DESCRIPTION:
    This script downloads and runs Firefox AppImage in a non-persistent,
    isolated mode using /tmp/firefox-isolated directory. Features Zenity GUI
    for download progress and cleanup confirmation.

FEATURES:
    - Downloads Firefox ESR AppImage automatically with progress dialog
    - Creates temporary profile for each session in /tmp
    - Zenity GUI for download progress and cleanup confirmation
    - Prevents AppImage portable directory creation (.home/.config)
    - Complete environment isolation using custom HOME and XDG variables
    - Cleans up all temporary data after Firefox closes
    - No interference with system Firefox installation

REQUIREMENTS:
    - zenity (for GUI dialogs)
    - curl or wget (for downloading)

EOF
}

# Function to clean up downloaded AppImage
clean_appimage() {
    if [[ -d "$WORK_DIR" ]]; then
        print_status "Removing all application files..."
        rm -rf "$WORK_DIR"
        print_success "All application files removed"
    else
        print_warning "No application files found to remove"
    fi
    
    # Also clean up any AppImage portable directories that might exist
    if [[ -f "$APPIMAGE_PATH" ]]; then
        local appimage_base="${APPIMAGE_PATH%.*}"
        local portable_home="${appimage_base}.home"
        local portable_config="${appimage_base}.config"
        
        [[ -d "$portable_home" ]] && rm -rf "$portable_home" && print_success "Removed portable home directory"
        [[ -d "$portable_config" ]] && rm -rf "$portable_config" && print_success "Removed portable config directory"
    fi
    
    # Clean up problematic directories
    cleanup_problematic_dirs
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -c|--clean)
        clean_appimage
        exit 0
        ;;
    -v|--version)
        echo "Firefox Isolated Instance Script (Zenity) v1.0"
        exit 0
        ;;
    "")
        # No arguments, run main function
        main
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
