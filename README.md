<p align="center">
  <a href="https://www.beeper.com/changelog/desktop">
    <img src="https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/beeper-community/update-beeper/master/.github/badges/beeper-version.json&style=for-the-badge" alt="Beeper Latest">
  </a>
  &nbsp;
  <a href="https://aur.archlinux.org/packages/beeper-v4-bin">
    <img src="https://img.shields.io/aur/version/beeper-v4-bin?label=AUR&style=for-the-badge&color=1793d1" alt="AUR Version">
  </a>
  &nbsp;
  <a href="https://github.com/beeper-community/update-beeper/actions/workflows/lint.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/beeper-community/update-beeper/lint.yml?label=lint&style=for-the-badge" alt="Lint">
  </a>
  &nbsp;
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge" alt="License: MIT">
  </a>
</p>

# update-beeper

A self-healing Beeper Desktop updater for Arch Linux. Downloads directly from Beeper's API with SHA256 verification, retries with targeted fixes on failure, and rolls back automatically if recovery fails. Supports native Wayland, structured logging, and systemd automation.

---

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/install.sh | bash

update-beeper            # Update to latest
update-beeper --versions # Show version status
```

---

## The Problem

<table>
<tr>
<td width="50%">

### Before

```
Beeper Desktop

  "Update Available!"
  [ Restart to Update ]

  * clicks *
  * still on old version *
```

</td>
<td width="50%">

### After

```
🐝 Beeper Updater v1.9.0

[1/8] Checking versions
  ✓ Update available

[4/8] Downloading 4.2.630
  ✓ 213MB verified

╭──────────────────────────────────────╮
│  ✓ Update complete                   │
│  Version  4.2.587 → 4.2.630          │
│  Duration 52s                        │
│  Desktop  beeper-wayland.desktop     │
╰──────────────────────────────────────╯
```

</td>
</tr>
</table>

Beeper's updater tries to replace files in `/opt` owned by pacman, causing a silent failure. This script downloads directly from Beeper's API instead.

---

## Installation

**Quick Install** (recommended):

```bash
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/install.sh | bash
```

**Manual Install:**

```bash
curl -o ~/.local/bin/update-beeper \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/update-beeper
curl -o ~/.local/bin/beeper-version \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/beeper-version
curl -o ~/.local/bin/beeper-health \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/beeper-health

chmod +x ~/.local/bin/update-beeper ~/.local/bin/beeper-version ~/.local/bin/beeper-health
```

**Clone & Install:**

```bash
git clone https://github.com/beeper-community/update-beeper.git
cd update-beeper && ./install.sh
```

> Make sure `~/.local/bin` is in your `PATH`.

---

## Usage

```bash
update-beeper                # Update to latest
update-beeper --versions     # Show all versions
update-beeper --check-desktop # Validate desktop shortcut and icon
update-beeper --dry-run      # Preview without changes
update-beeper --force        # Force reinstall
update-beeper --rollback     # Rollback to previous version
update-beeper --history      # Show past updates
```

### All Flags

| Flag              | Short | Description                          |
|-------------------|-------|--------------------------------------|
| `--check`         | `-c`  | Check without installing             |
| `--force`         | `-f`  | Force reinstall                      |
| `--quiet`         | `-q`  | Errors only (for cron/systemd)       |
| `--notify`        | `-n`  | Desktop notification                 |
| `--rollback`      | `-r`  | Rollback to previous backup          |
| `--changelog`     | `-l`  | Open changelog in browser            |
| `--versions`      |       | Show installed, latest, AUR versions |
| `--dry-run`       |       | Preview what would happen            |
| `--history`       |       | Show update history                  |
| `--skip-checksum` |       | Skip SHA256 verification             |
| `--check-desktop` |       | Validate desktop shortcut and icon   |
| `--branch`        |       | Set or show active branch (stable, nightly) |
| `--whats-new`     | `-w`  | Show changes since installed version |
| `--menu`          | `-m`  | Force interactive menu               |
| `--version`       | `-v`  | Show script version                  |
| `--help`          | `-h`  | Show help                            |

---

## Automatic Updates

```bash
mkdir -p ~/.config/systemd/user
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/systemd/update-beeper-user.service \
  -o ~/.config/systemd/user/update-beeper.service
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/systemd/update-beeper-user.timer \
  -o ~/.config/systemd/user/update-beeper.timer

systemctl --user daemon-reload
systemctl --user enable --now update-beeper.timer
```

Runs daily between 10:00–14:00 (randomized).

---

## Self-Healing

Each stage is verified and retried with targeted fixes before falling back to automatic rollback.

<details>
<summary>Verification and recovery details</summary>

| Failure             | Fix Applied                       |
|---------------------|-----------------------------------|
| Download too small  | Clear temp, retry                 |
| SHA256 mismatch     | Re-download from scratch          |
| Non-ELF binary      | Re-download (corrupted)           |
| Missing files       | Clear squashfs-root, re-extract   |
| Permission errors   | Recursive chown/chmod             |
| Low disk space      | Warn if < 1200MB on `/opt`        |
| Version mismatch    | Fresh download                    |
| Startup crash       | Clear Electron cache, retry       |
| Untrusted domain    | Abort download                    |
| Pacman version desync | Deregister stale AUR DB entry   |
| Orphaned runtime deps | Mark as explicitly installed     |
| All retries fail    | **Automatic rollback** to backup  |

</details>

---

## Interactive Menu

When run with no flags in an interactive terminal (TTY), update-beeper shows an interactive menu instead of running a silent update. Non-interactive contexts (cron, systemd, pipes) still auto-update as before.

```bash
update-beeper          # Shows menu in terminal, auto-updates in cron
update-beeper --menu   # Force menu even with other flags
```

**Backend detection** picks the best available UI: fzf, dialog, whiptail, or a pure-bash fallback -- no extra dependencies required.

**Branch support** lets you switch between `stable` and `nightly` channels. Branch preference persists in `~/.config/update-beeper/config`.

**In-terminal changelog** shows version diffs pulled from cached [beeper-intel](https://github.com/beeper-community/beeper-intel) data (6-hour local cache).

---

## File Locations

| Path | Purpose |
|------|---------|
| `/opt/beeper/` | Installation directory |
| `/opt/beeper-backups/` | Rolling backups (last 3) |
| `~/.config/BeeperTexts/` | User config + caches |
| `~/.local/share/applications/beeper-wayland.desktop` | Desktop shortcut (Wayland) |
| `~/.local/share/icons/hicolor/512x512/apps/beepertexts.png` | Launcher icon |
| `~/.local/share/update-beeper/update-beeper.log` | Event log |
| `~/.local/share/update-beeper/history.txt` | Update history |
| `~/.config/update-beeper/config` | Branch and preferences |
| `~/.cache/update-beeper/checksums.txt` | SHA256 cache |
| `~/.cache/update-beeper/` | Intel data cache (versions, changelog) |

---

## Requirements

| Requirement | Notes |
|-------------|-------|
| **x86_64** | Beeper doesn't provide ARM builds |
| **Arch Linux** | Or Arch-based (Manjaro, EndeavourOS) |
| **curl** | Required |
| **sudo** | Required (installs to `/opt`) |
| **notify-send** | Optional (desktop notifications) |

---

## FAQ

<details>
<summary>Should I keep the AUR package?</summary>

It's optional. After a direct install, the script automatically deregisters the stale AUR entry from pacman's database (v1.6.0+) and preserves runtime dependencies from orphan cleanup (v1.7.0+). If AUR catches up later, you can reinstall with `yay -S beeper-v4-bin`.

</details>

<details>
<summary>What if an update breaks something?</summary>

The script automatically rolls back. You can also run `update-beeper --rollback` manually.

</details>

<details>
<summary>Blank window on Wayland (Hyprland/Sway)?</summary>

Run `update-beeper --force` to reinstall with native Wayland flags. The updater automatically creates a `beeper-wayland.desktop` shortcut, installs the launcher icon, and detects your `~/bin/beeper-wayland` wrapper if present. Run `update-beeper --check-desktop` to validate your shortcut is healthy.

</details>

<details>
<summary>Does this work on non-Arch distros?</summary>

The core updater works on any x86_64 Linux. AUR version checking requires pacman.

</details>

<details>
<summary>Can I get bleeding-edge fixes before a stable release?</summary>

Yes -- run `update-beeper --branch nightly` to switch to the nightly channel. Nightly builds contain crash fixes and patches that haven't reached stable yet. Switch back anytime with `update-beeper --branch stable`.

</details>

---

[CONTRIBUTING.md](CONTRIBUTING.md) · [CHANGELOG.md](CHANGELOG.md) · MIT License

<p align="center">
  <sub>Made with 🐝 for the Beeper community</sub>
</p>
