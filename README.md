# Advanced Incremental Backup System

A robust Bash script for creating space-efficient, incremental backups using `rsync` and hard links. It includes a retention policy, locking to prevent concurrent runs, detailed logging, and optional email notifications.

## How it Works

This system leverages `rsync`'s `--link-dest` feature to achieve high efficiency. Here's the process:

1.  A timestamped folder is created for the new backup (e.g., `2025-08-31_12-00-00/`).
2.  `rsync` compares the source directory with the *most recent* successful backup.
3.  Any **new or modified files** are copied to the new backup folder.
4.  Any **unchanged files** are not copied. Instead, a **hard link** is created, which points to the existing file from the previous backup. Hard links consume negligible disk space.
5.  A `latest` symlink is updated to always point to the newest successful backup.
6.  Old backups are automatically deleted based on the configured retention policy.

This means you can have what looks like dozens of full backups, while only using the disk space for one full backup plus the changes for each subsequent run.

## Features

-   **Space-Efficient Incremental Backups:** Uses hard links for unchanged files.
-   **Automated Retention Policy:** Automatically prunes old backups after a specified number of days.
-   **Atomic & Safe:** A `latest` symlink is only updated after a successful backup.
-   **Concurrency Lock:** Prevents multiple instances from running at the same time and corrupting data.
-   **Robust Error Handling:** The script stops immediately on any critical error.
-   **Detailed Logging:** Each run produces a timestamped log file with combined output and error streams.
-   **Highly Configurable:** All options are managed in a simple configuration file.
-   **Email Notifications:** Get alerts on backup success or failure.

## Requirements

-   Bash v4.0+
-   `rsync`
-   `mailutils` (`mail` command) for email notifications (optional)

## Setup

1.  Place the project files on your server.
2.  Make the script executable:
    ```bash
    chmod +x backup.sh
    ```
3.  **Crucially, edit `config/backup.conf`** to set your `SOURCE_DIR` and `DEST_DIR`.
4.  Customize other optional settings like `RETENTION_DAYS` and `EMAIL`.

## Directory Structure at Destination

After a few runs, your `DEST_DIR` will look like this:

````

/path/to/destination/
├── backups/
│   ├── 2025-08-29\_12-00-00/
│   ├── 2025-08-30\_12-00-00/
│   └── 2025-08-31\_12-00-00/
├── latest -\> /path/to/destination/backups/2025-08-31\_12-00-00
└── backup.lock

````

## Scheduling with Cron

To run the backup every day at 2:00 AM, edit your crontab (`crontab -e`) and add:

```crontab
0 2 * * * /path/to/your/project/backup.sh
````
