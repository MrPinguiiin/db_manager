#!/bin/bash

# =================================================================
#            INSTALLER SCRIPT for DB-MANAGER
# =================================================================
# This script downloads and installs the db-manager tool from
# the MrPinguiiin GitHub repository to make it a system-wide command.
# =================================================================

# --- Configuration ---
# The raw URL of your main script in the GitHub repository
SCRIPT_URL="https://raw.githubusercontent.com/MrPinguiiin/db_manager/main/db-manager"

# The destination directory (standard for user-installed executables)
INSTALL_DIR="/usr/local/bin"

# The name of the command after installation
CMD_NAME="db-manager"
# -------------------

# Ensure the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Please use 'sudo'." >&2
   exit 1
fi

# Function to display messages
log() {
    echo "=> $1"
}

log "Starting installation of $CMD_NAME..."

# Download the script and place it in the installation directory
log "Downloading script from GitHub..."
wget -qO "$INSTALL_DIR/$CMD_NAME" "$SCRIPT_URL"
if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to download the script. Please check the URL and your internet connection."
    exit 1
fi

# Make the script executable
log "Setting executable permissions..."
chmod +x "$INSTALL_DIR/$CMD_NAME"
if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to set executable permissions on $INSTALL_DIR/$CMD_NAME."
    exit 1
fi

log "---------------------------------------------------------"
echo "✅ Installation complete!"
echo ""
echo "You can now run the tool from anywhere by simply typing:"
echo "   $CMD_NAME"
echo "---------------------------------------------------------"

exit 0