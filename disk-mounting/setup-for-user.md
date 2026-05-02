# Setting Up Another User's External HDD

**Version:** 1.0  
**Last Updated:** 2026-05-02

## Overview

This guide sets up persistent, resilient mounting of another user's external HDD on your PC such that:
- The disk always mounts to the same location regardless of USB port or system state
- It survives kernel updates, sudden disconnects, power outages, and reboots
- Only the target user can read/write to the disk
- Accidental writes to your internal SSD are prevented if the external disk is missing

**Prerequisites:**
- You have a sudo account on this PC (admin)
- The target user has a non-sudo account with access to this PC
- The target user's external HDD is formatted with ext4
- The external HDD is connected during initial setup

---

## Step 1: Get the Target User's UID and GID

First, find the user ID of the target user's account. Run this command:

```bash
id <target-user>
```

Replace `<target-user>` with the actual username.

**Expected output example:**
```
uid=1001(<target-user>) gid=1001(<target-user>) groups=1001(<target-user>),100(users)
```

**Write down:**
- `uid` value (e.g., `1001`)
- `gid` value (e.g., `1001`)

You'll need these values later.

---

## Step 2: Identify the Target User's External HDD

Connect the external HDD to your PC and identify its UUID and device path.

```bash
lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL
```

Look for the disk (typically `sdc`, `sdd`, `sde`, etc., depending on how many internal/external drives are already connected).

**Save these values:**
- **Device path**: e.g., `/dev/sdc1`
- **UUID**: e.g., `a1b2c3d4-e5f6-7890-abcd-ef1234567890`
- **FSTYPE**: Should be `ext4`

**Alternative command** if you're unsure which disk is the target user's:

```bash
sudo lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINT
```

The target user should tell you the approximate size of their disk (e.g., "1.8TB" or "2TB").

---

## Step 3: Create the Mount Point Directory

Create the directory where the target user's disk will mount. Use `/media/<target-user>` as the mount point.

```bash
sudo mkdir -p /media/<target-user>
```

Replace `<target-user>` with the target user's actual username.

---

## Step 4: Configure Filesystem Root Permissions

The target user's ext4 filesystem stores ownership/permissions in its root inode. 
These permissions will apply whenever the disk is mounted. Set them now so only the target user can access the disk.

**Mount the disk temporarily:**

```bash
sudo mount /dev/sdc1 /media/<target-user>
```

Replace `/dev/sdc1` with the actual device path from Step 2 and `<target-user>` with the target user's actual username.

**Set ownership and permissions on the filesystem root:**

```bash
sudo chown <target-user>:<target-user> /media/<target-user>
sudo chmod 700 /media/<target-user>
```

(Replace the usernames with the actual uid:gid from Step 1.)

**Unmount the disk:**

```bash
sudo umount /media/<target-user>
```

Replace `<target-user>` with the target user's actual username.

**What you just did:**
- These ownership/permissions are stored inside the ext4 filesystem itself
- They will apply every time the disk is mounted
- They survive unmounts, USB port changes, and reboots
- No other user (including you) can access the mounted filesystem

---

## Step 5: Secure the Bare Mount Point Directory

When the disk is not mounted, `/media/<target-user>` is just a directory on your SSD.
Make it read-only to prevent the target user from accidentally writing to your internal drive if the external disk fails to mount.

```bash
sudo chown <target-user>:<target-user> /media/<target-user>
sudo chmod 500 /media/<target-user>
```

Replace `<target-user>` with the target user's actual username.

**Why mode 500 (r-x)?**
- The target user can access the directory (read + execute) to trigger the automount
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

At the end of the file, add this line. **Replace the UUID with the actual UUID from Step 2 and `<target-user>` with the target user's username:**

```
UUID=<actual-uuid>  /media/<target-user>  ext4  noauto,x-systemd.automount,x-systemd.device-timeout=5,nofail,errors=remount-ro,noatime  0  0
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
sudo systemctl restart media-<target-user>.automount
```

Replace `<target-user>` with the target user's actual username. This ensures the automount is ready to intercept access attempts.

---

## Step 8: Verify the Setup

Run these tests to confirm everything works correctly.

### Test 1: Automount Triggers on Access

Have the target user access the disk:

```bash
sudo -u <target-user> ls /media/<target-user>
```

Replace `<target-user>` with the target user's actual username.

**Expected output:** Directory listing showing actual disk contents.

**If you see:** `Permission denied` → Permissions not set correctly. Go back to Step 4.

**If you see:** `No such device` → Disk is not connected. Connect it and try again.

### Test 2: You Cannot Access the Disk

Try accessing the disk as yourself (the sudo user):

```bash
ls /media/<target-user>
```

Replace `<target-user>` with the target user's actual username.

**Expected output:** `ls: cannot open directory '/media/<target-user>': Permission denied`

This is correct — the disk is the target user's, not yours.

### Test 3: Confirm Mount is Active

Check the mount status:

```bash
findmnt /media/<target-user>
```

Replace `<target-user>` with the target user's actual username.

**Expected output:** Shows two layers:
- `systemd-1 autofs` (the automount system)
- `/dev/sdc1 ext4` (the actual filesystem)

If you see neither, try accessing the disk first (Test 1) to trigger the automount.

### Test 4: Disk Disconnection Handling

**Disconnect the USB cable** and have the target user try to access:

```bash
sudo -u <target-user> touch /media/<target-user>/test.txt
```

Replace `<target-user>` with the target user's actual username.

**Expected behavior:**
- Command hangs for ~5-10 seconds
- Then fails with: `touch: cannot touch '/media/<target-user>/test.txt': No such device`
- **Important:** No silent writes to your internal SSD

### Test 5: Port Independence

**Reconnect the USB to a different port** and have the target user try accessing:

```bash
sudo -u <target-user> ls /media/<target-user>
```

Replace `<target-user>` with the target user's actual username.

**Expected behavior:**
- Takes ~30-40 seconds (udev detection and device settling)
- Then succeeds with disk contents
- Works regardless of which USB port was used

### Test 6: Filesystem Permissions

Check the actual mounted filesystem permissions:

```bash
stat /media/<target-user>
```

Replace `<target-user>` with the target user's actual username.

**Expected output:** Shows `<target-user> <target-user>` ownership with mode `700` (or `drwx------`).

---

## Step 9: Cleanup and Document

Remove any test files created during verification:

```bash
sudo -u <target-user> rm -f /media/<target-user>/test.txt
```

Replace `<target-user>` with the target user's actual username.

**Document for future reference:**
- Target user's disk UUID: `<actual-uuid>`
- Device path used: `<actual-device>`
- Mount point: `/media/<target-user>`
- Target user's UID: `<actual-uid>`

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
- Only the target user can read/write to the mounted filesystem
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
1. Unmount: `sudo umount /media/<target-user>`
2. Re-do Step 4 (make sure you used the correct UID/GID)
3. Run Test 1 again

Replace `<target-user>` with the target user's actual username.

### Issue: Test 2 should show "Permission denied" but doesn't

**Cause:** Filesystem permissions are too open (not 700).

**Solution:**
1. Unmount: `sudo umount /media/<target-user>`
2. Mount temporarily: `sudo mount /dev/sdc1 /media/<target-user>`
3. Fix permissions: `sudo chmod 700 /media/<target-user>`
4. Unmount: `sudo umount /media/<target-user>`
5. Run Test 2 again

Replace `<target-user>` with the target user's actual username.

### Issue: Test 3 shows nothing

**Cause:** The automount unit hasn't been triggered yet.

**Solution:**
1. Run Test 1 to trigger the automount
2. Run Test 3 again
3. If still nothing, check the automount unit: `systemctl list-units --type automount | grep <target-user>`
4. If not present, re-do Step 7

Replace `<target-user>` with the target user's actual username.

### Issue: Test 4 doesn't timeout, just succeeds

**Cause:** The disk is still connected (Test 4 requires physical disconnection).

**Solution:**
1. Actually unplug the USB cable (verify it's no longer visible in `lsblk`)
2. Try again

### Issue: Boot hangs waiting for disk

**Cause:** `nofail` option missing from fstab.

**Solution:**
1. Check the fstab entry: `grep "UUID=" /etc/fstab | grep <target-user>`
2. Verify it includes `nofail`
3. If missing, edit `/etc/fstab` and add it
4. Run: `sudo systemctl daemon-reload`

Replace `<target-user>` with the target user's actual username.

---

## Notes for the Target User

Share this information with the target user so they know what to expect:

- **First access is slow:** The first time after connecting the disk, accessing `/media/<target-user>` takes ~30-40 seconds (udev detection).
- **Subsequent access is fast:** Once mounted, it's instant.
- **Different USB ports work:** The disk will work in any USB port on this PC.
- **Safe failure mode:** If the disk disconnects, access attempts fail cleanly (no silent writes to the system SSD).
- **Before backups:** Always check disk space with `df -h /media/<target-user>` and verify the disk is connected.

Replace `<target-user>` with the target user's actual username.

---

## Next Steps

The target user can now use their disk on your PC:

```bash
ls /media/<target-user>                    # Check contents
df -h /media/<target-user>                 # Check disk space
cp /my/data /media/<target-user>           # Backup data
```

Replace `<target-user>` with the target user's actual username.

The disk will persist across reboots, kernel updates, and USB port changes. It's ready for reliable backups.
