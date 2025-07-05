#!/bin/bash

# Load config
CONFIG_FILE="$(dirname "$0")/config/backup.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

# Set up variables
date_str=$(date +"%Y-%m-%d_%H-%M-%S")
backup_dir="$DEST_DIR/backup_$date_str"
log_file="$LOG_DIR/backup_$date_str.log"
err_file="$LOG_DIR/backup_$date_str.err.log"

mkdir -p "$backup_dir" "$LOG_DIR"

rsync -av --delete "$SOURCE_DIR/" "$backup_dir/" > "$log_file" 2> "$err_file"
rsync_status=$?

# Check for errors
if [ $rsync_status -eq 0 ]; then
    status_msg="Backup successful: $date_str"
    success=1
else
    status_msg="Backup FAILED: $date_str. See $err_file."
    success=0
fi

echo "$status_msg" | tee -a "$log_file"

# Email notification (optional)
if [ -n "$EMAIL" ]; then
    subject="[AutoBackup] $status_msg"
    if [ $success -eq 1 ]; then
        mail -s "$subject" "$EMAIL" < "$log_file"
    else
        mail -s "$subject" "$EMAIL" < "$err_file"
    fi
fi

exit $rsync_status
