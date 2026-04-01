
TASK:


You are tasked with creating a system that automates the backup of a specific directory on your Linux server. The backup should occur daily, and old backups should be managed to avoid consuming too much disk space. Here are the requirements:

1. Bash Script:

- Write a Bash script named backup.sh that:

- Creates a compressed archive of a specified directory.
- Stores the backup in a designated backup directory with a timestamp in the filename.
- Deletes backups older than 7 days to manage disk space.
- Configuration File: Use a configuration file for defining the source and backup directories, retention period, and log file path.
- Email Notification: Send an email notification upon completion, indicating success or failure.
- Error Handling: Add more robust error handling and reporting.
- Concurrency Handling: Ensure only one instance of the script runs at a time.
- The script should log its actions to a log file.

2. Cron Job:

- Schedule the backup.sh script to run daily at midnight using Cron.

3. SystemD Service:

- Create a SystemD service to manage the backup.sh script.
- Ensure the service starts on boot and can be manually started and stopped.
  
  
  
# Implementation

The script source code:


``` bash
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
```

And backup.conf :

``` bash
# backup.conf

# Source and Destination
SOURCE_DIR="/home/ybryshten/linux_practice/important_database"
DEST_DIR="/home/ybryshten/linux_practice/backups"

# Retention policy (in days)
RETENTION_DAYS=7

# Where to save the backup logs
LOG_FILE="/home/ybryshten/linux_practice/backups/backup.log"

EMAIL_TO="<ADD_EMAIL>"
```

Crontab file to execute this script every day at 14 00 (changed it to 14 00 instead of midnight):

``` bash
# Edit this file to introduce tasks to be run by cron.
# 
# Each task to run has to be defined through a single line
# indicating with different fields when the task will be run
# and what command to run for the task
# 
# To define the time you can provide concrete values for
# minute (m), hour (h), day of month (dom), month (mon),
# and day of week (dow) or use '*' in these fields (for 'any').
# 
# Notice that tasks will be started based on the cron's system
# daemon's notion of time and timezones.
# 
# Output of the crontab jobs (including errors) is sent through
# email to the user the crontab file belongs to (unless redirected).
# 
# For example, you can run a backup of all your user accounts
# at 5 a.m every week with:
# 0 5 * * 1 tar -zcf /var/backups/home.tgz /home/
# 
# For more information see the manual pages of crontab(5) and cron(8)
# 
# m h  dom mon dow   command
0 14 * * * /home/ybryshten/linux_practice/backup.sh
~                                                                                                                                                                                             
~                                                                    
```

And systemd file:

``` bash
[Unit]
Description=Automated Database Backup Service
After=network.target

[Service]
Type=oneshot
User=ybryshten
Group=ybryshten
WorkingDirectory=/home/ybryshten/linux_practice
ExecStart=/home/ybryshten/linux_practice/backup.sh
# Ensures the script has a clean environment
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target                                                                                          
```

# Execution

![[../Pasted image 20260401142907.png]]

![[../Pasted image 20260401142928.png]]