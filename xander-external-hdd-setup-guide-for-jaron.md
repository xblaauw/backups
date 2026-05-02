# Setting Up Xander's External HDD on Jaron's PC

## Overview

This guide sets up persistent, resilient mounting of Xander's external HDD on your (Jaron's) PC such that:
- The disk always mounts to the same location regardless of USB port or system state
- It survives kernel updates, sudden disconnects, power outages, and reboots
- Only Xander (the non-sudo user) can read/write to the disk
- Accidental writes to your internal SSD are prevented if the external disk is missing

**Prerequisites:**
- You (Jaron) have a sudo account on this PC
- Xander has a non-sudo account with SSH access
- Xander's external HDD is formatted with ext4
- The external HDD is connected during initial setup

---

## Step 1: Get Xander's UID and GID

First, find the user ID of Xander's account. Run this command:

```bash
id xander
```

**Expected output example:**
```
uid=1001(xander) gid=1001(xander) groups=1001(xander),100(users)
```

**Write down:**
- `uid` value (e.g., `1001`)
- `gid` value (e.g., `1001`)

You'll need these values later.

---

## Step 2: Identify Xander's External HDD

Connect the external HDD to your PC and identify its UUID and device path.

```bash
lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL
```

Look for Xander's disk (typically `sdc`, `sdd`, `sde`, etc., depending on how many internal/external drives are already connected).

**Save these values:**
- **Device path**: e.g., `/dev/sdc1`
- **UUID**: e.g., `a1b2c3d4-e5f6-7890-abcd-ef1234567890` (yours will be different)
- **FSTYPE**: Should be `ext4`

**Alternative command** if you're unsure which disk is Xander's:

```bash
sudo lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINT
```

Xander should tell you the approximate size of his disk (e.g., "1.8TB" or "2TB").

---

## Step 3: Create the Mount Point Directory

Create the directory where Xander's disk will mount. Use `/media/xander` as the mount point.

```bash
sudo mkdir -p /media/xander
```

---

## Step 4: Configure Filesystem Root Permissions

Xander's ext4 filesystem stores ownership/permissions in its root inode. 
These permissions will apply whenever the disk is mounted. Set them now so only Xander can access the disk.

**Mount the disk temporarily:**

```bash
sudo mount /dev/sdc1 /media/xander
```

(Replace `/dev/sdc1` with Xander's actual device path from Step 2.)

**Set ownership and permissions on the filesystem root:**

```bash
sudo chown xander:xander /media/xander
sudo chmod 700 /media/xander
```

(Replace `xander:xander` with the actual uid:gid from Step 1 if it's different from `1001:1001`.)

**Unmount the disk:**

```bash
sudo umount /media/xander
```

**What you just did:**
- These ownership/permissions are stored inside the ext4 filesystem itself
- They will apply every time the disk is mounted
- They survive unmounts, USB port changes, and reboots
- No other user (including you) can access the mounted filesystem

---

## Step 5: Secure the Bare Mount Point Directory

When the disk is not mounted, `/media/xander` is just a directory on your SSD.
Make it read-only to prevent Xander from accidentally writing to your internal drive if the external disk fails to mount.

```bash
sudo chown xander:xander /media/xander
sudo chmod 500 /media/xander
```

**Why mode 500 (r-x)?**
- Xander can access the directory (read + execute) to trigger the automount
- But cannot write to it (no write permission)
- When the disk is mounted, the 700 permissions on the filesystem root apply instead
- This prevents silent data loss if the disk is missing

---

## Step 6: Add Entry to /etc/fstab

Edit `/etc/fstab` to make the mount persistent across reboots:

```bash
sudo nano /etc/fstab
```

(Or use `sudo vi /etc/fstab` if you prefer vim.)

At the end of the file, add this line. **Replace the UUID with Xander's actual UUID from Step 2:**

```
UUID=a1b2c3d4-e5f6-7890-abcd-ef1234567890  /media/xander  ext4  noauto,x-systemd.automount,x-systemd.device-timeout=5,nofail,errors=remount-ro,noatime  0  0
```

**Save and exit** the editor (Ctrl+O, Enter, Ctrl+X in nano; `:wq` in vi).

**Option Explanations:**

| Option | Purpose |
|---|---|
| `UUID=...` | Persistent identification — doesn't change if USB port changes |
| `noauto` | Don't mount at boot — let the automount system handle it |
| `x-systemd.automount` | Create systemd automount unit; mounts on first access |
| `x-systemd.device-timeout=5` | Fail quickly if disk is missing (prevents SSH timeouts) |
| `nofail` | Boot succeeds even if the disk is not plugged in |
| `errors=remount-ro` | On filesystem errors, remount read-only (prevents corruption) |
| `noatime` | Skip access-time updates (reduces writes, safer for sudden disconnects) |

---

## Step 7: Reload systemd and Activate Automount

Tell systemd to regenerate mount units from the updated `/etc/fstab`:

```bash
sudo systemctl daemon-reload
```

Now explicitly restart the automount unit to activate it:

```bash
sudo systemctl restart media-xander.automount
```

This ensures the automount is ready to intercept access attempts.

---

## Step 8: Verify the Setup

Run these tests to confirm everything works correctly.

### Test 1: Automount Triggers on Access

Have Xander access the disk:

```bash
sudo -u xander ls /media/xander
```

**Expected output:** Directory listing showing actual disk contents (e.g., `kopia_backup2`, `lost+found`, or whatever is on Xander's disk).

**If you see:** `Permission denied` → Permissions not set correctly. Go back to Step 4.

**If you see:** `No such device` → Disk is not connected. Connect it and try again.

### Test 2: You Cannot Access the Disk

Try accessing the disk as yourself (the sudo user):

```bash
ls /media/xander
```

**Expected output:** `ls: cannot open directory '/media/xander': Permission denied`

This is correct — the disk is Xander's, not yours.

### Test 3: Confirm Mount is Active

Check the mount status:

```bash
findmnt /media/xander
```

**Expected output:** Shows two layers:
- `systemd-1 autofs` (the automount system)
- `/dev/sdc1 ext4` (the actual filesystem)

If you see neither, try accessing the disk first (Test 1) to trigger the automount.

### Test 4: Disk Disconnection Handling

**Disconnect the USB cable** and have Xander try to access:

```bash
sudo -u xander touch /media/xander/test.txt
```

**Expected behavior:**
- Command hangs for ~5-10 seconds
- Then fails with: `touch: cannot touch '/media/xander/test.txt': No such device`
- **Important:** No silent writes to your internal SSD

### Test 5: Port Independence

**Reconnect the USB to a different port** and have Xander try accessing:

```bash
sudo -u xander ls /media/xander
```

**Expected behavior:**
- Takes ~30-40 seconds (udev detection and device settling)
- Then succeeds with disk contents
- Works regardless of which USB port was used

### Test 6: Filesystem Permissions

Check the actual mounted filesystem permissions:

```bash
stat /media/xander
```

**Expected output:** Shows `xander xander` ownership with mode `700` (or `drwx------`).

---

## Step 9: Cleanup and Document

Remove any test files created during verification:

```bash
sudo -u xander rm -f /media/xander/test.txt /media/xander/jaron-test*.txt
```

**Document for future reference:**
- Xander's disk UUID: `a1b2c3d4-e5f6-7890-abcd-ef1234567890` (replace with actual)
- Device path used: `/dev/sdc1` (replace with actual)
- Mount point: `/media/xander`
- Xander's UID: `1001` (replace if different)

---

## What You've Set Up

**Resilience:**

| Failure Scenario | Behavior |
|---|---|
| Disk in different USB port | UUID finds it automatically; mounts at same location |
| Boot without disk connected | System boots normally; mount waits for access |
| Disk connected after boot | Auto-mounts on first access |
| Access attempt while disk missing | Timeout after ~5-10 seconds; fails cleanly |
| Sudden disconnect mid-backup | ext4 journal handles recovery on next mount |
| Power outage during write | ext4 journal + `errors=remount-ro` protects integrity |
| Kernel update / reboot | UUID + fstab persist unchanged |
| Accidental writes if disk missing | Read-only bare mount point prevents writes to your SSD |

**Access Control:**
- Only Xander can read/write to the mounted filesystem
- You (as sudo user) can still access it with `sudo`, but this is expected
- Other non-sudo users cannot access it

---

## Troubleshooting

### Issue: Test 1 shows "No such device"

**Cause:** Disk is not connected.

**Solution:**
1. Plug in the USB cable
2. Wait 30-40 seconds for the system to detect it
3. Run `lsblk` to verify it appears
4. Try Test 1 again

### Issue: Test 1 shows "Permission denied"

**Cause:** Filesystem permissions were not set correctly in Step 4.

**Solution:**
1. Unmount: `sudo umount /media/xander`
2. Re-do Step 4 (make sure you used the correct UID/GID)
3. Run Test 1 again

### Issue: Test 2 should show "Permission denied" but doesn't

**Cause:** Filesystem permissions are too open (not 700).

**Solution:**
1. Unmount: `sudo umount /media/xander`
2. Mount temporarily: `sudo mount /dev/sdc1 /media/xander`
3. Fix permissions: `sudo chmod 700 /media/xander`
4. Unmount: `sudo umount /media/xander`
5. Run Test 2 again

### Issue: Test 3 shows nothing

**Cause:** The automount unit hasn't been triggered yet.

**Solution:**
1. Run Test 1 to trigger the automount
2. Run Test 3 again
3. If still nothing, check the automount unit: `systemctl list-units --type automount | grep xander`
4. If not present, re-do Step 7

### Issue: Test 4 doesn't timeout, just succeeds

**Cause:** The disk is still connected (Test 4 requires physical disconnection).

**Solution:**
1. Actually unplug the USB cable (verify it's no longer visible in `lsblk`)
2. Try again

### Issue: Boot hangs waiting for disk

**Cause:** `nofail` option missing from fstab.

**Solution:**
1. Check the fstab entry: `grep "UUID=" /etc/fstab | grep xander`
2. Verify it includes `nofail`
3. If missing, edit `/etc/fstab` and add it
4. Run: `sudo systemctl daemon-reload`

---

## Notes for Xander

Share this information with Xander so he knows what to expect:

- **First access is slow:** The first time after connecting the disk, accessing `/media/xander` takes ~30-40 seconds (udev detection).
- **Subsequent access is fast:** Once mounted, it's instant.
- **Different USB ports work:** The disk will work in any USB port on this PC.
- **Safe failure mode:** If the disk disconnects, access attempts fail cleanly (no silent writes to Jaron's SSD).
- **Before backups:** Always check disk space with `df -h /media/xander` and verify the disk is connected.

---

## Next Steps

Xander can now use his disk on your PC:

```bash
ls /media/xander                    # Check contents
df -h /media/xander                 # Check disk space
cp /my/data /media/xander           # Backup data
```

The disk will persist across reboots, kernel updates, and USB port changes. It's ready for reliable backups.
