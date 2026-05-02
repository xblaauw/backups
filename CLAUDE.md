# CLAUDE.md: Guide for Claude Code Agents

This file instructs Claude Code agents how to help users set up persistent external HDD mounting and SMART monitoring.

**All authoritative documentation and code is referenced below using @ syntax. Load everything at the start.**

---

## Load Full Repository Context

When helping a user with this project, load these files to have complete context:

@README.md
@disk-mounting/setup-admin.md
@smart-monitoring/setup.md
@smart-monitoring/troubleshooting.md
@smart-monitoring/scripts/register.sh
@smart-monitoring/scripts/check.sh
@smart-monitoring/scripts/deregister.sh

---

## Agent Behavior

### Important: Admin Privileges Required

**Before starting, tell the user:**

> "This process requires admin/sudo privileges. I (Claude) don't have those privileges, so you'll need to run commands in a terminal on your actual system.
>
> **Here's how:**
> 1. Open a second terminal on your laptop (separate from this chat)
> 2. I'll give you commands one at a time
> 3. You run them in that terminal
> 4. Copy the output and paste it back here so I can verify it worked
>
> **For copying in Linux terminals:** Use `Ctrl+Shift+C` to copy and `Ctrl+Shift+V` to paste (not Ctrl+C/V like Windows)."

---

### When User Wants Setup Help

1. **Ask clarifying questions upfront:**
   - "What are you setting up? (New disk mount? SMART monitoring? Both?)"
   - "Will this be for you, or someone else?"
   - "How comfortable are you with Linux commands?"
   - "Do you have sudo access? Is the drive ext4? Is it connected now?"

2. **Choose the right guide from loaded context:**
   - Disk mounting → follow `disk-mounting/setup-admin.md` exactly
   - SMART monitoring → follow `smart-monitoring/setup.md` exactly
   - Troubleshooting → use `smart-monitoring/troubleshooting.md`

3. **For each step:**
   - Explain what the command does
   - Give one command at a time
   - Wait for user to run it
   - Ask them to verify it worked
   - Read their output and confirm before proceeding

4. **If anything fails:**
   - Stop and diagnose (don't skip ahead)
   - Reference the troubleshooting section
   - Only proceed when resolved

### Key Principles

- **MD files are authoritative** — follow them exactly
- **Verify each step** before moving to the next
- **Make the user feel in control** — explain, ask permission, never assume
- **Diagnose problems** — don't skip them
- **Users run commands** — you don't run them on their behalf
