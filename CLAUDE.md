# Persistent External HDD Setup Guide

## Purpose

This document guides a new agent (and the user) through setting up **persistent, resilient mounting** of an external HDD on a Linux laptop. The setup ensures the drive:
- Always mounts to the same location (regardless of USB port)
- Survives reboots, kernel updates, and sudden disconnections
- Protects against accidental data loss if the drive is missing
- (Optionally) includes automated SMART health monitoring with email alerts

## How This Guide Works

**The agent should:**
1. Ask the user clarifying questions upfront
2. Explain what will happen and how the agent will verify each step
3. Load all relevant files using `@filename` syntax so full context is available
4. Give clear, single commands (not scripts with multiple steps)
5. **After each user action, verify it succeeded** before proceeding
6. Explain *what* and *why*, not just *how*
7. Make the user feel in control — pause frequently and check understanding

**The agent should NOT:**
- Assume the user knows Linux commands
- Rush through steps
- Run commands on the user's behalf (except where explicitly approved upfront)
- Proceed if verification fails without diagnosing the issue

---

## Starting the Conversation

### Step 1: Ask Clarifying Questions

Before proceeding, ask:

1. **What do you want to set up?**
   - "Do you want to mount a single external HDD? Or multiple disks?"
   - "Will this be for yourself, or are you setting this up for someone else on your laptop?"

2. **SMART monitoring (optional):**
   - "Do you want automated daily health checks on the drive with email alerts if problems are detected?"
   - If yes: "Who should receive email alerts?"

3. **Comfort level:**
   - "How comfortable are you running Linux commands? (Just so I know if I should explain more.)"
   - "After I give you a command, would you like me to verify it worked before we continue?"

4. **Prerequisites:**
   - "Do you have sudo access on this laptop?"
   - "Is the external drive already formatted with ext4?"
   - "Do you have the drive physically connected right now?"

### Step 2: Explain the Approach

Once you understand what the user needs, say something like:

> "Here's what we'll do:
> 1. **Identify your drive** — find its device path and UUID
> 2. **Create a mount point** — a folder where the drive will appear
> 3. **Fix permissions** — ensure only the right user can access it
> 4. **Add to fstab** — tell Linux how to mount it automatically
> 5. **Test the setup** — verify it works after reboot and port changes
> 6. (Optional) **Set up monitoring** — daily health checks via email
>
> After each step, I'll ask you to verify it worked. If something looks wrong, we'll diagnose it together. You're in control — let me know if you want to slow down or skip anything."

### Step 3: Confirm Understanding

Ask:
- "Does this approach make sense?"
- "Are you ready to start?"
- "Do you have 30-45 minutes? (This takes time, but there's no rush.)"

---

## The Setup Process

### Phase 1: Gather Information

**Goal:** Identify the drive and the user it belongs to.

1. **Ask the user to run:**
   ```bash
   lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL
   ```

2. **Wait for output, then ask:**
   - "Which disk is yours? (Look for size, label, or description you recognize.)"
   - Once identified, ask them to provide: device path, UUID, size

3. **Verify:**
   - Read back: "So your drive is `/dev/sdX1`, UUID `xxx-xxx-xxx`, about `YYY GB`, right?"
   - Confirm before proceeding.

4. **Ask for mount point:**
   - "What username should own this drive? (Your username, or someone else's?)"
   - "The drive will mount at `/media/<username>`. That OK?"

---

### Phase 2: Prepare the System

**Before touching the filesystem, verify prerequisites.**

1. **Check sudo access:**
   ```bash
   sudo -l | head -5
   ```
   If it asks for a password, they have sudo. If it says "not allowed", stop — they need admin help.

2. **Check ext4 filesystem:**
   - Ask: "Is the drive currently mounted or visible in any file manager?"
   - If mounted: ask them to safely eject/unmount it
   - Explain: "We need to temporarily mount it to fix permissions. When we do, all existing files are safe — we're not changing them, just who can access them."

3. **Disconnect the drive:**
   - Explain: "Disconnect the USB cable. We'll reconnect it after we set up the system files."

---

### Phase 3: Create Mount Point & Fix Permissions

**Load context:**
> @disk-mounting/setup-admin.md

1. **Explain what's about to happen:**
   - "We're going to create a folder where your drive will appear, then fix the permissions on the drive itself so only the right user can access it."
   - "This uses ext4's filesystem-level permissions, so the settings survive unplugging, rebooting, everything."

2. **Create the mount point:**
   ```bash
   sudo mkdir -p /media/<username>
   ```
   Verify:
   ```bash
   ls -la /media/ | grep <username>
   ```
   Should show a directory owned by root.

3. **Reconnect the drive.**
   - Explain: "The system will likely auto-mount it temporarily. That's OK."
   - Wait for them to say it's plugged in.

4. **Fix filesystem permissions:**
   - Explain: "We're mounting the drive, changing who owns it inside the filesystem, then unmounting it. This takes < 1 minute."
   - Give them these commands one at a time:

   ```bash
   sudo mount /dev/sdX1 /media/<username>
   ```
   Ask: "Did it show any errors, or is it quiet?"

   ```bash
   sudo chown <username>:<username> /media/<username>
   ```
   Ask: "Anything error-like?"

   ```bash
   sudo chmod 700 /media/<username>
   ```
   Ask: "OK?"

   ```bash
   sudo umount /media/<username>
   ```
   Ask: "Unmounted?"

5. **Verify permissions were set:**
   - Explain: "We're checking that the permissions stuck. This confirms the filesystem owns them internally."
   - Reconnect the drive.
   - Ask them to run:
   ```bash
   stat /media/<username> | grep -E "Access:|Uid:"
   ```
   - Verify output shows `<username>` as owner and mode `0700` (or `drwx------`).

---

### Phase 4: Add fstab Entry

**Load context:**
> @disk-mounting/setup-admin.md

1. **Explain what fstab is:**
   - "fstab is a file that tells Linux how to mount drives. We're going to add an entry so your drive mounts automatically based on its UUID (the unique identifier), not the device name (which can change if you use different USB ports)."

2. **Show the entry they'll add:**
   ```
   UUID=<your-uuid>  /media/<username>  ext4  noauto,x-systemd.automount,x-systemd.device-timeout=5,nofail,errors=remount-ro,noatime,sync  0  0
   ```

3. **Ask them to edit:**
   ```bash
   sudo nano /etc/fstab
   ```
   - Guide them: "Scroll to the bottom. Paste the line we just showed you. Replace `<your-uuid>` and `<username>`."
   - Remind: "Ctrl+O to save, Enter, Ctrl+X to exit."

4. **Verify the entry was added:**
   ```bash
   cat /etc/fstab | tail -3
   ```
   - Confirm the line is there, with correct UUID and username.

---

### Phase 5: Activate the Setup

1. **Reload systemd:**
   ```bash
   sudo systemctl daemon-reload
   ```
   (Should be quiet.)

2. **Restart the automount unit:**
   ```bash
   sudo systemctl restart media-<username>.automount
   ```
   (Should be quiet.)

3. **Explain what just happened:**
   - "We told the system to re-read fstab and activate the automount unit. Now when you access `/media/<username>`, it'll automatically mount the drive if it's plugged in."

---

### Phase 6: Test the Setup

1. **Access the drive:**
   ```bash
   ls /media/<username>
   ```
   - Should show the drive's contents (or be empty if it's empty).
   - Ask: "Do you see files/folders? Or is it empty?"

2. **Check mount status:**
   ```bash
   findmnt /media/<username>
   ```
   - Should show both the automount layer and the actual ext4 mount.
   - Explain: "If you see both layers, the automount system is working. Good sign."

3. **Disconnect the drive and test failure mode:**
   - Explain: "We're testing what happens if you accidentally try to access the drive when it's not plugged in. Should fail quickly, not hang."
   - Disconnect USB.
   - Ask them to run (they'll need to interrupt after 5-10 seconds):
   ```bash
   ls /media/<username>
   ```
   - Should fail with "No such device" or "Resource temporarily unavailable" — not hang, not write to internal SSD.
   - Explain: "Perfect — it failed cleanly. That's what we want."

4. **Reconnect to a different USB port and verify:**
   - Explain: "Now we'll test port independence. Plug the drive into a different USB port and wait 30-40 seconds for the system to detect it."
   - Wait for confirmation.
   - Ask them to run:
   ```bash
   ls /media/<username>
   ```
   - Should work.
   - Verify mount shows the drive is still mounted:
   ```bash
   findmnt /media/<username>
   ```

---

## Optional: Set Up SMART Monitoring

**Load context:**
> @smart-monitoring/setup.md

Only if the user wants automated health checks.

1. **Identify the device again:**
   ```bash
   lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL | grep <your-uuid>
   ```
   - Note the current `/dev/sdX1` path (may have changed if ports were swapped).

2. **Run the registration script:**
   ```bash
   bash ~/Projects/backups/smart-monitoring/scripts/register.sh
   ```
   - Guide them through the prompts (device path, recipient email, SMTP choice).
   - After it completes, ask:
   ```bash
   crontab -l | grep SMARTCTL_DEVICE
   ```
   - Verify the cron job appears.

3. **Test manually:**
   ```bash
   bash ~/Projects/backups/smart-monitoring/scripts/check.sh
   ```
   - Should send an email and log a result.
   - Explain: "The script ran successfully. You should receive an email in a few seconds. Check for it."

---

## After Setup

**Summarize what they've accomplished:**
- ✓ Drive mounts automatically at `/media/<username>` based on UUID
- ✓ Works across USB port changes
- ✓ Fails safely if disconnected (no silent SSD writes)
- ✓ Survives reboots and kernel updates
- ✓ (Optional) Automated daily health checks

**Offer next steps:**
- "Want to test a full reboot?"
- "Want to set up another drive the same way?"
- "Any questions about what we set up?"

---

## Troubleshooting During Setup

If something fails:

1. **Don't proceed.** Stop and diagnose.
2. **Check the error message.** Ask the user to copy-paste the exact error.
3. **Use these checks:**
   ```bash
   # Is the drive detected?
   lsblk
   
   # Is fstab correct?
   cat /etc/fstab | grep <uuid>
   
   # Is the automount unit active?
   systemctl list-units --type automount | grep <username>
   
   # What does the system log say?
   dmesg | tail -20
   ```
4. **Diagnose together.** Don't guess. Read error messages with them.

---

## Key Files (Load with @filename)

The agent should have these files fully available:

- @disk-mounting/setup-admin.md — Full setup procedure with detailed explanations
- @smart-monitoring/setup.md — SMART monitoring guide
- @smart-monitoring/troubleshooting.md — Common issues and fixes
- @smart-monitoring/scripts/register.sh — Registration script (if reviewing)
- @README.md — High-level project overview

---

## Agent Behavior Summary

**Be:**
- Patient and non-judgmental
- Clear about what each command does
- Diligent about verifying each step
- Willing to diagnose problems, not skip them
- Respectful of the user's comfort level

**Don't:**
- Assume technical knowledge
- Rush through explanations
- Run commands without the user explicitly doing it
- Proceed if verification fails
- Make the user feel stupid for asking questions

**Always:**
- Ask clarifying questions upfront
- Explain what, why, and how
- Verify after each step before proceeding
- Check understanding frequently
- Make the user feel in control
