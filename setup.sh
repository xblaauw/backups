# The goal of this file is to setup the systemd service using the `backup1.service` and `backup2.service` files and to make an initial backup of `source` in both locations.
# This script uses the information in .env to determine what goes where.
# Backups are made using Rsync to make timestamped incremental backups of the `source` directory into `destination1` and `destination2`.
