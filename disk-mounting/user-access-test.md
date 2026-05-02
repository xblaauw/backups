# Disk Access Test Guide

**Version:** 1.0  
**Last Updated:** 2026-05-02

This guide lets you verify that your external HDD is properly set up and ready for backups.

**Run these tests before doing important backups.**

---

## Quick Check (30 seconds)

Can you access your disk right now?

```bash
ls /media/<your-username>
```

Replace `<your-username>` with your actual Linux username (the one used in the mount point setup).

**If it works:** You'll see directory names like `kopia_backup2`, `lost+found`, etc.

**If it fails with "Permission denied":** Something is wrong with your setup — contact your admin.

**If it fails with "No such device":** The disk is not connected. Connect it via USB and wait ~30-40 seconds, then try again.

---

## Full Test Suite

Run these in order to verify everything is working correctly.

### Test 1: Access Your Disk

```bash
ls -la /media/<your-username>
```

Replace `<your-username>` with your actual Linux username.

**Expected:** You see the contents of your disk. No errors.

**If you see:** `Permission denied` → Setup problem. Contact your admin.

**If you see:** `No such device` → Disk is not connected. Connect it and wait.

---

### Test 2: Create a Test File

```bash
touch /media/<your-username>/test-file.txt
```

Replace `<your-username>` with your actual Linux username.

**Expected:** No output. File is created.

**If you see:** `Permission denied` → You don't own the disk (wrong setup).

**If you see:** `No such device` → Disk is not connected.

---

### Test 3: Write Data

```bash
echo "Test data from $(date)" > /media/<your-username>/test.txt
cat /media/<your-username>/test.txt
```

Replace `<your-username>` with your actual Linux username.

**Expected:** Echoes back "Test data from [today's date]".

**If it fails:** The disk is not writable. Contact your admin.

---

### Test 4: Clean Up Test Files

```bash
rm /media/<your-username>/test-file.txt /media/<your-username>/test.txt
```

Replace `<your-username>` with your actual Linux username.

---

### Test 5: Check Disk Space

```bash
df -h /media/<your-username>
```

Replace `<your-username>` with your actual Linux username.

**Expected:** Shows disk size, used space, and available space.

Example output:
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdc1       1.8T  500G  1.3T  28% /media/<your-username>
```

**This tells you:**
- Total disk size: 1.8T
- Currently used: 500G
- Space available for backups: 1.3T

---

### Test 6: Verify Mount is Persistent

```bash
mountpoint /media/<your-username>
```

Replace `<your-username>` with your actual Linux username.

**Expected:** `/media/<your-username> is a mountpoint`

**If you see:** `/media/<your-username> is not a mountpoint` → Disk is not mounted. Accessing it will auto-mount it.

---

### Test 7: Disk Disconnection Simulation (Optional)

This simulates what happens if the disk suddenly disconnects while you're using it.

**Before you start:** Have the disk connected.

```bash
# Try to access the disk (should work)
ls /media/<your-username>

# Now, physically unplug the USB cable

# Try to access again (within 10 seconds)
ls /media/<your-username>
```

Replace `<your-username>` with your actual Linux username.

**Expected:** First command works. After unplugging, the second command waits ~5-10 seconds then shows error: `No such device`.

**Why this test matters:** This confirms that your backups won't silently write to the system's internal SSD if the external disk disconnects.

**Reconnect the disk** to a different USB port and wait ~30-40 seconds. You should be able to access it again.

---

## Before Running Your Backups

✅ Run **Test 1** (Quick access — verify you can reach your disk)  
✅ Run **Test 5** (Check disk space — make sure you have enough)  
✅ If both pass, your disk is ready for backups

---

## Troubleshooting

### Problem: I get "Permission denied" when accessing my disk mount

This means the disk is not set up for your user. You should **not** be able to get this error — the setup gives you full access.

**Action:** Contact your admin. The disk ownership/permissions need to be fixed.

### Problem: I get "No such device" when accessing my disk mount

The disk is not connected.

**Action:** 
1. Plug in the USB cable
2. Wait 30-40 seconds (the system needs time to detect it)
3. Try again: `ls /media/<your-username>`

Replace `<your-username>` with your actual Linux username.

### Problem: I can access the disk, but writes are very slow

The disk might be:
- Connected to a bad USB port (try a different port)
- Performing a background check/repair (normal after sudden disconnect)
- Nearly full (run `df -h /media/<your-username>` to check)

Replace `<your-username>` with your actual Linux username.

**Action:** 
- Try a different USB port
- Check available space with `df -h /media/<your-username>`
- Wait a few minutes and try again

### Problem: Access suddenly stops working mid-backup

The disk probably disconnected.

**Action:**
1. Check the USB connection (reseat the cable)
2. Wait 30-40 seconds
3. Try accessing again: `ls /media/<your-username>`

Replace `<your-username>` with your actual Linux username.

If it was a sudden disconnect, your backup may be incomplete. Don't assume the data was written.

### Problem: I forgot to check if my disk is connected before starting a backup

The backup process will:
1. Try to access `/media/<your-username>`
2. Wait ~5-10 seconds
3. Fail with `No such device` error

Replace `<your-username>` with your actual Linux username.

Your backup will **not** silently write to the system's internal SSD. This is intentional — the disk is set up to protect against accidental data loss.

---

## Quick Reference

| Command | What it does |
|---|---|
| `ls /media/<your-username>` | List your disk contents |
| `df -h /media/<your-username>` | Check disk space |
| `touch /media/<your-username>/filename` | Create a test file |
| `mountpoint /media/<your-username>` | Check if disk is mounted |

Replace `<your-username>` with your actual Linux username in all commands.

---

## Notes

- **First access is slow:** The first time you access the disk after connecting it, the system needs ~30-40 seconds to detect and mount it. This is normal.
- **Subsequent access is fast:** Once mounted, access is instant.
- **Different USB ports:** The disk will work in any USB port. The first time you use a new port, expect ~30-40 seconds of detection time.
- **Always check space before backups:** Use `df -h /media/<your-username>` to verify you have enough space.
- **Read-only when disconnected:** If you try to access the disk while it's unplugged, you'll get a quick error instead of the system hanging or writing to the wrong place.

Replace `<your-username>` with your actual Linux username.

---

## Questions?

If something doesn't work as described in this guide, contact your admin with:
1. **What test failed** (Test 1, Test 5, etc.)
2. **The exact error message** you got
3. **Whether the disk is connected** via USB
