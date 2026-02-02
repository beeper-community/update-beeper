<p align="center">

```
                          ██╗   ██╗██████╗ ██████╗  █████╗ ████████╗███████╗
                          ██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝
                          ██║   ██║██████╔╝██║  ██║███████║   ██║   █████╗  
                          ██║   ██║██╔═══╝ ██║  ██║██╔══██║   ██║   ██╔══╝  
                          ╚██████╔╝██║     ██████╔╝██║  ██║   ██║   ███████╗
                           ╚═════╝ ╚═╝     ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝
    ╔═══════════════════════════════════════════════════════════════════════════════════╗
    ║                                                                                   ║
    ║      ██████╗ ███████╗███████╗██████╗ ███████╗██████╗         __         __        ║
    ║      ██╔══██╗██╔════╝██╔════╝██╔══██╗██╔════╝██╔══██╗       /  \.-"""-./  \       ║
    ║      ██████╔╝█████╗  █████╗  ██████╔╝█████╗  ██████╔╝      /    \_   _/    \      ║
    ║      ██╔══██╗██╔══╝  ██╔══╝  ██╔═══╝ ██╔══╝  ██╔══██╗     /  (   \ | /   )  \     ║
    ║      ██████╔╝███████╗███████╗██║     ███████╗██║  ██║    |    \___\|/___/    |    ║
    ║      ╚═════╝ ╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝     \      /_\      /      ║
    ║                                                             '-.._____...-'        ║
    ║   ════════════════════════════════════════════════════════════════════════════    ║
    ║                                                                                   ║
    ║          🐝 Self-healing  •  Auto-rollback  •  Arch Linux  •  Wayland 🐝          ║
    ║                                                                                   ║
    ╚═══════════════════════════════════════════════════════════════════════════════════╝
```

</p>

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

<p align="center">
  <b>A self-healing Beeper Desktop updater for Arch Linux</b><br>
  <i>Because Beeper's "Update Available" button should actually work</i>
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-the-problem">The Problem</a> •
  <a href="#-features">Features</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-usage">Usage</a> •
  <a href="#-automatic-updates">Automation</a>
</p>

---

## 🚀 Quick Start

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/install.sh | bash

# Check your version status
beeper-version

# Update to latest
update-beeper
```

---

## 🎯 The Problem

<table>
<tr>
<td width="50%">

### ❌ BEFORE (Broken)

```
┌────────────────────────────────────┐
│  🐝 Beeper Desktop                 │
│                                    │
│  ┌──────────────────────────────┐  │
│  │                              │  │
│  │    "Update Available!"       │  │
│  │                              │  │
│  │    [ Restart to Update ]     │  │
│  │                              │  │
│  └──────────────────────────────┘  │
│                                    │
│  * clicks button *                 │
│  * restarts *                      │
│  * still on old version *          │
│                                    │
│  😤 Nothing happened!              │
│                                    │
└────────────────────────────────────┘
```

</td>
<td width="50%">

### ✅ AFTER (This Script)

```
┌────────────────────────────────────┐
│  $ update-beeper                   │
│                                    │
│  🐝 Checking for updates...        │
│  ├─ Installed: 4.2.482             │
│  ├─ Latest:    4.2.495             │
│  └─ Update available!              │
│                                    │
│  📥 Downloading... done            │
│  📦 Extracting... done             │
│  🔍 Verifying... done              │
│  💾 Installing... done             │
│  ✓ Beeper updated to 4.2.495!      │
│                                    │
│  🎉 You're on the latest version!  │
│                                    │
└────────────────────────────────────┘
```

</td>
</tr>
</table>

### Why Does This Happen?

```
    ┌─────────────────────────────────────────────────────────────────────────┐
    │                                                                         │
    │   🐝 Beeper's Built-in Updater     vs     📦 AUR Package System        │
    │                                                                         │
    │   "I'll replace my own files"      vs     "Pacman owns those files"    │
    │                                                                         │
    │              │                                     │                    │
    │              ▼                                     ▼                    │
    │   ┌─────────────────────┐              ┌─────────────────────┐         │
    │   │ Downloads update    │              │ Blocks modification │         │
    │   │ Tries to write      │───CONFLICT───│ "Permission denied" │         │
    │   │ files in /opt       │              │ Files stay the same │         │
    │   └─────────────────────┘              └─────────────────────┘         │
    │                                                                         │
    │                          RESULT: Silent failure                        │
    │                          You think you updated, but you didn't         │
    │                                                                         │
    └─────────────────────────────────────────────────────────────────────────┘
```

**PLUS:** Even `yay -Syu beeper-v4-bin` is often behind—the AUR depends on a maintainer noticing the release.

---

## ✨ Features

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   FEATURE                           STATUS              PROGRESS             ║
║   ─────────────────────────────────────────────────────────────────────────  ║
║                                                                              ║
║   🚀 Direct Download from API       Complete            [##########] 100%   ║
║   🔄 Self-Healing Retry Logic       Complete            [##########] 100%   ║
║   ⏪ Automatic Rollback             Complete            [##########] 100%   ║
║   🏥 Health Monitor (blank fix)     Complete            [##########] 100%   ║
║   🗣️  Natural Language Commands      Complete            [##########] 100%   ║
║   🛫 Pre-flight Validation          Complete            [##########] 100%   ║
║   📦 AUR Version Awareness          Complete            [##########] 100%   ║
║   ⏰ Systemd Timer Automation       Complete            [##########] 100%   ║
║   🖥️  Native Wayland Support         Complete            [##########] 100%   ║
║   🔒 Concurrent Run Prevention      Complete            [##########] 100%   ║
║   🔔 Desktop Notifications          Complete            [##########] 100%   ║
║   🤫 Quiet Mode for Cron            Complete            [##########] 100%   ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

<details>
<summary><b>🆕 What's New in v1.2</b> (click to expand)</summary>

```
    ·  ·    ·                                          ·    ·  ·
         · 🐝  ·                                      ·  🐝 ·
      ·        ·   NEW FEATURES HAVE LANDED!      ·        ·
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    🗣️  NATURAL LANGUAGE     Say "Update Beeper" - it just works!
                             Shell aliases, Jarvis wrapper, Claude Code

    🏥  HEALTH MONITORING    Auto-restarts Beeper on blank screen
                             Systemd timer checks every 5 minutes

    📊  --versions FLAG      See all versions at a glance:
                             Installed • Latest • AUR

    🐛  BUG FIXES            Version detection now uses package.json
                             (source of truth) instead of pacman

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

</details>

---

## 📊 How It Works

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                           UPDATE PIPELINE FLOW                               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────┐ ║
║    │  CHECK   │───▶│ DOWNLOAD │───▶│ EXTRACT  │───▶│ INSTALL  │───▶│VERIFY│ ║
║    │ VERSION  │    │ APPIMAGE │    │  FILES   │    │ TO /opt  │    │START │ ║
║    └────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘    └──┬───┘ ║
║         │               │               │               │              │     ║
║         │ up to date    │ <150MB?       │ missing       │ perm         │fail ║
║         ▼               ▼   files?      ▼   error?      ▼              ▼     ║
║    ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐    ┌───────┐ ║
║    │ EXIT OK │     │  RETRY  │     │  RETRY  │     │  RETRY  │    │ROLLBCK│ ║
║    │  ✓ 🐝   │     │ (2x max)│     │ (2x max)│     │ (2x max)│    │RESTORE│ ║
║    └─────────┘     └─────────┘     └─────────┘     └─────────┘    └───────┘ ║
║                                                                              ║
║    ════════════════════════════════════════════════════════════════════════  ║
║                                                                              ║
║    📁 CRITICAL FILES VERIFIED:                                               ║
║    ├── beepertexts              (main binary)                                ║
║    ├── snapshot_blob.bin        (V8 JavaScript snapshot)                     ║
║    ├── v8_context_snapshot.bin  (V8 context snapshot)                        ║
║    └── resources/app/package.json (version source of truth)                  ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## 📦 Installation

### Option 1: Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/install.sh | bash
```

### Option 2: Manual Install

```bash
# Download scripts
curl -o ~/.local/bin/update-beeper \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/update-beeper
curl -o ~/.local/bin/beeper-version \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/beeper-version

# Make executable
chmod +x ~/.local/bin/update-beeper ~/.local/bin/beeper-version
```

### Option 3: Clone & Install

```bash
git clone https://github.com/beeper-community/update-beeper.git
cd update-beeper
./install.sh
```

> **Note:** Make sure `~/.local/bin` is in your PATH.

---

## 🔧 Usage

### Check Version Status

```bash
beeper-version
```

```
╭──────────────────────────────────────╮
│     🐝 Beeper Version Status         │
├──────────────────────────────────────┤
│                                      │
│   Installed:  4.2.482                │
│   Latest:     4.2.495                │
│   AUR:        4.2.455                │
│                                      │
│   ⚠ Update available!               │
│   ℹ AUR is behind by ~40 releases   │
│                                      │
╰──────────────────────────────────────╯
```

### Update Beeper

```bash
update-beeper              # Check and install updates
update-beeper --check      # Check only, don't install
update-beeper --versions   # Show all versions (installed, latest, AUR)
update-beeper --changelog  # Open changelog for installed version
update-beeper --force      # Force reinstall even if up to date
update-beeper --notify     # Send desktop notification (for automation)
update-beeper --quiet      # Silent mode (for cron/systemd)
update-beeper --rollback   # Manually rollback to previous version
```

### Command Reference

| Option | Short | Description |
|--------|-------|-------------|
| `--check` | `-c` | Check for updates without installing |
| `--changelog` | `-l` | Show changelog for installed version |
| `--notify` | `-n` | Send desktop notification (for cron/timer use) |
| `--force` | `-f` | Force update even if already on latest |
| `--quiet` | `-q` | Quiet mode - only output on errors |
| `--versions` | | Show all version info (installed, latest, AUR) |
| `--rollback` | `-r` | Rollback to previous backup version |
| `--version` | `-v` | Show script version |
| `--help` | `-h` | Show help message |

---

## ⏰ Automatic Updates

### Systemd Timer (Set & Forget)

```bash
# Copy systemd user files
mkdir -p ~/.config/systemd/user
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/systemd/update-beeper-user.service \
  -o ~/.config/systemd/user/update-beeper.service
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/systemd/update-beeper-user.timer \
  -o ~/.config/systemd/user/update-beeper.timer

# Enable the timer
systemctl --user daemon-reload
systemctl --user enable --now update-beeper.timer

# Check timer status
systemctl --user list-timers update-beeper.timer
```

> Runs daily between 10:00-14:00 (randomized to avoid hammering Beeper's servers).

---

## 🗣️ Natural Language Commands

```
╭─────────────────────────────────────────────────────────────────────────────╮
│                                                                             │
│       "Update Beeper"              ───▶      🐝 Updating...                │
│       "Is Beeper up to date?"      ───▶      🐝 Checking...                │
│       "Beeper version"             ───▶      🐝 v4.2.495                   │
│       "Rollback Beeper"            ───▶      🐝 Restoring...               │
│                                                                             │
│                    Talk to your updater like a human!                       │
│               Works with Claude Code, Bash aliases, or Jarvis               │
│                                                                             │
╰─────────────────────────────────────────────────────────────────────────────╯
```

<details>
<summary><b>Shell Aliases (Bash/Zsh)</b></summary>

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Quick shortcuts
alias bu='update-beeper'
alias bv='beeper-version'

# Natural language wrapper
beeper() {
    case "$1" in
        update|upgrade) shift; update-beeper "$@" ;;
        version|--version|-v) beeper-version ;;
        *) echo "Usage: beeper {update|version}" ;;
    esac
}
```

Then use: `bu`, `bv`, `beeper update`, `beeper version`

</details>

<details>
<summary><b>Jarvis Wrapper (Natural Language CLI)</b></summary>

```bash
# Install the NL wrapper
curl -o ~/bin/jarvis-beeper \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/jarvis-beeper
chmod +x ~/bin/jarvis-beeper

# Use natural language!
jarvis-beeper "update beeper"
jarvis-beeper "is beeper up to date"
jarvis-beeper "what version of beeper do I have"
jarvis-beeper "rollback beeper"
```

</details>

<details>
<summary><b>Claude Code Integration</b></summary>

The update-beeper skill auto-activates when you say things like:
- "I need to update Beeper"
- "Update Beeper to latest"
- "Is Beeper up to date?"
- "Check Beeper version"

</details>

---

## 🏥 Health Monitoring

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                          BEEPER HEALTH MONITOR                               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║   Fixes the dreaded "blank screen after sleep" bug automatically!            ║
║                                                                              ║
║   Every 5 minutes:                                                           ║
║                                                                              ║
║   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐           ║
║   │   Process   │  ──▶    │   Window    │  ──▶    │   Status    │           ║
║   │   Running?  │         │   Visible?  │         │             │           ║
║   └──────┬──────┘         └──────┬──────┘         └─────────────┘           ║
║          │                       │                                           ║
║          │ NO                    │ NO (blank!)                               ║
║          ▼                       ▼                                           ║
║   ┌─────────────┐         ┌─────────────────────────┐                       ║
║   │   Log: not  │         │   Auto-restart with     │                       ║
║   │   running   │         │   XWayland fallback     │                       ║
║   └─────────────┘         └─────────────────────────┘                       ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

<details>
<summary><b>Install Health Monitor</b></summary>

```bash
# Download the health check script
curl -o ~/bin/beeper-health \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/beeper-health
chmod +x ~/bin/beeper-health

# Install systemd timer (runs every 5 minutes)
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/beeper-health.service << 'EOF'
[Unit]
Description=Check Beeper health and restart if unresponsive

[Service]
Type=oneshot
ExecStart=%h/bin/beeper-health
EOF

cat > ~/.config/systemd/user/beeper-health.timer << 'EOF'
[Unit]
Description=Run Beeper health check every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now beeper-health.timer
```

Logs are written to `/tmp/beeper-health.log` when issues are detected.

</details>

---

## 🖥️ Wayland Support

Beeper uses Electron, which can have rendering issues on Wayland. **Blank/white windows** are common when Electron tries to use XWayland.

<details>
<summary><b>Automatic Configuration</b></summary>

When running on Wayland (detected via `$WAYLAND_DISPLAY`), this script automatically:

1. **Tests startup with Wayland flags** - Uses `--enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu-compositing`
2. **Creates desktop file override** - Installs to `~/.local/share/applications/beeper.desktop`

This fixes:
- Blank/white windows on startup
- Blank screen after sleep/wake/screensaver cycles

</details>

<details>
<summary><b>Manual Fix</b></summary>

If you installed Beeper before this feature was added:

```bash
update-beeper --force
```

This reinstalls and configures Wayland support.

</details>

---

## 🔧 Self-Healing Pipeline

<details>
<summary><b>What Gets Verified</b></summary>

| File | Purpose |
|------|---------|
| `beepertexts` | Main Electron binary |
| `snapshot_blob.bin` | V8 JavaScript snapshot |
| `v8_context_snapshot.bin` | V8 context snapshot |
| `resources/app/package.json` | Version source of truth |

</details>

<details>
<summary><b>Self-Healing Actions</b></summary>

| Failure | Diagnosis | Fix Applied |
|---------|-----------|-------------|
| Download too small | Incomplete transfer | Clear temp, wait 2s, retry |
| Missing critical files | Extraction failed | Clear squashfs-root, re-extract |
| Wrong version | Stale download | Clear temp, fresh download |
| Startup crash | Corrupted cache | Clear Electron cache dirs |
| All retries exhausted | Unrecoverable | **Automatic rollback** |

</details>

<details>
<summary><b>Code Safety Practices</b></summary>

| Practice | Implementation |
|----------|----------------|
| **No directory leaks** | All `cd` commands run in subshells |
| **Safe file operations** | All paths quoted, absolute references |
| **Proper error handling** | 46+ commands protected |
| **Clean exit** | Trap ensures temp cleanup |
| **Idempotent operations** | Safe to run multiple times |

</details>

---

## 📋 Requirements

| Requirement | Notes |
|-------------|-------|
| **Architecture** | x86_64 only (Beeper doesn't provide ARM builds) |
| **Distro** | Arch Linux or Arch-based (Manjaro, EndeavourOS, etc.) |
| **curl** | Required - for downloading |
| **sudo** | Required - for installing to /opt |
| **notify-send** | Optional - for desktop notifications |

---

## 📁 File Locations

```
/opt/beeper/              ← Installation directory
/opt/beeper-backups/      ← Rolling backups (last 3 versions)
~/.config/BeeperTexts/    ← User config + Electron caches
/tmp/beeper-update/       ← Temporary download/extract dir
```

---

## ❓ FAQ

<details>
<summary><b>Should I still use the AUR package?</b></summary>

Yes! This script works alongside the AUR package. When AUR catches up, you can run `yay -Syu beeper-v4-bin` to resync. The script tells you when this happens.

</details>

<details>
<summary><b>What if an update breaks something?</b></summary>

The script automatically rolls back to your previous working version. You'll get a notification and can try again later.

</details>

<details>
<summary><b>Does this work on other distros?</b></summary>

Partially. The core update functionality works on any Linux distro with x86_64 architecture. However:
- AUR version checking won't work (requires pacman)
- You'll see a warning about non-Arch distro
- The script still installs to `/opt/beeper`

</details>

<details>
<summary><b>Why x86_64 only?</b></summary>

Beeper Desktop only provides x86_64 (64-bit Intel/AMD) builds. There are no ARM or 32-bit versions available.

</details>

<details>
<summary><b>Beeper shows blank window on Hyprland/Sway?</b></summary>

Run `update-beeper --force` to reinstall with native Wayland support. The script automatically creates a desktop file override with correct Ozone platform flags.

</details>

<details>
<summary><b>Beeper goes blank after sleep/wake?</b></summary>

Fixed by the `--disable-gpu-compositing` flag, included automatically. Run `update-beeper --force` to update your desktop file.

</details>

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📜 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## 📄 License

MIT

---

<p align="center">
  <img src="https://raw.githubusercontent.com/beeper-community/update-beeper/master/.github/assets/bee-divider.png" alt="divider" width="400">
</p>

<p align="center">
  <sub>Made with 🐝 for the Beeper community</sub><br>
  <sub><i>Because "Update Available" should mean something</i></sub>
</p>
