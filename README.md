# PostgreSQL Database Management Script for Docker

This script provides an interactive command-line interface to easily backup and restore PostgreSQL databases running inside a Docker container.

## Prerequisites

Before using this script, ensure you have the following installed and configured:

-   **Bash:** The script is written in Bash.
-   **Docker:** Docker must be installed and running.
-   **A running PostgreSQL container:** You need a PostgreSQL container to connect to.

## Configuration

You can configure the script by editing the following variables at the top of the `backup.sh` file:

-   `CONTAINER_NAME`: The name of your running PostgreSQL Docker container. (Default: `postgres_db`)
-   `DB_USER`: The PostgreSQL user to connect with. This user must have permission to access the databases and perform dumps. (Default: `postgres`)
-   `BACKUP_DIR`: The local directory where backup files will be stored. The script will create this directory if it doesn't exist. (Default: `./db_backups`)

```bash
# --- Configuration ---
CONTAINER_NAME="postgres_db" # Adjust to your PostgreSQL container name
DB_USER="postgres"           # Adjust to your PostgreSQL user
BACKUP_DIR="./db_backups"    # Directory where backup files are stored
# -------------------
```

## Usage

1.  **Make the script executable:**
    Before running the script for the first time, you need to give it execute permissions.

    ```sh
    chmod +x backup.sh
    ```

2.  **Run the script:**
    Execute the script from your terminal.

    ```sh
    ./backup.sh
    ```

3.  **Follow the interactive menu:**
    The script will present a menu with the following options:

    ```
    ========================================
      PostgreSQL Docker Database Management
    ========================================
    Select the operation you want to perform:
    1) Backup Database
    2) Restore Database
    3) Exit
    ```

### Backup a Database

1.  Choose option `1`.
2.  The script will list all available databases in the container.
3.  Enter the number corresponding to the database you want to back up.
4.  Enter a prefix for your backup file name (e.g., `myapp_production`).
5.  The script will create a `.sql` backup file in the configured `BACKUP_DIR`, named with the prefix and a timestamp (e.g., `myapp_production_20231027_103000.sql`).

### Restore a Database

1.  Choose option `2`.
2.  The script will list all backup files (`.sql`, `.dump`, `.backup`) found in the `BACKUP_DIR`.
3.  Enter the number corresponding to the backup file you want to restore.
4.  The script will then list the available databases in the container.
5.  Enter the number for the **target database** where the backup will be restored.
6.  **Warning:** The restore operation will overwrite the target database. You will be asked for confirmation before proceeding. Type `y` to continue. 