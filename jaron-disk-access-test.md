# Disk Access Test Guide

**Version:** 1.0  
**Last Updated:** 2026-05-02

This guide lets you verify that your external HDD is properly set up and ready for backups.

**Run these tests before doing important backups.**

---

## Quick Check (30 seconds)

Can you access your disk right now?

```bash
ls /media/jaron
```

**If it works:** You'll see directory names like `kopia_backup2`, `lost+found`, etc.

**If it fails with "Permission denied":** Something is wrong with your setup — contact xander.

**If it fails with "No such device":** The disk is not connected. Connect it via USB and wait ~30-40 seconds, then try again.

---

## Full Test Suite

Run these in order to verify everything is working correctly.

### Test 1: Access Your Disk

```bash
ls -la /media/jaron
```

**Expected:** You see the contents of your disk. No errors.

**If you see:** `Permission denied` → Setup problem. Contact xander.

**If you see:** `No such device` → Disk is not connected. Connect it and wait.

---

### Test 2: Create a Test File

```bash
touch /media/jaron/jaron-test-file.txt
```

**Expected:** No output. File is created.

**If you see:** `Permission denied` → You don't own the disk (wrong setup).

**If you see:** `No such device` → Disk is not connected.

---

### Test 3: Write Data

```bash
echo "Test data from $(date)" > /media/jaron/jaron-test.txt
cat /media/jaron/jaron-test.txt
```

**Expected:** Echoes back "Test data from [today's date]".

**If it fails:** The disk is not writable. Contact xander.

---

### Test 4: Clean Up Test Files

```bash
rm /media/jaron/jaron-test-file.txt /media/jaron/jaron-test.txt
```

---

### Test 5: Check Disk Space

```bash
df -h /media/jaron
```

**Expected:** Shows disk size, used space, and available space.

Example output:
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdc1       1.8T  500G  1.3T  28% /media/jaron
```

**This tells you:**
- Total disk size: 1.8T
- Currently used: 500G
- Space available for backups: 1.3T

---

### Test 6: Verify Mount is Persistent

```bash
mountpoint /media/jaron
```

**Expected:** `/media/jaron is a mountpoint`

**If you see:** `/media/jaron is not a mountpoint` → Disk is not mounted. Accessing it will auto-mount it.

---

### Test 7: Disk Disconnection Simulation (Optional)

This simulates what happens if the disk suddenly disconnects while you're using it.

**Before you start:** Have the disk connected.

```bash
# Try to access the disk (should work)
ls /media/jaron

# Now, physically unplug the USB cable

# Try to access again (within 10 seconds)
ls /media/jaron
```

**Expected:** First command works. After unplugging, the second command waits ~5-10 seconds then shows error: `No such device`.

**Why this test matters:** This confirms that backups won't silently write to xander's internal SSD if the external disk disconnects.

**Reconnect the disk** to a different USB port and wait ~30-40 seconds. You should be able to access it again.

---

## Before Running Your Backups

✅ Run **Test 1** (Quick access)  
✅ Run **Test 5** (Check disk space — make sure you have enough)  
✅ If both pass, your disk is ready for backups

---

## Troubleshooting

### Problem: I get "Permission denied" when accessing `/media/jaron`

This means the disk is not set up for your user. You should **not** be able to get this error — the setup gives you full access.

**Action:** Contact xander. The disk ownership/permissions need to be fixed.

### Problem: I get "No such device" when accessing `/media/jaron`

The disk is not connected.

**Action:** 
1. Plug in the USB cable
2. Wait 30-40 seconds (the system needs time to detect it)
3. Try again: `ls /media/jaron`

### Problem: I can access the disk, but writes are very slow

The disk might be:
- Connected to a bad USB port (try a different port)
- Performing a background check/repair (normal after sudden disconnect)
- Nearly full (run `df -h /media/jaron` to check)

**Action:** 
- Try a different USB port
- Check available space with `df -h /media/jaron`
- Wait a few minutes and try again

### Problem: Access suddenly stops working mid-backup

The disk probably disconnected.

**Action:**
1. Check the USB connection (reseat the cable)
2. Wait 30-40 seconds
3. Try accessing again: `ls /media/jaron`

If it was a sudden disconnect, your backup may be incomplete. Don't assume the data was written.

### Problem: I forgot to check if my disk is connected before starting a backup

The backup process will:
1. Try to access `/media/jaron`
2. Wait ~5-10 seconds
3. Fail with `No such device` error

Your backup will **not** silently write to xander's internal SSD. This is intentional — the disk is set up to protect against accidental data loss.

---

## Quick Reference

| Command | What it does |
|---|---|
| `ls /media/jaron` | List your disk contents |
| `df -h /media/jaron` | Check disk space |
| `touch /media/jaron/filename` | Create a test file |
| `mountpoint /media/jaron` | Check if disk is mounted |

---

## Notes

- **First access is slow:** The first time you access the disk after connecting it, the system needs ~30-40 seconds to detect and mount it. This is normal.
- **Subsequent access is fast:** Once mounted, access is instant.
- **Different USB ports:** The disk will work in any USB port. The first time you use a new port, expect ~30-40 seconds of detection time.
- **Always check space before backups:** Use `df -h /media/jaron` to verify you have enough space.
- **Read-only when disconnected:** If you try to access the disk while it's unplugged, you'll get a quick error instead of the system hanging or writing to the wrong place.

---

## Questions?

If something doesn't work as described in this guide, contact xander with:
1. **What test failed** (Test 1, Test 5, etc.)
2. **The exact error message** you got
3. **Whether the disk is connected** via USB
