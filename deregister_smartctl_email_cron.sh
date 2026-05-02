#!/bin/bash

# Deregister SMART Health Check Cron Job
# Removes the cron job and optionally the credentials/configuration files

set -e

echo "=== SMART Health Check Cron Job Deregistration ==="
echo

# Remove cron job
if crontab -l 2>/dev/null | grep -q smartctl_email_check; then
    (crontab -l 2>/dev/null | grep -v smartctl_email_check) | crontab -
    echo "✓ Removed cron job"
else
    echo "ℹ No cron job found"
fi

echo

# Prompt to remove credentials/config
read -p "Remove credentials and configuration files? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f ~/.smartctl_email_creds && echo "✓ Removed ~/.smartctl_email_creds"
    rm -f ~/.msmtprc && echo "✓ Removed ~/.msmtprc"
    rm -f ~/.smartctl_check.env && echo "✓ Removed ~/.smartctl_check.env"
    rm -f ~/.msmtp.log && echo "✓ Removed ~/.msmtp.log"
else
    echo "ℹ Credentials and configuration files retained"
fi

echo
echo "=== Deregistration Complete ==="
echo
echo "To re-register: bash $(dirname "${BASH_SOURCE[0]}")/register_smartctl_email_cron.sh"
