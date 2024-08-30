# The goal of this file is to setup the systemd service using the backup.service file and to make an initial backup.
# This script takes 2 arguments, `source` and `destination`, both arguments are a valid filesystem path.
# Backups are made using Rsync to make timestamped versioned backups of the `source` directory.
