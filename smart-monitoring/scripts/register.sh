#!/bin/bash

# Register SMART Health Check Cron Job
# Sets up credentials, msmtp configuration, and daily cron job

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="${SCRIPT_DIR}/check.sh"

echo "=== SMART Health Check Cron Job Registration ==="
echo

# Verify the check script exists
if [ ! -f "$CHECK_SCRIPT" ]; then
    echo "Error: check.sh not found at ${CHECK_SCRIPT}"
    exit 1
fi

# Make check script executable
chmod +x "$CHECK_SCRIPT"
echo "✓ check.sh is executable"

# Check if smartctl is installed
if ! command -v smartctl &> /dev/null; then
    echo "Error: smartctl is not installed. Install it with:"
    echo "  sudo apt-get install smartmontools"
    exit 1
fi
echo "✓ smartctl is installed"

# Check if msmtp is installed
if ! command -v msmtp &> /dev/null; then
    echo "Error: msmtp is not installed. Install it with:"
    echo "  sudo apt-get install msmtp msmtp-mta"
    exit 1
fi
echo "✓ msmtp is installed"

echo

# Prompt for configuration
read -p "Enter device path [/dev/sdc1]: " DEVICE
DEVICE="${DEVICE:-/dev/sdc1}"

read -p "Enter recipient email(s): " RECIPIENT
if [ -z "$RECIPIENT" ]; then
    echo "Error: Recipient email is required"
    exit 1
fi

echo
echo "=== SMTP Configuration ==="
echo "Choose your SMTP provider:"
echo "1) Gmail (gmail.com)"
echo "2) Custom SMTP server"
read -p "Select [1 or 2]: " SMTP_CHOICE

if [ "$SMTP_CHOICE" = "2" ]; then
    # Custom SMTP
    read -p "SMTP server hostname [mail.antagonist.nl]: " SMTP_HOST
    SMTP_HOST="${SMTP_HOST:-mail.antagonist.nl}"

    read -p "SMTP port [587]: " SMTP_PORT
    SMTP_PORT="${SMTP_PORT:-587}"

    read -p "SMTP username: " SMTP_USER
    if [ -z "$SMTP_USER" ]; then
        echo "Error: SMTP username is required"
        exit 1
    fi

    read -p "SMTP password: " -s SMTP_PASSWORD
    echo
else
    # Gmail
    SMTP_HOST="smtp.gmail.com"
    SMTP_PORT="587"

    read -p "Gmail address: " SMTP_USER

    echo "Note: If you have 2FA enabled, use an App Password instead of your regular password."
    echo "See: https://myaccount.google.com/apppasswords"
    read -p "Gmail password or App Password: " -s SMTP_PASSWORD
    echo
fi

echo

# Verify the device exists
if [ ! -e "$DEVICE" ]; then
    echo "Warning: Device $DEVICE does not exist yet."
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting registration."
        exit 1
    fi
fi

# Create credentials file
CREDS_FILE=~/.smartctl_email_creds
echo "$SMTP_PASSWORD" > "$CREDS_FILE"
chmod 600 "$CREDS_FILE"
echo "✓ Created credentials file: $CREDS_FILE (mode 600)"

# Create/update msmtp configuration
MSMTP_CONFIG=~/.msmtprc
ACCOUNT_NAME="smartctl_monitor"

cat > "$MSMTP_CONFIG" <<EOF
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile ~/.msmtp.log

account ${ACCOUNT_NAME}
host ${SMTP_HOST}
port ${SMTP_PORT}
from ${SMTP_USER}
user ${SMTP_USER}
passwordeval cat ~/.smartctl_email_creds

account default : ${ACCOUNT_NAME}
EOF
chmod 600 "$MSMTP_CONFIG"
echo "✓ Created msmtp configuration: $MSMTP_CONFIG (mode 600)"
echo "  SMTP: ${SMTP_HOST}:${SMTP_PORT}"
echo "  User: ${SMTP_USER}"

# Test msmtp connection
echo "Testing msmtp configuration..."
if echo "Test email from smartctl setup" | msmtp -a ${ACCOUNT_NAME} "$RECIPIENT" 2>/dev/null; then
    echo "✓ msmtp test successful"
else
    echo "⚠ Warning: msmtp test may have failed. Check logs at ~/.msmtp.log"
fi

echo

# Prompt for cron schedule
read -p "Enter cron schedule [0 9 * * * (daily at 9am)]: " CRON_SCHEDULE
CRON_SCHEDULE="${CRON_SCHEDULE:-0 9 * * *}"

# Create cron job
CRON_JOB="$CRON_SCHEDULE SMARTCTL_DEVICE=$DEVICE SMARTCTL_RECIPIENT=$RECIPIENT $CHECK_SCRIPT > /dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v smartctl_email_check || true; echo "$CRON_JOB") | crontab -
echo "✓ Registered cron job: $CRON_SCHEDULE"
echo "  Device: $DEVICE"
echo "  Recipient: $RECIPIENT"

echo

# Create environment file for reference
ENV_FILE=~/.smartctl_check.env
cat > "$ENV_FILE" <<EOF
# SMART Health Check Configuration
SMARTCTL_DEVICE=$DEVICE
SMARTCTL_RECIPIENT=$RECIPIENT
CRON_SCHEDULE='$CRON_SCHEDULE'
EOF
echo "✓ Saved configuration to: $ENV_FILE"

echo
echo "=== Registration Complete ==="
echo
echo "Next steps:"
echo "1. Verify cron job: crontab -l | grep smartctl"
echo "2. Test manually: $CHECK_SCRIPT"
echo "3. Monitor log file: tail -f ~/.smartctl_check.log"
echo "4. Remove anytime: bash $SCRIPT_DIR/deregister_smartctl_email_cron.sh"
