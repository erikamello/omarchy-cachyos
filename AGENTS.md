# Agent Handoff

This repository is a CachyOS compatibility fork of Omarchy. Treat it as a
compatibility fork, not as a plain conflict-resolution fork.

Before changing update, install, package, login, kernel, NVIDIA, filesystem,
session, or migration behavior, read:

- `docs/update-from-upstream.md` - repeatable method for merging stable Omarchy
  into this fork.
- `$HOME/dev/github/system-assembly-report.md` - current machine assembly report
  with boot, filesystem, desktop, package, and NVIDIA facts.

## Current Model

- Active Omarchy source: `$HOME/.local/share/omarchy` points at this checkout.
- Maintained branch: `cachyos/main`.
- Upstream stable branch: `upstream/master` from `basecamp/omarchy`.
- Historical branch: `dev`; do not use it for stable updates unless the human
  explicitly asks.
- Do not run installers or system-level update scripts unless the human
  explicitly asks. Updating this repo and applying system changes are separate
  operations.

## Compatibility Policy

Preserve these machine-specific decisions unless the human explicitly changes
direction:

- CachyOS is the OS base.
- KDE/SDDM coexist with Omarchy/Hyprland.
- Boot is GRUB, not Limine.
- Root and home are ext4, not Btrfs/Snapper.
- CachyOS owns pacman configuration, repositories, hooks, and package-manager
  defaults.
- NVIDIA handling must respect CachyOS kernel-bound packages.
- Fish shell support matters; do not assume Bash-only user behavior.
- Committed code and docs must avoid personal absolute paths. Use `$HOME`, `~`,
  `$OMARCHY_PATH`, or repo-relative paths.
- Keep `tldr` out of the base package list because `tealdeer` provides the
  command on this system.

## Upstream Update Rule

For upstream Omarchy updates, Git conflicts are only the visible part. Also
audit non-conflicting upstream changes for assumptions about:

- Limine or Plymouth
- Btrfs or Snapper
- vanilla Arch package names
- Omarchy-owned pacman config
- Omarchy's expected NVIDIA package model
- Hyprland-only session assumptions
- Bash-only shell assumptions
- hard-coded local/user paths

Take upstream improvements by default, but reject or adapt upstream changes that
would damage this CachyOS/KDE/GRUB/ext4 setup. Keep the downstream delta small
and explicit.

## High-Risk Files

Changes in these paths need extra care:

- `bin/omarchy-update-restart`
- `config/uwsm/env`
- `install/config/hardware/nvidia.sh`
- `install/login/all.sh`
- `install/omarchy-base.packages`
- `install/post-install/all.sh`
- `install/preflight/all.sh`
- `migrations/*.sh`
- anything under `default/limine`, `default/plymouth`, `default/pacman`, or
  `default/snapper`

## Verification Essentials

Before reporting an update or compatibility change as done, run the relevant
checks from `docs/update-from-upstream.md`. At minimum, verify:

```bash
git status --short --branch
git diff --check
! rg -n -P "\\x2fhome\\x2f${USER}(?=/|$)|\\x2fUsers\\x2f${USER}(?=/|$)" .
! grep -qx 'tldr' install/omarchy-base.packages
! grep -q 'preflight/pacman.sh' install/preflight/all.sh
! grep -q 'post-install/pacman.sh' install/post-install/all.sh
! grep -E 'limine|plymouth' install/login/all.sh
```

For changed shell files, run `bash -n` on each changed shell script before
committing.

# Upstream Style

- Two spaces for indentation, no tabs
- Use bash 5 conditionals: use `[[ ]]` for string/file tests and `(( ))` for numeric tests
- In `[[ ]]`, don't quote variables, but do quote string literals when comparing values (e.g., `[[ $branch == "dev" ]]`)
- Prefer `(( ))` over numeric operators inside `[[ ]]` (e.g., `(( count < 50 ))`, not `[[ $count -lt 50 ]]`)
- For strings/paths with spaces, quote them instead of escaping spaces with `\ ` (e.g., `"$APP_DIR/Disk Usage.desktop"`, not `$APP_DIR/Disk\ Usage.desktop`)
- Shebangs must use `#!/bin/bash` consistently (never `#!/usr/bin/env bash`)

# Command Naming

All commands start with `omarchy-`. Prefixes indicate purpose:

- `cmd-` - check if commands exist, misc utility commands
- `pkg-` - package management helpers
- `hw-` - hardware detection (return exit codes for use in conditionals)
- `refresh-` - copy default config to user's `~/.config/`
- `restart-` - restart a component
- `launch-` - open applications
- `install-` - install optional software
- `setup-` - interactive setup wizards
- `toggle-` - toggle features on/off
- `theme-` - theme management
- `update-` - update components

# Helper Commands

Use these instead of raw shell commands:

- `omarchy-cmd-missing` / `omarchy-cmd-present` - check for commands
- `omarchy-pkg-missing` / `omarchy-pkg-present` - check for packages
- `omarchy-pkg-add` - install packages (handles both pacman and AUR)
- `omarchy-hw-asus-rog` - detect ASUS ROG hardware (and similar `hw-*` commands)

# Config Structure

- `config/` - default configs copied to `~/.config/`
- `default/themed/*.tpl` - templates with `{{ variable }}` placeholders for theme colors
- `themes/*/colors.toml` - theme color definitions (accent, background, foreground, color0-15)

# Refresh Pattern

To copy a default config to user config with automatic backup:

```bash
omarchy-refresh-config hypr/hyprlock.conf
```

This copies `~/.local/share/omarchy/config/hypr/hyprlock.conf` to `~/.config/hypr/hyprlock.conf`.

# Migrations

To create a new migration, run `omarchy-dev-add-migration --no-edit`. This creates a migration file named after the unix timestamp of the last commit.

Migration format:
- No shebang line
- Start with an `echo` describing what the migration does
- Use `$OMARCHY_PATH` to reference the omarchy directory

Example:
```bash
echo "Disable fingerprint in hyprlock if fingerprint auth is not configured"

if omarchy-cmd-missing fprintd-list || ! fprintd-list "$USER" 2>/dev/null | grep -q "finger"; then
  sed -i 's/fingerprint:enabled = .*/fingerprint:enabled = false/' ~/.config/hypr/hyprlock.conf
fi
```
