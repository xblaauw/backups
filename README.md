# Backup & Monitoring Setup Documentation

**Version:** 1.0  
**Last Updated:** 2026-05-02

---

## Hardware Setup & Project Goals

### Hardware Configuration

This project manages external HDD storage for systems with the following setup:

- **Primary Machine:** Linux laptop with multiple user accounts
  - **OS Drive:** SSD (~220GB) with OS and critical files
  - **Internal Storage:** Optional internal HDD for additional capacity
  - **External Storage:** One or more external HDDs connected via USB
  
- **User Accounts:** 
  - **Admin account** — has sudo access, manages system configuration
  - **Regular user account(s)** — non-sudo, uses disk for personal backups

- **External Disks:**
  - ext4-formatted HDD(s) for reliable, cross-platform compatibility
  - May be rotated between machines or shared between users
  - Subject to disconnection, USB port changes, system reboots

### Project Goals

1. **Persistent Disk Mounting**
   - Mount external HDDs to consistent paths regardless of:
     - Which USB port is used
     - System reboots
     - Kernel updates
     - Disk disconnection and reconnection
   - Ensure only authorized users can access each disk
   - Prevent accidental data writes to the small SSD if external disk is missing

2. **Health Monitoring & Early Warning**
   - Detect disk failures before data loss occurs
   - Monitor SMART health status continuously
   - Alert admin immediately if problems detected
   - Maintain activity logs for troubleshooting

3. **Multi-User Support**
   - Allow non-sudo users to reliably access their backup disks
   - Support multiple disks on same system
   - Support replicating setup across multiple machines
   - No password sharing required between users

4. **Resilience & Data Protection**
   - Survive hardware failures gracefully (bad USB ports, power outages)
   - Prevent silent data loss (fail loudly, not quietly)
   - Recover automatically from temporary disconnections
   - Maintain filesystem integrity under all conditions

---

## What's In This Folder

This folder contains everything needed to set up and maintain:
1. **Persistent external HDD mounting** — mounts always go to the same place, survive reboots/kernel updates/USB port changes
2. **SMART health monitoring** — daily checks with email alerts on failure or disk disconnection

## Quick Start

**Choose your task:**

### I'm Setting Up My Own External HDD
- Read: `disk-mounting/setup-admin.md`
- Test after setup: `disk-mounting/user-access-test.md`

### I'm Setting Up Someone Else's Disk
- Read: `disk-mounting/setup-for-user.md`

### I Want Automated Health Monitoring
- Read: `smart-monitoring/setup.md`
- Run: `bash smart-monitoring/scripts/register.sh`

## Files at a Glance

### Disk Mounting

| File | Purpose |
|------|---------|
| `disk-mounting/setup-admin.md` | Admin: set up your own disk mount |
| `disk-mounting/setup-for-user.md` | Admin: set up a disk for another user |
| `disk-mounting/user-access-test.md` | User: verify disk is accessible after setup |

### SMART Monitoring

| File | Purpose |
|------|---------|
| `smart-monitoring/setup.md` | Complete SMART monitoring setup (all prerequisites + steps) |
| `smart-monitoring/scripts/check.sh` | Automated health check script |
| `smart-monitoring/scripts/register.sh` | Interactive registration for monitoring |
| `smart-monitoring/scripts/deregister.sh` | Remove monitoring setup |
| `smart-monitoring/troubleshooting.md` | Troubleshooting and common issues |

## Setup Order (Most Common Scenario)

1. **Set up the disk mount** (one-time)
   - Admin reads: `disk-mounting/setup-admin.md`
   - Follow all steps, verify at the end

2. **Set up SMART monitoring** (optional but recommended)
   - Admin reads: `smart-monitoring/setup.md`
   - Run: `bash smart-monitoring/scripts/register.sh`
   - Test: `bash smart-monitoring/scripts/check.sh`

3. **User tests access** (after admin setup)
   - User reads: `disk-mounting/user-access-test.md`
   - Verify disk is accessible before running backups

## Key Concepts

### Persistent Mount (UUID-Based)
- Uses filesystem **UUID** (not device name) so it works even if USB port changes
- Uses **systemd automount** so disk mounts on first access
- Permissions stored in **filesystem itself** so they persist across everything
- Mount point is **read-only when disk absent** to prevent accidental SSD writes

### SMART Monitoring
- **Always sends email** — even on success, so you know the system is working
- Stores password securely in `~/.smartctl_email_creds` (mode 600)
- Requires **passwordless sudo** for smartctl in crontab
- Uses **msmtp** (lightweight SMTP client) to send emails
- Flexible on SMTP provider — Gmail (with 2FA) or custom SMTP server

## Recovery After 1+ Year (Amnesia Mode)

Forgot how this works? Here's what you need:

```bash
# Check what's configured
cat ~/.smartctl_check.env          # Monitoring settings
crontab -l | grep smartctl         # Cron job details
cat ~/.smartctl_check.log          # Recent check history

# Test that everything still works
bash ~/Projects/backups/smart-monitoring/scripts/check.sh  # Manual health check
tail -f ~/.smartctl_check.log                              # Watch for results

# Verify mount is accessible
ls /media/jaron                     # Should list disk contents
findmnt /media/jaron               # Show mount details
```

## Common Tasks

### Change monitoring schedule
```bash
crontab -e
# Find the smartctl line, edit the time (see cron format in setup.md)
```

### Check disk health manually
```bash
bash ~/Projects/backups/smart-monitoring/scripts/check.sh
```

### View monitoring logs
```bash
tail -f ~/.smartctl_check.log
```

### Stop monitoring (keep disk mount)
```bash
bash ~/Projects/backups/smart-monitoring/scripts/deregister.sh
```

### See what's mounted
```bash
findmnt /media/jaron
```

### Mirror setup on another laptop
- For mounting: Use `disk-mounting/setup-for-user.md` (adjust user names)
- For monitoring: Run `smart-monitoring/scripts/register.sh` on that laptop

## Troubleshooting Quick Links

- Disk not mounting? → See `disk-mounting/setup-admin.md` (Troubleshooting section)
- Emails not arriving? → See `smart-monitoring/troubleshooting.md`
- Can't access disk as user? → See `disk-mounting/user-access-test.md`

## Security Notes

- **Credentials:** Stored in `~/.smartctl_email_creds` (mode 600) and `~/.msmtprc` (mode 600)
- **Don't commit:** These files should never be in git — they contain passwords
- **Don't share:** Each person should have their own SMTP credentials
- **Sudo:** Only `smartctl` command is passwordless; nothing else

---

**Next:** Pick your task from "Quick Start" above and open the relevant guide.
