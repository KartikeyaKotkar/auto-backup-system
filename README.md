# Auto Backup System

A Bash-based script to back up files from a configurable source directory to a destination using `rsync`. Includes logging, error handling, and optional email notifications.

## Features
- Incremental backups using `rsync`
- Timestamped backup folders
- Per-run log and error files
- Optional email notifications on success/failure
- Easy configuration via `config/backup.conf`
- Example crontab entry for scheduling

## Requirements
- Bash shell
- `rsync`
- `mail` or `sendmail` (for email notifications, optional)

## Setup
1. Clone or copy this project to your server.
2. Edit `config/backup.conf` to set your source, destination, and email (optional).
3. Make the script executable:
   ```bash
   chmod +x backup.sh
   ```
4. Ensure the `logs/` directory exists (created by default).

## Usage
Run the backup script manually:
```bash
./backup.sh
```

## Configuration
Edit `config/backup.conf`:
```
SOURCE_DIR="/path/to/source"
DEST_DIR="/path/to/destination"
EMAIL="user@example.com"  # Leave blank to disable email
LOG_DIR="/absolute/path/to/logs"  # Optional, default is ./logs
```

## Logs
- Log files are saved in `logs/` with timestamps.
- Error logs are saved separately for each run.

## Scheduling with Cron
To run the backup every day at 2:00 AM, add this to your crontab:
```
0 2 * * * /path/to/backup.sh
```

## Example
```
$ ./backup.sh
Backup successful: 2025-07-05_14-00-00
```

## License
MIT
