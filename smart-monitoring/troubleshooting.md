# SMART Monitoring Troubleshooting

**Version:** 1.0  
**Last Updated:** 2026-05-02

## Common Issues

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
bash ~/Projects/backups/smart-monitoring/scripts/deregister.sh
bash ~/Projects/backups/smart-monitoring/scripts/register.sh
```

### Issue: "Permission denied" when running smartctl

**Cause:** User doesn't have sudo access to read the device.

**Solution:**
```bash
sudo visudo
```

Add this line at the end:
```
<username> ALL=(ALL) NOPASSWD: /usr/sbin/smartctl
```

(Replace `<username>` with your actual username.)

Save and exit. Then test again:
```bash
bash ~/Projects/backups/smart-monitoring/scripts/check.sh
```

### Issue: Device not found (`/dev/sdc1`)

**Verify the device exists:**
```bash
lsblk
```

Look for your disk. If it's at a different path (e.g., `/dev/sdd1`), you need to:

**Option 1: Re-register**
```bash
bash ~/Projects/backups/smart-monitoring/scripts/deregister.sh
bash ~/Projects/backups/smart-monitoring/scripts/register.sh
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
bash ~/Projects/backups/smart-monitoring/scripts/check.sh
```

## Removing the Setup

If you want to stop monitoring:

```bash
bash ~/Projects/backups/smart-monitoring/scripts/deregister.sh
```

You'll be prompted to remove credentials and configuration files. Choose yes to clean up everything.
