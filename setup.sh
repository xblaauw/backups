# The goal of this file is to setup the systemd service using the backup.service file and to make an initial backup.
# This script takes 3 arguments, `source` and `destination1` and `destination2`, all arguments are a valid filesystem path.
# Backups are made using Rsync to make timestamped incremental backups of the `source` directory.
