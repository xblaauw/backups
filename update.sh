#!/bin/bash

# Stop job 1
sudo ./stop1.sh

# Copy local backup jobs to systemd
sudo cp backup1.service /etc/systemd/system/backup1.service
sudo cp backup1.timer /etc/systemd/system/backup1.timer

# Start & Enable
sudo systemctl start backup1.service
sudo systemctl enable backup1.service

sudo systemctl start backup1.timer
sudo systemctl enable backup1.timer

# Reload systemd
sudo systemctl daemon-reload


### REPEAT FOR BACKUP 2 ###

# Stop job 2
sudo ./stop2.sh

# Copy local backup jobs to systemd
sudo cp backup2.service /etc/systemd/system/backup2.service
sudo cp backup2.timer /etc/systemd/system/backup2.timer

# Start & Enable
sudo systemctl start backup2.service
sudo systemctl enable backup2.service

sudo systemctl start backup2.timer
sudo systemctl enable backup2.timer

# Reload systemd
sudo systemctl daemon-reload

