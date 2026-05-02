# SMART Health Monitoring Setup

**Version:** 1.0  
**Last Updated:** 2026-05-02

## Overview

This setup monitors the health of your external HDD using SMART (Self-Monitoring, Analysis and Reporting Technology) and sends you an email report on every check.

**What it does:**
- Runs a daily SMART health check on your external HDD
- Logs all check results locally
- **Always sends an email** — whether the check passes, fails, or encounters an error
- Reports any failures clearly (disk disconnected, smartctl errors, health problems)
- Requires no interaction — fully automated via cron

**Critical design:** This script is designed to fail loudly, not silently. If anything goes wrong, you'll know immediately.

**When you need this:**
- You have an external HDD used for important backups
- You want early warning of disk failures
- You want to catch data corruption before it spreads

---

## Prerequisites

### 1. Install smartmontools

`smartctl` is the tool that reads SMART data from disks.

```bash
sudo apt-get update
sudo apt-get install smartmontools
```

Verify installation:
```bash
smartctl --version
```

### 2. Install msmtp

`msmtp` is a lightweight SMTP client that sends emails. You'll use it to email Jaron when problems occur.

```bash
sudo apt-get install msmtp msmtp-mta
```

During installation, you may be prompted about **AppArmor support**. Choose **yes** — this enables security restrictions on msmtp that prevent it from accessing files it shouldn't.

Verify installation:
```bash
msmtp --version
```

### 3. Allow Non-Sudo Access to smartctl

The smartctl script needs to read disk health data, which requires sudo access. 
Set up passwordless sudo for smartctl so the cron job can run without prompting for a password.

Run this command:

```bash
sudo visudo
```

At the **end of the file**, add this line:

```
xander ALL=(ALL) NOPASSWD: /usr/sbin/smartctl
```

Save and exit (Ctrl+O, Enter, Ctrl+X in nano; `:wq` in vi).

**What this does:** Allows your user to run smartctl with sudo without needing to enter a password. This is safe because it only allows smartctl, nothing else.

### 4. Identify Your Disk Device

Find the device path of your external HDD:

```bash
lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL
```

Look for your disk (from our earlier setup: likely `/dev/sdc1`, labeled `jaron-c-hdd`, UUID `cc6e9ded-5c6f-4d4f-baac-2360c40359fc`).

**Write down your device path** — you'll need it during setup.

### 5. Have Recipients' Emails

Default recipients:
- Xander: `xander@painapple.nl`
- Jaron: `jaronheising@gmail.com`

(You can use different addresses or add more by using comma-separated values during registration.)

---

## Setup Process

### Step 1: Make Scripts Executable

Navigate to the backups directory:

```bash
cd ~/Projects/backups
chmod +x register_smartctl_email_cron.sh deregister_smartctl_email_cron.sh smartctl_email_check.sh
```

### Step 2: Configure Passwordless sudo for smartctl

If you haven't already done this in the prerequisites, run:

```bash
sudo visudo
```

Add this line at the end:

```
xander ALL=(ALL) NOPASSWD: /usr/sbin/smartctl
```

Save and exit.

### Step 3: Run the Registration Script

This interactive script sets up everything:

```bash
bash register_smartctl_email_cron.sh
```

**You'll be prompted for:**

1. **Device path** — Press Enter to use `/dev/sdc1`, or enter your actual device (e.g., `/dev/sdd1`)
2. **Recipient email(s)** — Press Enter to use `xander@painapple.nl,jaronheising@gmail.com`, or enter alternatives (comma-separated for multiple)
3. **SMTP Provider** — Choose:
   - **Option 1: Gmail** — Uses `smtp.gmail.com` port 587. Just provide your Gmail address and password
   - **Option 2: Custom SMTP** — Provide server, port, username, password (default: `mail.antagonist.nl` port 587)
4. **SMTP credentials** — Your email password (input is hidden)
   - **Gmail users with 2FA:** Use an [App Password](https://myaccount.google.com/apppasswords) instead of your regular password
5. **Cron schedule** — Press Enter to use `0 9 * * *` (daily at 9am), or enter a different schedule

**What the script does:**
- Creates `~/.smartctl_email_creds` (stores password securely, mode 600)
- Creates `~/.msmtprc` (msmtp configuration, mode 600)
- Tests the email connection
- Registers a daily cron job
- Creates `~/.smartctl_check.env` (configuration reference)

**Expected output:**
```
=== SMART Health Check Cron Job Registration ===

✓ smartctl_email_check.sh is executable
✓ smartctl is installed
✓ msmtp is installed

Enter device path [/dev/sdc1]: [press Enter or type your device]
Enter recipient email [xblaauw@gmail.com]: [press Enter or accept]
Enter SMTP password for xander@painapple.nl: [type your password, hidden]

✓ Created credentials file: ~/.smartctl_email_creds (mode 600)
✓ Created msmtp configuration: ~/.msmtprc (mode 600)
✓ msmtp test successful
...
=== Registration Complete ===
```

### Step 4: Verify Registration

Check that the cron job was added:

```bash
crontab -l | grep smartctl
```

**Expected output:**
```
0 9 * * * SMARTCTL_DEVICE=/dev/sdc1 SMARTCTL_RECIPIENT=xblaauw@gmail.com /home/xander/Projects/backups/smartctl_email_check.sh > /dev/null 2>&1
```

---

## Testing

### Test 1: Run the Check Manually

```bash
bash ~/Projects/backups/smartctl_email_check.sh
```

**Expected behavior:**
- An email is sent **on every check** — pass, fail, or error
- Email subject shows:
  - ✅ if disk is healthy (PASSED)
  - ⚠️ if disk has warnings (WARNING)
  - 🔴 if disk is failed or smartctl error (FAILED/ERROR)
  - ❓ if status cannot be determined (UNKNOWN)
- Log entry is created at `~/.smartctl_check.log`

**Error scenarios that will send email:**
- Disk is disconnected → "No such device" error is reported
- Disk is failing → FAILED status is reported
- smartctl cannot access device → smartctl error is included in email
- Any other issue → full error trace is included

**Why always send email?** Silent failures are worse than false alarms. You need to know immediately if monitoring itself is broken.

**If there's an error:**
- Check `~/.msmtp.log` for SMTP issues
- Check that `/dev/sdc1` is the correct device (or update `~/.smartctl_check.env`)

### Test 2: Check the Log

```bash
tail -f ~/.smartctl_check.log
```

You should see entries like:
```
[2026-05-02 10:45:23] Device: /dev/sdc1 | Status: PASSED
[2026-05-02 10:45:45] Device: /dev/sdc1 | Status: PASSED
```

### Test 3: Verify Cron Job Runs

The cron job runs at 9am daily (or your specified time). 
To simulate an immediate run, you can:

1. Change the cron schedule to 1 minute from now
2. Wait for cron to execute
3. Check the log

Or just wait until the scheduled time and check the log.

---

## Understanding the Output

### Healthy Disk
- **Status:** PASSED
- **Action:** Email sent with ✅ subject; logged locally
- **What it means:** Disk is healthy, monitoring system is working correctly
- **Why email on success?** You need proof the monitoring is alive. If emails stop, you know something is wrong.

### Unhealthy Disk

**Status:** FAILED or WARNING

**Email is sent with:**
- Disk status (FAILED/WARNING)
- Device name
- Hostname where check ran
- Full SMART health output
- Complete smartctl diagnostic data

**What it means:** 
- FAILED = Disk failure detected; data at risk
- WARNING = Potential issue detected; monitor closely

**Action:** 
1. Backup critical data immediately
2. Plan disk replacement soon
3. Don't ignore FAILED status

---

## Configuration Files

After registration, three configuration files are created:

### `~/.smartctl_email_creds`
- Contains your SMTP password
- Protected with mode 600 (only you can read)
- Used by msmtp to authenticate

### `~/.msmtprc`
- msmtp configuration (SMTP settings)
- Protected with mode 600
- Specifies mail.antagonist.nl, port 587, TLS, etc.

### `~/.smartctl_check.env`
- Reference file with your setup details
- Device path, recipient, cron schedule

Do not share these files or commit them to version control — they contain credentials.

---

## Troubleshooting

### Issue: "smartctl is not installed"

**Solution:**
```bash
sudo apt-get install smartmontools
```

### Issue: "msmtp is not installed"

**Solution:**
```bash
sudo apt-get install msmtp msmtp-mta
```

### Issue: "msmtp test may have failed"

**Check the log:**
```bash
cat ~/.msmtp.log
```

Common issues:
- Wrong password — re-run registration with correct password
- Network issue — verify internet connection
- SMTP server temporarily down — try again later

**Re-register to fix:**
```bash
bash ~/Projects/backups/deregister_smartctl_email_cron.sh
bash ~/Projects/backups/register_smartctl_email_cron.sh
```

### Issue: "Permission denied" when running smartctl

**Cause:** User doesn't have sudo access to read the device.

**Solution:**
```bash
sudo visudo
```

Add this line at the end:
```
xander ALL=(ALL) NOPASSWD: /usr/sbin/smartctl
```

Save and exit. Then test again:
```bash
bash ~/Projects/backups/smartctl_email_check.sh
```

### Issue: Device not found (`/dev/sdc1`)

**Verify the device exists:**
```bash
lsblk
```

Look for your disk. If it's at a different path (e.g., `/dev/sdd1`), you need to:

**Option 1: Re-register**
```bash
bash ~/Projects/backups/deregister_smartctl_email_cron.sh
bash ~/Projects/backups/register_smartctl_email_cron.sh
```

**Option 2: Manual update**
```bash
# Edit the crontab
crontab -e

# Find the smartctl line and change /dev/sdc1 to your actual device
```

### Issue: No email received when disk is unhealthy

**Check:**
1. Is the disk actually unhealthy? Run: `smartctl -H /dev/sdc1`
2. Did cron job run? Check: `cat ~/.smartctl_check.log`
3. Is msmtp working? Check: `cat ~/.msmtp.log`
4. Is the recipient email correct? Check: `cat ~/.smartctl_check.env`

**Test email manually:**
```bash
echo "Test" | msmtp your-email@example.com
```
(Replace `your-email@example.com` with the recipient email.)

### Issue: Cron job doesn't seem to run

**Verify cron is running:**
```bash
sudo systemctl status cron
```

**Check system cron logs:**
```bash
grep CRON /var/log/syslog | tail -20
```

**Test cron job manually:**
```bash
bash ~/Projects/backups/smartctl_email_check.sh
```

---

## Removing the Setup

If you want to stop monitoring:

```bash
bash ~/Projects/backups/deregister_smartctl_email_cron.sh
```

You'll be prompted to remove credentials and configuration files. Choose yes to clean up everything.

---

## Cron Schedule Reference

The cron schedule follows the format: `minute hour day month day-of-week command`

**Examples:**
- `0 9 * * *` — Daily at 9:00am
- `0 */12 * * *` — Every 12 hours
- `0 0 * * 0` — Weekly on Sunday at midnight
- `30 2 * * *` — Daily at 2:30am

You can use crontab.guru to generate schedules.

---

## Monitoring Multiple Disks

This setup monitors one disk (`/dev/sdc1`). To monitor Jaron's disk on his PC as well, repeat the setup on his system with:
- His sudo account
- His recipient email (or yours)
- The path to his external HDD

The scripts are self-contained and can run on multiple systems independently.

---

## Notes

- **Password security:** Your SMTP password is stored in `~/.smartctl_email_creds` with restricted permissions. Only you can read it, but keep it secure.

- **Logs:** Check `~/.smartctl_check.log` for all check results. This file grows over time; feel free to delete it and start fresh.

- **msmtp logs:** `~/.msmtp.log` contains SMTP connection details. Useful for debugging email issues.

- **When to care:** SMART warnings are early indicators. A PASSED status doesn't guarantee the disk is perfect, but FAILED/WARNING means you should act quickly.

- **Offline disks:** If the disk is not connected when cron runs, smartctl will fail with "No such device" error. An email IS sent reporting this error (with 🔴 subject) so you know immediately that the disk is missing or inaccessible.

---

## Switching to "Silent on Success" Mode

Once you've verified the monitoring system is working (after a few days of receiving emails), you can switch to sending emails **only when there are problems**:

Edit the check script:

```bash
nano ~/Projects/backups/smartctl_email_check.sh
```

---

## Design Philosophy: Always Send Emails

This monitoring system is designed to **always send an email**, even on success. This is intentional and critical for a monitoring system:

- **Failure modes in monitoring are invisible.** If you only email on problems, you can't tell if the monitoring system itself has stopped working.
- **False sense of security is dangerous.** Silent success can mask a broken system — worse than a false alarm.
- **You need proof it's working.** Regular emails prove the system is alive and functioning.

**Why this matters:**
- If you receive emails daily and suddenly stop → something is wrong
- If you never hear from it → you can't tell if it's working or broken
- If the cron job dies → you'll notice the silence immediately

**Filter if needed:** If daily emails become too much, set up email filters to automatically organize them, but keep receiving them. Never disable emails in the script.

---

## Quick Reference Cheat Sheet

**Check configuration:**
```bash
cat ~/.smartctl_check.env              # View setup details
crontab -l | grep smartctl             # View cron job
```

**Test monitoring:**
```bash
bash ~/Projects/backups/smartctl_email_check.sh  # Run manual check
tail -f ~/.smartctl_check.log                     # Watch logs
```

**Fix issues:**
```bash
cat ~/.msmtp.log                  # Email sending errors
sudo smartctl -H /dev/sdc1        # Check disk directly
crontab -e                        # Edit cron schedule
```

**Remove monitoring:**
```bash
bash ~/Projects/backups/deregister_smartctl_email_cron.sh
```

---

## Next Steps

1. Configure passwordless sudo for smartctl (Step 2 in Setup Process above)
2. Run the registration script: `bash register_smartctl_email_cron.sh`
3. Test manually: `bash smartctl_email_check.sh`
4. Check the log: `tail -f ~/.smartctl_check.log`
5. Wait for the scheduled time (or 1 minute if testing) to see cron in action
6. Mirror the setup on Jaron's side when ready
