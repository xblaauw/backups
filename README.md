# Backup & Monitoring Setup Documentation

**Version:** 1.0  
**Last Updated:** 2026-05-02  
**Purpose:** Complete setup for persistent external HDD mounting and SMART health monitoring with email alerts

---

## What's In This Folder

This folder contains everything needed to set up and maintain:
1. **Persistent external HDD mounting** — mounts always go to the same place, survive reboots/kernel updates/USB port changes
2. **SMART health monitoring** — daily checks with email alerts on failure or disk disconnection

## Quick Start

**Choose your task:**

### Setup an External HDD Mount (Multi-User Access)
Start here if you're setting up an external disk for reliable access across reboots and USB ports.

- **For your own laptop:** Read `jaron-disk-mount-guide.md`
- **For another person's laptop:** Read `xander-external-hdd-setup-guide-for-jaron.md`
- **To test access after setup:** Read `jaron-disk-access-test.md`

### Setup SMART Health Monitoring
Start here if you want automated daily health checks with email alerts.

- **Complete setup guide:** Read `smartctl-monitoring-setup.md`
- **Scripts:** `register_smartctl_email_cron.sh`, `smartctl_email_check.sh`, `deregister_smartctl_email_cron.sh`

## Files at a Glance

| File | Purpose | Audience |
|------|---------|----------|
| `jaron-disk-mount-guide.md` | Step-by-step mount setup for single person | Someone setting up their own external HDD |
| `xander-external-hdd-setup-guide-for-jaron.md` | Setup guide for another person's HDD | Someone helping a friend set up their disk |
| `jaron-disk-access-test.md` | Quick tests to verify disk is accessible | Person using the disk after setup |
| `smartctl-monitoring-setup.md` | Complete SMART monitoring setup (prerequisites, scripts, troubleshooting) | Anyone setting up health monitoring |
| `register_smartctl_email_cron.sh` | Interactive registration script for monitoring | Run this after reading smartctl guide |
| `smartctl_email_check.sh` | Automated health check script | Run by cron; also useful for manual testing |
| `deregister_smartctl_email_cron.sh` | Remove monitoring setup | Run to clean up |

## Setup Order (Most Common Scenario)

1. **First time?** Set up the disk mount
   - Read: `jaron-disk-mount-guide.md`
   - Follow all 9 steps, verify at the end
   
2. **Want monitoring?** Set up SMART checks
   - Read: `smartctl-monitoring-setup.md` (prerequisites + setup process)
   - Run: `bash register_smartctl_email_cron.sh`
   - Test: `bash smartctl_email_check.sh`

3. **Need to test disk access?** 
   - Read: `jaron-disk-access-test.md`

## Recovery After 1+ Year (Amnesia Mode)

Forgot how this works? Here's what you need:

```bash
# Check what's configured
cat ~/.smartctl_check.env          # Monitoring settings
crontab -l | grep smartctl         # Cron job details
cat ~/.smartctl_check.log          # Recent check history

# Test that everything still works
bash ~/Projects/backups/smartctl_email_check.sh  # Manual health check
tail -f ~/.smartctl_check.log                     # Watch for results

# Verify mount is accessible
ls /media/jaron                     # Should list disk contents
```

If something's broken, go to the **Troubleshooting** section in the relevant markdown file.

## Key Concepts (Understand These)

### Persistent Mount
- Uses **UUID** (not device name like `/dev/sdc1`) so it works even if USB port changes
- Uses **systemd automount** so disk mounts on first access
- **Permissions stored in filesystem** so they persist across everything
- Mount point is **read-only when disk absent** to prevent accidental SSD writes

### SMART Monitoring
- **Always sends email** — even on success, so you know the system is working
- **Stores password securely** in `~/.smartctl_email_creds` (mode 600)
- **Requires passwordless sudo** for smartctl in crontab
- **Uses msmtp** (lightweight SMTP client) to send emails
- **Flexible on SMTP provider** — Gmail (with 2FA) or custom SMTP server

## Common Tasks

### Change monitoring schedule
```bash
crontab -e
# Find the smartctl line, edit the time (see cron format in smartctl-monitoring-setup.md)
```

### Check disk health manually
```bash
bash ~/Projects/backups/smartctl_email_check.sh
```

### View monitoring logs
```bash
tail -f ~/.smartctl_check.log
```

### Stop monitoring (keep disk mount)
```bash
bash ~/Projects/backups/deregister_smartctl_email_cron.sh
```

### See what's mounted
```bash
findmnt /media/jaron
```

### Mirror setup on another laptop
- For mounting: Use `xander-external-hdd-setup-guide-for-jaron.md` (adjust names)
- For monitoring: Run `register_smartctl_email_cron.sh` on that laptop

## Troubleshooting Quick Links

- Disk not mounting? → See "Troubleshooting" in `jaron-disk-mount-guide.md`
- Emails not arriving? → See "Troubleshooting" in `smartctl-monitoring-setup.md`
- Can't access disk as user? → Check mount permissions in `jaron-disk-access-test.md`

## Security Notes

- **Credentials:** Stored in `~/.smartctl_email_creds` (mode 600) and `~/.msmtprc` (mode 600)
- **Don't commit:** These files should never be in git — they contain passwords
- **Don't share:** Each person should have their own SMTP credentials
- **Sudo:** Only `smartctl` command is passwordless, nothing else

## Support

Each markdown file has a **Troubleshooting** section. Start there.

If stuck:
1. Check the relevant guide's troubleshooting
2. Look at log files: `~/.smartctl_check.log`, `~/.msmtp.log`
3. Test manually: Run the check script by hand to see errors
4. Review the "Understanding" sections in each guide

---

**Next:** Pick your task from "Quick Start" above and open the relevant markdown file.
