#!/bin/bash

# =================================================================
#           POSTGRESQL DATABASE MANAGEMENT SCRIPT FOR DOCKER
# =================================================================
# Version 3.0: Interactive configuration mode (Auto/Manual).
# This script allows you to interactively back up and restore
# a database from/to a PostgreSQL Docker container.
# =================================================================

# --- Default Configuration ---
# These values can be overridden in Manual Mode.
CONTAINER_NAME="postgres_db"
DB_USER="postgres"
BACKUP_DIR="./db_backups"
# -----------------------------

# --- Global State ---
CONTAINER_INITIALIZED=false
CONTAINER_DISCOVERY="auto" # Default mode

# Function to display an error message and exit
error_exit() {
    echo ""
    echo "❌ Error: $1" >&2
    exit 1
}

# --- Interactive Configuration Setup ---
setup_configuration() {
    clear
    echo "========================================"
    echo "  PostgreSQL Docker Database Management "
    echo "========================================"
    echo "Please choose a configuration mode:"
    echo "1) Automatic (Recommended)"
    echo "2) Manual"
    echo ""
    read -p "Enter your choice (1-2): " mode_choice

    case $mode_choice in
        1)
            echo "✅ Automatic mode selected."
            CONTAINER_DISCOVERY="auto"
            ;;
        2)
            echo "⚙️  Manual mode selected. Please provide the configuration details."
            CONTAINER_DISCOVERY="manual"
            
            # Prompt for Container Name, pre-filling with the default value
            read -p "Enter Docker Container Name [default: $CONTAINER_NAME]: " CONTAINER_NAME_INPUT
            if [ -n "$CONTAINER_NAME_INPUT" ]; then
                CONTAINER_NAME="$CONTAINER_NAME_INPUT"
            fi

            # Prompt for Database User
            read -p "Enter PostgreSQL User [default: $DB_USER]: " DB_USER_INPUT
            if [ -n "$DB_USER_INPUT" ]; then
                DB_USER="$DB_USER_INPUT"
            fi

            # Prompt for Backup Directory
            read -p "Enter Backup Directory [default: $BACKUP_DIR]: " BACKUP_DIR_INPUT
            if [ -n "$BACKUP_DIR_INPUT" ]; then
                BACKUP_DIR="$BACKUP_DIR_INPUT"
            fi
            ;;
        *)
            error_exit "Invalid choice. Please run the script again."
            ;;
    esac

    # Create the backup directory
    mkdir -p "$BACKUP_DIR" || error_exit "Failed to create backup directory: $BACKUP_DIR"
    
    echo ""
    echo "--- Configuration for this session ---"
    echo "Mode: $CONTAINER_DISCOVERY"
    echo "Container Name: $CONTAINER_NAME"
    echo "Database User: $DB_USER"
    echo "Backup Directory: $BACKUP_DIR"
    echo "--------------------------------------"
    echo ""
    read -p "Press Enter to continue..."
}


# --- Container Initialization Function ---
initialize_container() {
    if [ "$CONTAINER_INITIALIZED" = true ]; then
        return
    fi

    if [ "$CONTAINER_DISCOVERY" = "auto" ]; then
        echo "🔍 Auto-detecting running PostgreSQL containers..."
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
    docker exec -t "$CONTAINER_NAME" pg_dump --clean -U "$DB_USER" -d "$DATABASE_TO_BACKUP" > "$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        echo "✅ Database backup created successfully: $BACKUP_FILE"
    else
        error_exit "Database backup failed."
    fi
}

# --- Interactive Restore Function ---
do_restore() {
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
    
    set -o pipefail
    cat "$SELECTED_BACKUP" | docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$TARGET_DATABASE"
    EXIT_CODE=$?
    set +o pipefail

    if [ $EXIT_CODE -eq 0 ]; then
        echo "✅ Restore completed successfully."
    else
        error_exit "Restore FAILED. Check the PostgreSQL error messages above."
    fi
}

# --- Main Program Flow ---

# 1. Setup the configuration based on user's choice
setup_configuration

# 2. Initialize and verify the container
initialize_container

# 3. Show the main action menu
clear
echo "========================================"
echo "          Main Action Menu"
echo "========================================"
echo "Configuration is set. Please choose an operation:"
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