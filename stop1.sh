#!/bin/bash

# Stop jobs
sudo systemctl stop backup1.timer
sudo systemctl stop backup1.service

# Disable jobs
sudo systemctl disable backup1.timer
sudo systemctl disable backup1.service