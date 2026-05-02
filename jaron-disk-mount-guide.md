# Persistent External HDD Mount for Multi-User Access

## Overview

This guide sets up persistent, resilient mounting of an external HDD that:
- Always mounts to the same location regardless of USB port or system state
- Survives kernel updates, sudden disconnects, power outages, and reboots
- Provides exclusive access to a specific non-sudo user (e.g., Jaron)
- Prevents accidental writes to the internal drive if the external disk is missing

**Prerequisites:**
- Two user accounts: one with sudo (e.g., xander), one without (e.g., jaron)
- External HDD already formatted with ext4
- The external disk should be connected during initial setup

---

## Step 1: Identify the Disk

Connect the external HDD and identify its UUID and device path.

```bash
lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL
```

Look for your disk (typically named `sdc`, `sdd`, etc.). Note:
- **Device path**: e.g., `/dev/sdc1`
- **UUID**: e.g., `cc6e9ded-5c6f-4d4f-baac-2360c40359fc`
- **FSTYPE**: Should be `ext4`

```bash
# Alternative: use blkid to see just the UUID
blkid /dev/sdc1
# Output: /dev/sdc1: UUID="cc6e9ded-5c6f-4d4f-baac-2360c40359fc" TYPE="ext4"
```

**Save these values — you'll need them in later steps.**

---

## Step 2: Determine Target User's ID

Get the UID and GID of the user who will own the disk (e.g., jaron).

```bash
id jaron
# Output: uid=1001(jaron) gid=1001(jaron) groups=1001(jaron),100(users)
```

---

## Step 3: Create Mount Point Directory

Create the directory where the disk will mount. Use a simple path like `/media/jaron`.

```bash
sudo mkdir -p /media/jaron
```

---

## Step 4: Fix Filesystem Root Permissions

The ext4 filesystem's root inode stores ownership/permissions that will apply when the disk is mounted. 
This must be set so only the target user can access it.

```bash
# Mount the disk temporarily
sudo mount /dev/sdc1 /media/jaron

# Change ownership and permissions on the filesystem root
# This affects the disk's actual root directory, not the mount point
sudo chown jaron:jaron /media/jaron
sudo chmod 700 /media/jaron

# Unmount
sudo umount /media/jaron
```

**Why this works:**
- ext4 stores permissions inside the filesystem itself
- These permissions survive unmounts, USB port changes, and reboots
- Any user besides jaron (and root) cannot access the mounted filesystem

---

## Step 5: Secure the Bare Mount Point

When the disk is not mounted, `/media/jaron` is just a directory on your SSD. 
Make it read-only to prevent accidental writes if the disk fails to mount.

```bash
sudo chown jaron:jaron /media/jaron
sudo chmod 500 /media/jaron
```

**Why mode 500 (r-x)?**
- Jaron can access the directory (read + execute)
- But cannot write to it (no write permission)
- The automount system can still intercept access and mount the real disk
- When the disk is mounted, the 700 permissions on the filesystem root apply instead

---

## Step 6: Add fstab Entry

Edit `/etc/fstab` and add an entry for the disk. This makes the mount persistent across reboots.

```bash
sudo nano /etc/fstab
# or use: sudo vi /etc/fstab
```

Add this line (replace the UUID with your actual UUID):

```
UUID=cc6e9ded-5c6f-4d4f-baac-2360c40359fc  /media/jaron  ext4  noauto,x-systemd.automount,x-systemd.device-timeout=5,nofail,errors=remount-ro,noatime  0  0
```

**Option Explanations:**

| Option | Purpose |
|---|---|
| `UUID=...` | Persistent identification (port-agnostic) |
| `noauto` | Don't mount at boot — let automount handle it |
| `x-systemd.automount` | Create a systemd automount unit; mounts on first access |
| `x-systemd.device-timeout=5` | Fail quickly if disk missing (prevents SSH hangs) |
| `nofail` | Boot succeeds even if disk is not plugged in |
| `errors=remount-ro` | On filesystem errors, go read-only (prevents corruption) |
| `noatime` | Skip access-time updates (reduces writes, safer for sudden disconnects) |

Save and exit the editor.

---

## Step 7: Reload systemd

Tell systemd to regenerate mount units from the updated `/etc/fstab`.

```bash
sudo systemctl daemon-reload
```

---

## Step 8: Restart the Automount Unit

The automount unit may not activate immediately after `daemon-reload`. 
Explicitly restart it to ensure it's ready.

```bash
sudo systemctl restart media-jaron.automount
```

**Why this step?**  
In our testing, the automount unit was created but inactive until explicitly restarted. 
Without this, access might not trigger the automount correctly.

---

## Step 9: Verify the Setup

Run these tests to confirm everything works:

### Test 1: Automount Triggers on Access

```bash
# Access the disk as the target user (jaron)
sudo -u jaron ls /media/jaron
```

**Expected output:** Directory listing showing actual disk contents (e.g., `kopia_backup2`, `lost+found`).

### Test 2: Other Users Cannot Access

```bash
# Try accessing as another user (e.g., xander or another sudo user)
ls /media/jaron
```

**Expected output:** `ls: cannot open directory '/media/jaron': Permission denied`

### Test 3: Confirm Mount is Active

```bash
findmnt /media/jaron
```

**Expected output:** Shows both the automount layer (systemd-1 autofs) and the actual ext4 mount.

### Test 4: Disk Disconnection Handling

**Disconnect the USB cable** and try to access:

```bash
sudo -u jaron touch /media/jaron/test.txt
```

**Expected behavior:**
- Command hangs for ~5-10 seconds (the device timeout)
- Then fails with: `touch: cannot touch '/media/jaron/test.txt': No such device`
- **Important:** No silent writes to your internal SSD

### Test 5: Port Independence

**Reconnect the USB cable to a different port** and try accessing again:

```bash
sudo -u jaron ls /media/jaron
```

**Expected behavior:**
- Takes ~30-40 seconds for udev detection and device settling
- Then succeeds with disk contents
- (Longer than normal because the system doesn't recognize the device immediately on a new port)

### Test 6: Permissions on Mounted Filesystem

```bash
# Check the actual permissions on the mounted root
stat /media/jaron
```

**Expected output:** Shows `jaron jaron 700` (or similar: `drwx------`).

---

## Troubleshooting

### Issue: `findmnt` shows nothing after fstab edit

**Cause:** The automount unit exists but hasn't been activated yet.

**Solution:**
```bash
sudo systemctl daemon-reload
sudo systemctl restart media-jaron.automount
```

Then try accessing the mount point again to trigger the automount.

### Issue: Files created in `/media/jaron` but disk not mounted

**Cause:** The automount unit is present but not intercepting access properly.

**Solution:**
1. Verify the unit exists: `systemctl list-units --type automount | grep jaron`
2. Restart it: `sudo systemctl restart media-jaron.automount`
3. Try accessing again: `sudo -u jaron ls /media/jaron`

### Issue: Jaron can write to bare mount point (before disk mounts)

**Cause:** Mount point directory has write permissions (mode 700).

**Solution:** Change to read-only:
```bash
sudo umount /media/jaron  # if currently mounted
sudo chmod 500 /media/jaron
```

Then test that writes fail:
```bash
sudo -u jaron touch /media/jaron/test.txt  # should fail or trigger automount
```

### Issue: Boot hangs waiting for disk

**Cause:** `nofail` option missing from fstab entry.

**Solution:** Verify the fstab line includes `nofail`:
```bash
grep "UUID=cc6e9ded" /etc/fstab
```

Should show the option. If missing, edit `/etc/fstab` and add it.

### Issue: Long delays when accessing disk (30-40 seconds)

**Cause:** Udev/kernel needs time to detect and initialize the device, especially on a different USB port.

**Expected behavior:** This is normal for external USB devices. The `x-systemd.device-timeout=5` applies to missing devices, not slow devices.

**Mitigation:** Always use the same USB port if responsiveness matters (but UUID-based setup means different ports still work).

---

## Resilience Summary

This setup handles:

| Failure Scenario | Behavior |
|---|---|
| Disk in different USB port | UUID finds it automatically; mounts at same location |
| Boot without disk connected | System boots normally; mount waits for access |
| Disk connected after boot | Auto-mounts on first access (`x-systemd.automount`) |
| Access attempt while disk missing | Timeout after ~5-10 seconds; fails cleanly |
| Sudden disconnect mid-write | ext4 journal handles recovery on next mount |
| Power outage during write | ext4 journal + `errors=remount-ro` protects integrity |
| Kernel update / reboot | UUID + fstab entries persist unchanged |
| Intermittent USB connection | Each reconnect is detected; automount re-triggers |
| Accidental writes if disk missing | Read-only bare mount point (mode 500) prevents this |

---

## Permanent Automount (Optional)

If you want the disk to mount automatically at boot (assuming it's connected), change the fstab line to:

```
UUID=cc6e9ded-5c6f-4d4f-baac-2360c40359fc  /media/jaron  ext4  auto,nofail,x-systemd.device-timeout=5,errors=remount-ro,noatime  0  0
```

Change:
- `noauto` → `auto` (mount at boot if device is present)
- Remove `x-systemd.automount` (no longer needed if always mounting at boot)

Then `sudo systemctl daemon-reload` to apply.

**Trade-off:** Boot time increases by ~5-10 seconds if the disk is slow or not yet initialized when systemd tries to mount it.

---

## Verifying After Reboot

After a reboot, verify the setup still works:

```bash
# With disk connected:
sudo -u jaron ls /media/jaron  # should work
ls /media/jaron                 # should fail

# Without disk connected:
sudo -u jaron ls /media/jaron  # should timeout then fail
```

---

## Notes

- **Permission ownership:** The filesystem root must be owned by the target user (e.g., `jaron:jaron`). This is set during Step 4 and stored inside the ext4 filesystem itself.

- **Mount point vs. filesystem:** The bare directory `/media/jaron` on the SSD and the ext4 filesystem's root are separate. Step 4 configures the filesystem; Steps 3, 5 configure the mount point.

- **UUID vs. device names:** `/dev/sdc1` can change to `/dev/sdd1` if USB order changes. UUID never changes, making it the reliable identifier.

- **Systemd automount behavior:** Even with `noauto`, the automount unit intercepts access attempts and mounts the disk if the device is available. This is why writes can trigger a mount — it's intentional and prevents silent SSD writes if the disk is present but unmounted.

- **Read-only mount point:** Mode 500 on the bare mount point prevents accidental writes when the disk is missing, but the automount system can still trigger the real mount. When the disk is mounted, the filesystem root's 700 permissions apply instead.
