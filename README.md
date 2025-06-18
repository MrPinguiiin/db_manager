# PostgreSQL Database Management Script for Docker

This script provides an interactive command-line interface to easily backup and restore PostgreSQL databases running inside a Docker container.

## Prerequisites

Before using this script, ensure you have the following installed and configured:

-   **Bash:** The script is written in Bash.
-   **Docker:** Docker must be installed and running.
-   **A running PostgreSQL container:** You need a PostgreSQL container to connect to.

## Configuration

You can configure the script by editing the variables at the top of the `backup.sh` file.

| Variable              | Description                                                                                                                               |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `CONTAINER_DISCOVERY` | Set the container discovery method. Can be `auto` or `manual`.                                                                            |
| `CONTAINER_NAME`      | The name of your PostgreSQL Docker container. **This is only used if `CONTAINER_DISCOVERY` is set to `manual`**.                            |
| `DB_USER`             | The PostgreSQL user for connecting to the database. This user must have permissions to perform dumps.                                     |
| `BACKUP_DIR`          | The local directory where backup files will be stored. The script creates this directory if it doesn't exist.                             |

### Container Discovery

-   **`auto` (Default):**
    -   The script will automatically search for running containers based on the official `postgres` image.
    -   If only one container is found, it will be selected automatically.
    -   If multiple containers are found, you will be prompted to choose one.
    -   If no containers are found, the script will exit with an error.

-   **`manual`:**
    -   The script will use the value specified in the `CONTAINER_NAME` variable.
    -   It will first check if a container with that exact name is currently running. If not, it will exit with an error.

## Installation

You can install this script using the following one-liner. This command downloads the `install.sh` script and runs it to install the tool on your system.

> **Note:** The installation script requires `wget` and will use `sudo` for system-wide installation.

```sh
wget -qO install.sh https://raw.githubusercontent.com/MrPinguiiin/db_manager/main/install.sh && chmod +x install.sh && sudo ./install.sh
```

## Usage

If you prefer not to install the script system-wide, you can run it directly.

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