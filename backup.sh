#!/bin/bash

# Author: ybryshten@griddynamics.com (Yauheni Bryshten)
# 
# Practical task for Linux module in T1-T2 development path. 
#
# Description of the task:
# You are tasked with creating a system that automates the backup
# of a specific directory on your Linux server. The backup should
# occur daily, and old backups should be managed to avoid consuming
# too much disk space. All the requirenments for this script see in
# the comments bellow.



########################################
# CONFIG
########################################

set -euo pipefail


# Requrenments:
# - Configuration File: Use a configuration file for defining the source and backup directories, retention period, and log file path.
CONFIG_FILE="$(dirname "$0")/backup.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found!"
    exit 1
fi

source "$CONFIG_FILE"

mkdir -p "$(dirname "$LOG_FILE")"

# Requrenments:
# - The script should log its actions to a log file.
log() {
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# Requrenments:
# - Email Notification: Send an email notification upon completion, indicating success or failure.
notify_result() {
    # Capture the exit code of the very last command that ran
    local EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        log "Backup process completed successfully."
        echo "The backup of $SOURCE_DIR finished successfully on $(date)." | mail -s "SUCCESS: Server Backup" "$EMAIL_TO"
    else
        log "CRITICAL: Backup process failed with exit code $EXIT_CODE!"
        echo "The backup script failed! Please check the log at $LOG_FILE for details." | mail -s "FAILURE: Server Backup" "$EMAIL_TO"
    fi
    log "----------------------------------------"
}

# Tell Bash to run the 'notify_result' function on EXIT
trap notify_result EXIT



mkdir -p "$DEST_DIR"

ARCHIVE_PATH="${DEST_DIR}/$(date +"%Y-%m-%d_%H-%M-%S").tar.gz"


########################################
# Concurrency Handling (Lock File)
########################################

# Requrenments
# - Concurrency Handling: Ensure only one instance of the script runs at a time.
LOCK_FILE="/tmp/database_backup.lock"

# Open file descriptor 9 and point it to our lock file
exec 9> "$LOCK_FILE"

# Try to acquire an exclusive lock (-n means fail immediately if already locked)
if ! flock -n 9; then
    log "CRITICAL ERROR: Another instance of this backup script is already running."
    exit 5
fi

sleep 15

##########################################
# ERROR handling
##########################################

# Requrenments:
# - Error Handling: Add more robust error handling and reporting.

# Check if the source directory actually exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    log "CRITICAL ERROR: Source directory '$SOURCE_DIR' does not exist or was moved!"
    exit 2
fi

# Check if we have permission to read the source directory
if [[ ! -r "$SOURCE_DIR" ]]; then
    log "CRITICAL ERROR: No read permission for '$SOURCE_DIR'!"
    exit 3
fi

# Ensure destination exists, then check if we have permission to write to it
mkdir -p "$DEST_DIR"
if [[ ! -w "$DEST_DIR" ]]; then
    log "CRITICAL ERROR: No write permission for destination '$DEST_DIR'!"
    exit 4
fi




########################################
# MAIN
########################################

# Requrenments:
# - Creates a compressed archive of a specified directory.
# - Stores the backup in a designated backup directory with a timestamp in the filename.
tar -czf "$ARCHIVE_PATH" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

echo "Cleaning up backups older than $RETENTION_DAYS days..."

# Requrenments:
# - Deletes backups older than 7 days to manage disk space.
find "$DEST_DIR" -type f -name "*.tar.gz" -mtime +"$RETENTION_DAYS" -delete

echo "Done! Archive created and old backups cleaned up successfully."