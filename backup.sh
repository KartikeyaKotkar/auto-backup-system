#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# --- CONFIGURATION & SETUP ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/backup.conf"

# Load config file
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "FATAL: Configuration file not found at $CONFIG_FILE" >&2
    exit 1
fi

LOG_DIR="${LOG_DIR:-$SCRIPT_DIR/logs}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
RSYNC_OPTS="${RSYNC_OPTS:--avh --delete --stats}"

# --- VARIABLE DEFINITIONS ---

# Check for required variables
if [[ -z "$SOURCE_DIR" || -z "$DEST_DIR" ]]; then
    echo "FATAL: SOURCE_DIR and DEST_DIR must be set in the config file." >&2
    exit 1
fi

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUPS_ROOT="$DEST_DIR/backups"
CURRENT_BACKUP_DIR="$BACKUPS_ROOT/$TIMESTAMP"
LATEST_LINK="$DEST_DIR/latest"
LOCK_FILE="$DEST_DIR/backup.lock"
LOG_FILE="$LOG_DIR/backup_$TIMESTAMP.log"

# --- HELPER FUNCTIONS ---

log() {
    local message="$1"
    echo "[$TIMESTAMP] $message" | tee -a "$LOG_FILE"
}

send_notification() {
    local subject="$1"
    local body_file="$2"
    if [[ -n "$EMAIL" ]]; then
        mail -s "$subject" "$EMAIL" < "$body_file"
        log "Notification email sent to $EMAIL."
    fi
}

cleanup() {
    rm -f "$LOCK_FILE"
    log "Cleanup complete. Lock file removed."
}

# --- SCRIPT EXECUTION ---

mkdir -p "$LOG_DIR"

# Set a trap to ensure the cleanup function is called on exit
trap cleanup EXIT

# Prevent concurrent runs
if [ -e "$LOCK_FILE" ]; then
    log "ERROR: Lock file found at $LOCK_FILE. Another instance may be running."
    exit 1
else
    # Create a lock file with the current PID
    echo $$ > "$LOCK_FILE"
    log "Lock file created."
fi

# Pre-run checks
if [[ ! -d "$SOURCE_DIR" ]]; then
    log "ERROR: Source directory $SOURCE_DIR not found!"
    exit 1
fi
if ! mkdir -p "$DEST_DIR"; then
    log "ERROR: Could not create or access destination directory $DEST_DIR!"
    exit 1
fi

log "--- Starting Backup ---"
log "Source:      $SOURCE_DIR"
log "Destination: $CURRENT_BACKUP_DIR"

LINK_DEST_OPT=""
if [[ -L "$LATEST_LINK" ]]; then
    LATEST_BACKUP=$(readlink "$LATEST_LINK")
    if [[ -d "$LATEST_BACKUP" ]]; then
        LINK_DEST_OPT="--link-dest=$LATEST_BACKUP"
        log "Found previous backup. Will use for incremental linking: $LATEST_BACKUP"
    fi
fi

mkdir -p "$CURRENT_BACKUP_DIR"

log "Running rsync..."
rsync_start_time=$SECONDS
# The `2>&1` redirects stderr to stdout, so both are captured by `tee`
rsync $RSYNC_OPTS $LINK_DEST_OPT "$SOURCE_DIR/" "$CURRENT_BACKUP_DIR/" 2>&1 | tee -a "$LOG_FILE"
rsync_status=${PIPESTATUS[0]} # Get the exit code of rsync, not tee
rsync_duration=$(( SECONDS - rsync_start_time ))

if [ $rsync_status -eq 0 ]; then
    log "Rsync completed successfully in $rsync_duration seconds."

    rm -f "$LATEST_LINK"
    ln -s "$CURRENT_BACKUP_DIR" "$LATEST_LINK"
    log "Updated 'latest' symlink to point to the new backup."

    # --- Retention Policy ---
    if [[ "$RETENTION_DAYS" -gt 0 ]]; then
        log "Applying retention policy: Deleting backups older than $RETENTION_DAYS days..."
        # Find directories in BACKUPS_ROOT older than RETENTION_DAYS and remove them
        find "$BACKUPS_ROOT" -maxdepth 1 -type d -mtime "+$RETENTION_DAYS" -exec rm -rf {} \;
        log "Retention policy applied."
    fi

    log "--- Backup Successful ---"
    send_notification "[AutoBackup] SUCCESS: Backup completed on $(hostname)" "$LOG_FILE"
    exit 0
else
    log "--- !!! BACKUP FAILED !!! ---"
    log "Rsync exited with error code: $rsync_status."
    log "The failed backup directory ($CURRENT_BACKUP_DIR) will be removed."
    rm -rf "$CURRENT_BACKUP_DIR"
    send_notification "[AutoBackup] FAILED: Backup failed on $(hostname)" "$LOG_FILE"
    exit $rsync_status
fi
