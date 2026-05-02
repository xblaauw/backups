#!/bin/bash

# SMART Health Check with Email Alert
# Version: 1.0 (2026-05-02)
#
# Checks the SMART health status of an external HDD
# Sends an email to a recipient with the result (success or failure)
# IMPORTANT: Always sends email on any condition (health check or error)
#
# Configuration is read from environment variables set by crontab,
# which are configured during registration with register_smartctl_email_cron.sh

# DO NOT use set -e — we want to catch and report errors, not exit silently
# set -e

# Configuration - from crontab environment variables
DEVICE="${SMARTCTL_DEVICE}"
RECIPIENT="${SMARTCTL_RECIPIENT}"
HOSTNAME=$(hostname)
CHECK_TIME=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE=~/.smartctl_check.log

# Validate required environment variables from crontab
if [ -z "$DEVICE" ] || [ -z "$RECIPIENT" ]; then
    echo "ERROR: SMARTCTL_DEVICE and SMARTCTL_RECIPIENT environment variables not set"
    echo "This script must be run by crontab with proper environment variables."
    echo "Re-run: bash ~/Projects/backups/register_smartctl_email_cron.sh"
    exit 1
fi

# Log function
log_result() {
    echo "[${CHECK_TIME}] Device: ${DEVICE} | $1" >> "$LOG_FILE"
}

# Run SMART health check (requires sudo for device access)
SMARTCTL_OUTPUT=$(sudo smartctl -H "$DEVICE" 2>&1)
SMARTCTL_EXIT=$?

# Initialize status
STATUS="UNKNOWN"
EMAIL_SUBJECT=""

# Handle smartctl errors
if [ $SMARTCTL_EXIT -ne 0 ]; then
    STATUS="ERROR"
    HEALTH_STATUS="SMARTCTL FAILED"
    EMAIL_SUBJECT="🔴 SMART Check FAILED: ${DEVICE} on ${HOSTNAME}"
    log_result "ERROR - smartctl exit code: $SMARTCTL_EXIT"
else
    # Parse health status from output
    HEALTH_STATUS=$(echo "$SMARTCTL_OUTPUT" | grep -i "SMART Health Status" | head -1)

    # Extract health status
    if echo "$SMARTCTL_OUTPUT" | grep -qi "SMART Health Status:.*OK"; then
        STATUS="PASSED"
        EMAIL_SUBJECT="✅ SMART Check OK: ${DEVICE} on ${HOSTNAME}"
    elif echo "$SMARTCTL_OUTPUT" | grep -qi "SMART Health Status:.*FAILED"; then
        STATUS="FAILED"
        EMAIL_SUBJECT="🔴 SMART Check FAILED: ${DEVICE} on ${HOSTNAME}"
    elif echo "$SMARTCTL_OUTPUT" | grep -qi "SMART Health Status:.*WARNING"; then
        STATUS="WARNING"
        EMAIL_SUBJECT="⚠️  SMART Check WARNING: ${DEVICE} on ${HOSTNAME}"
    elif echo "$SMARTCTL_OUTPUT" | grep -qi "passed"; then
        STATUS="PASSED"
        EMAIL_SUBJECT="✅ SMART Check OK: ${DEVICE} on ${HOSTNAME}"
    elif echo "$SMARTCTL_OUTPUT" | grep -qi "failed"; then
        STATUS="FAILED"
        EMAIL_SUBJECT="🔴 SMART Check FAILED: ${DEVICE} on ${HOSTNAME}"
    else
        STATUS="UNKNOWN"
        EMAIL_SUBJECT="❓ SMART Check UNKNOWN: ${DEVICE} on ${HOSTNAME}"
    fi

    log_result "Status: $STATUS"
fi

# Construct email with headers
EMAIL_BODY=$(cat <<EOF
To: ${RECIPIENT}
Subject: ${EMAIL_SUBJECT}

SMART Health Check Report
=========================

Status: ${STATUS}
Device: ${DEVICE}
Host: ${HOSTNAME}
Time: ${CHECK_TIME}
smartctl Exit Code: ${SMARTCTL_EXIT}

Full SMART Health Output:
${HEALTH_STATUS}

Full smartctl Output:
${SMARTCTL_OUTPUT}

---
This is an automated report from smartctl monitoring on ${HOSTNAME}.
EOF
)

# Send email using msmtp
# -t flag tells msmtp to read recipients from email headers (To, Cc, Bcc)
# Uses default account from ~/.msmtprc (no -a flag needed)
if echo "${EMAIL_BODY}" | msmtp -t 2>&1; then
    log_result "Email sent successfully to ${RECIPIENT}"
else
    # Even if email sending fails, log it
    log_result "ERROR: Failed to send email to ${RECIPIENT}"
    exit 1
fi

# Exit with status code
if [ "$STATUS" != "PASSED" ]; then
    exit 1
else
    exit 0
fi
