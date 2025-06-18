#!/bin/bash

# =================================================================
#           POSTGRESQL DATABASE MANAGEMENT SCRIPT FOR DOCKER
# =================================================================
# Version 2.0: With accurate pipeline error detection.
# This script allows you to interactively back up and restore
# a database from/to a PostgreSQL Docker container.
# =================================================================

# --- Configuration ---
# Container discovery method: 'auto' or 'manual'.
# 'auto': The script will try to find a running PostgreSQL container.
# 'manual': You must specify the exact CONTAINER_NAME below.
CONTAINER_DISCOVERY="auto"

CONTAINER_NAME="postgres_db" # Used if CONTAINER_DISCOVERY is 'manual'. Adjust with your PostgreSQL container name
# -------------------

# --- Global State ---
CONTAINER_INITIALIZED=false

# Function to display an error message and exit
error_exit() {
    echo ""
    echo "❌ Error: $1" >&2
    exit 1
}

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR" || error_exit "Failed to create backup directory: $BACKUP_DIR"

# --- Container Initialization Function ---
initialize_container() {
    # Run initialization only once
    if [ "$CONTAINER_INITIALIZED" = true ]; then
        return
    fi

    if [ "$CONTAINER_DISCOVERY" = "auto" ]; then
        echo "🔍 Auto-detecting running PostgreSQL containers..."
        # Find containers using the official 'postgres' image
        local running_containers
        running_containers=($(docker ps --filter "status=running" --filter "ancestor=postgres" --format "{{.Names}}"))

        if [ ${#running_containers[@]} -eq 0 ]; then
            error_exit "No running PostgreSQL containers found. Please start your container or use manual configuration."
        elif [ ${#running_containers[@]} -eq 1 ]; then
            CONTAINER_NAME=${running_containers[0]}
            echo "✅ Automatically selected container: '$CONTAINER_NAME'"
        else
            echo "Multiple PostgreSQL containers found. Please select one:"
            local i=1
            for container in "${running_containers[@]}"; do
                echo "$i. $container"
                i=$((i+1))
            done
            echo ""
            local choice
            read -p "Enter the number of the container to use: " choice

            if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#running_containers[@]} ]; then
                error_exit "Invalid selection."
            fi
            CONTAINER_NAME=${running_containers[$((choice-1))]}
        fi
    else
        echo "⚙️  Manual mode: Checking for container '$CONTAINER_NAME'..."
        if ! docker ps --filter "name=^${CONTAINER_NAME}$" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
            error_exit "Container '$CONTAINER_NAME' is not running or does not exist. Please check the name and status."
        fi
        echo "✅ Container '$CONTAINER_NAME' found and is running."
    fi
    echo ""
    CONTAINER_INITIALIZED=true
}

# --- Interactive Backup Function ---
do_backup() {
    initialize_container
    echo ""
    echo "--- Starting Backup Process ---"

    # 1. Select the database to back up
    echo "Fetching database list from container '$CONTAINER_NAME'..."
    db_list=($(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -l -t | awk '{print $1}' | grep -vE 'template[01]|postgres'))
    if [ ${#db_list[@]} -eq 0 ]; then
        error_exit "Could not fetch the database list from the container."
    fi

    echo "Select the database to back up:"
    i=1
    for db in "${db_list[@]}"; do
        echo "$i. $db"
        i=$((i+1))
    done
    echo ""
    read -p "Enter the database number: " db_choice

    if ! [[ "$db_choice" =~ ^[0-9]+$ ]] || [ "$db_choice" -lt 1 ] || [ "$db_choice" -gt ${#db_list[@]} ]; then
        error_exit "Invalid database selection."
    fi
    DATABASE_TO_BACKUP="${db_list[$((db_choice-1))]}"

    # 2. Specify the backup filename
    read -p "Enter a prefix for the backup file (e.g., myapp_full): " FILENAME_PREFIX
    if [ -z "$FILENAME_PREFIX" ]; then
        error_exit "Backup file prefix cannot be empty."
    fi

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/${FILENAME_PREFIX}_${TIMESTAMP}.sql"

    echo ""
    echo "Starting database backup for '$DATABASE_TO_BACKUP'..."
    echo "File will be saved as: $(basename "$BACKUP_FILE")"

    # 3. Execute the backup
    # FIX: Added --clean to include DROP commands for a smoother restore
    docker exec -t "$CONTAINER_NAME" pg_dump --clean -U "$DB_USER" -d "$DATABASE_TO_BACKUP" > "$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        echo "✅ Database backup created successfully: $BACKUP_FILE"
    else
        error_exit "Database backup failed."
    fi
}

# --- Interactive Restore Function ---
do_restore() {
    initialize_container
    echo ""
    echo "--- Starting Restore Process ---"

    # 1. Select the backup file
    echo "Searching for backup files in directory '$BACKUP_DIR'..."
    backups=($(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.sql" -o -name "*.backup" -o -name "*.dump" \)))
    if [ ${#backups[@]} -eq 0 ]; then
        error_exit "No backup files found in '$BACKUP_DIR'."
    fi

    echo "Select the backup file to restore:"
    i=1
    for backup in "${backups[@]}"; do
        echo "$i. $(basename "$backup")"
        i=$((i+1))
    done
    echo ""
    read -p "Enter the backup file number: " backup_choice

    if ! [[ "$backup_choice" =~ ^[0-9]+$ ]] || [ "$backup_choice" -lt 1 ] || [ "$backup_choice" -gt ${#backups[@]} ]; then
        error_exit "Invalid backup file selection."
    fi
    SELECTED_BACKUP="${backups[$((backup_choice-1))]}"
    echo "You selected: $(basename "$SELECTED_BACKUP")"
    echo ""

    # 2. Select the target database
    echo "Fetching database list from container '$CONTAINER_NAME'..."
    db_list=($(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -l -t | awk '{print $1}' | grep -vE 'template[01]|postgres'))
    if [ ${#db_list[@]} -eq 0 ]; then
        error_exit "Could not fetch the database list from the container."
    fi

    echo "Select the TARGET database for the restore process:"
    j=1
    for db in "${db_list[@]}"; do
        echo "$j. $db"
        j=$((j+1))
    done
    echo ""
    read -p "Enter the target database number: " db_choice

    if ! [[ "$db_choice" =~ ^[0-9]+$ ]] || [ "$db_choice" -lt 1 ] || [ "$db_choice" -gt ${#db_list[@]} ]; then
        error_exit "Invalid target database selection."
    fi
    TARGET_DATABASE="${db_list[$((db_choice-1))]}"
    echo ""

    # 3. Confirm and execute
    echo "---------------------------------------------------------"
    echo "WARNING! You are about to overwrite the contents of an existing database."
    echo "---------------------------------------------------------"
    echo "Backup File   : $(basename "$SELECTED_BACKUP")"
    echo "Target Database : $TARGET_DATABASE"
    echo "---------------------------------------------------------"
    read -p "Are you sure you want to continue? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo "Restore process cancelled."
        exit 0
    fi

    echo ""
    echo "Starting restore process for database '$TARGET_DATABASE'..."
    
    # KEY FIX HERE: Use 'set -o pipefail'
    # This ensures the script fails if psql fails, not just if docker exec fails.
    set -o pipefail
    cat "$SELECTED_BACKUP" | docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$TARGET_DATABASE"
    
    # Save the exit code before running other commands
    EXIT_CODE=$?
    
    # Revert to normal behavior
    set +o pipefail

    if [ $EXIT_CODE -eq 0 ]; then
        echo "✅ Restore completed successfully."
    else
        error_exit "Restore FAILED. Check the PostgreSQL error messages above."
    fi
}

# --- Main Menu ---
clear
echo "========================================"
echo "  PostgreSQL Docker Database Management "
echo "========================================"
echo "Select the operation you want to perform:"
echo "1) Backup Database"
echo "2) Restore Database"
echo "3) Exit"
echo ""

read -p "Enter your choice (1-3): " CHOICE

case $CHOICE in
    1)
        do_backup
        ;;
    2)
        do_restore
        ;;
    3)
        echo "Exiting."
        exit 0
        ;;
    *)
        error_exit "Invalid choice."
        ;;
esac