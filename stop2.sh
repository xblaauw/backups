#!/bin/bash

# Stop jobs
sudo systemctl stop backup2.timer
sudo systemctl stop backup2.service

# Disable jobs
sudo systemctl disable backup2.timer
sudo systemctl disable backup2.service