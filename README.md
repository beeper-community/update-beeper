<p align="center">

```
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

## Quick Start

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/install.sh | bash

# Check your version status
update-beeper --versions

# Update to latest
update-beeper
```

---

## The Problem

<table>
<tr>
<td width="50%">

### Before (Broken)

```
  Beeper Desktop

    "Update Available!"

    [ Restart to Update ]

  * clicks button *
  * restarts *
  * still on old version *

  Nothing happened!
```

</td>
<td width="50%">

### After (This Script)

```
  🐝 Beeper Updater v1.5.0

  [1/8] Checking versions
    Installed: 4.2.482
    Latest:    4.2.547

  [4/8] Downloading Beeper 4.2.547
    ✓ Download complete — 213MB

  [5/8] Extracting & verifying
    ✓ All 3 checks passed

  ╭──────────────────────────────────╮
  │  ✓ Update complete               │
  │  Version   4.2.482 → 4.2.547    │
  │  Duration  52s                   │
  ╰──────────────────────────────────╯
```

</td>
</tr>
</table>

<details>
<summary><b>Why does Beeper's built-in update fail?</b></summary>

Beeper's built-in updater tries to replace its own files in `/opt`, but the AUR package manager (`pacman`) owns those files and blocks modifications. The result is a **silent failure** — you think you updated, but nothing changed.

This script bypasses the conflict by downloading directly from Beeper's API and installing with proper permissions.

</details>

---

## Features

| Feature                                | Since |
|----------------------------------------|-------|
| Direct download from Beeper API        | v1.0  |
| Self-healing retry logic (2x per stage)| v1.0  |
| Automatic rollback on failure          | v1.0  |
| Native Wayland support                 | v1.0  |
| AUR version awareness                  | v1.0  |
| Concurrent run prevention (flock)      | v1.1  |
| Quiet mode for cron/systemd            | v1.1  |
| Desktop notifications                  | v1.1  |
| Manual rollback (`--rollback`)         | v1.1  |
| Natural language commands              | v1.2  |
| Health monitor (blank screen fix)      | v1.2  |
| `--versions` flag                      | v1.2  |
| SHA256 checksum verification           | v1.3  |
| Domain validation (MITM protection)    | v1.3  |
| AUR JSON RPC API (replaces scraping)   | v1.4  |
| Structured logging & `--history`       | v1.4  |
| `--dry-run` preview mode               | v1.4  |
| ELF binary verification                | v1.4  |
| Download resume (`curl -C -`)          | v1.4  |
| Beeper-branded true color UI           | v1.5  |
| Collapsible check groups               | v1.5  |
| Summary box with unicode borders       | v1.5  |

<details>
<summary><b>What's New in v1.5</b></summary>

Full visual overhaul using Beeper's brand identity (`#6953f2` purple + `#0c52f9` blue).

**Before** (v1.3):
```
📥 Downloading Beeper 4.2.547...
   ✓ Download complete (213MB)
📦 Extracting AppImage...
   ✓ Extraction complete
🔍 Verifying extraction...
✅ Successfully updated to 4.2.547!
```

**After** (v1.5):
```
  [4/8] Downloading Beeper 4.2.547
    ✓ Download complete — 213MB

  [5/8] Extracting & verifying
    ✓ All 3 checks passed (extraction, files, ELF)

  ╭──────────────────────────────────────╮
  │  ✓ Update complete                   │
  │  Version   4.2.482 → 4.2.547        │
  │  Method    Direct install            │
  │  Duration  52s                       │
  ╰──────────────────────────────────────╯
```

- True color palette with 256-color fallback
- 8 numbered phases replacing 17 emoji headers
- Collapsible checks (one line when all pass)
- Output reduced from ~60 to ~25 lines

</details>

---

## How It Works

<details>
<summary><b>Update pipeline flow</b></summary>

```
  [1/8] Check versions    → Already up to date? Exit.
           │
  [2/8] Validate source   → Untrusted domain? Abort.
           │
  [3/8] Prerequisites     → sudo, disk, network, permissions
           │
  [4/8] Download           → With resume, retries, size check
           │
  [5/8] Extract & verify   → Checksum, ELF, critical files
           │
  [6/8] Install            → Backup → Patches → Copy → Permissions
           │
  [7/8] Configure          → Version verify, Wayland override
           │
  [8/8] Verify startup     → Launch test, retry with cache clear
           │
       ╭─────────╮
       │ Summary │ → Success box or rollback
       ╰─────────╯
```

**Critical files verified after extraction:**

| File                          | Purpose                    |
|-------------------------------|----------------------------|
| `beepertexts`                 | Main Electron binary       |
| `chrome-sandbox`              | Chromium sandbox (setuid)  |
| `snapshot_blob.bin`           | V8 JavaScript snapshot     |
| `v8_context_snapshot.bin`     | V8 context snapshot        |
| `resources/app/package.json`  | Version source of truth    |

</details>

---

## Installation

### Option 1: Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/install.sh | bash
```

### Option 2: Manual Install

```bash
curl -o ~/.local/bin/update-beeper \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/update-beeper
curl -o ~/.local/bin/beeper-version \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/beeper-version

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

## Usage

```bash
update-beeper              # Check and install updates
update-beeper --versions   # Show all versions (installed, latest, AUR)
update-beeper --dry-run    # Preview what would happen
update-beeper --force      # Force reinstall even if up to date
update-beeper --rollback   # Rollback to previous version
update-beeper --history    # Show past update attempts
```

### Command Reference

| Option            | Short | Description                                      |
|-------------------|-------|--------------------------------------------------|
| `--check`         | `-c`  | Check for updates without installing              |
| `--changelog`     | `-l`  | Show changelog for installed version              |
| `--notify`        | `-n`  | Send desktop notification (for cron/timer use)    |
| `--force`         | `-f`  | Force update even if already on latest            |
| `--quiet`         | `-q`  | Quiet mode — only output on errors                |
| `--versions`      |       | Show all version info (installed, latest, AUR)    |
| `--skip-checksum` |       | Skip SHA256 checksum verification                 |
| `--dry-run`       |       | Show what would happen without making changes     |
| `--history`       |       | Show update history with timestamps               |
| `--rollback`      | `-r`  | Rollback to previous backup version               |
| `--version`       | `-v`  | Show script version                               |
| `--help`          | `-h`  | Show help message                                 |

---

## Automatic Updates

### Systemd Timer (Set & Forget)

```bash
mkdir -p ~/.config/systemd/user
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/systemd/update-beeper-user.service \
  -o ~/.config/systemd/user/update-beeper.service
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/systemd/update-beeper-user.timer \
  -o ~/.config/systemd/user/update-beeper.timer

systemctl --user daemon-reload
systemctl --user enable --now update-beeper.timer
systemctl --user list-timers update-beeper.timer
```

> Runs daily between 10:00-14:00 (randomized to avoid hammering Beeper's servers).

---

## Natural Language Commands

<details>
<summary><b>Shell Aliases (Bash/Zsh)</b></summary>

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
alias bu='update-beeper'
alias bv='beeper-version'

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
curl -o ~/bin/jarvis-beeper \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/jarvis-beeper
chmod +x ~/bin/jarvis-beeper

jarvis-beeper "update beeper"
jarvis-beeper "is beeper up to date"
jarvis-beeper "what version of beeper do I have"
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

## Health Monitoring

<details>
<summary><b>Auto-restart on blank screen</b></summary>

Fixes the dreaded "blank screen after sleep" bug automatically. A systemd timer checks every 5 minutes whether Beeper's window is visible and restarts it with XWayland fallback if needed.

```bash
curl -o ~/bin/beeper-health \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/beeper-health
chmod +x ~/bin/beeper-health

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

## Wayland Support

Beeper uses Electron, which can have rendering issues on Wayland. **Blank/white windows** are common when Electron tries to use XWayland.

<details>
<summary><b>Automatic Configuration</b></summary>

When running on Wayland (detected via `$WAYLAND_DISPLAY`), this script automatically:

1. **Tests startup with Wayland flags** — `--enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu-compositing`
2. **Creates desktop file override** — Installs to `~/.local/share/applications/beeper.desktop`

This fixes blank/white windows on startup and after sleep/wake cycles.

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

## Self-Healing Pipeline

<details>
<summary><b>What Gets Verified</b></summary>

| Check                | Purpose                              |
|----------------------|--------------------------------------|
| Critical files       | beepertexts, snapshots, package.json |
| ELF binary type      | Validates real Linux executable      |
| SHA256 checksum      | Detects corrupted/tampered downloads |
| File permissions     | Correct ownership and setuid bits    |
| Disk space           | 1200MB available before install      |
| Domain validation    | Downloads only from trusted domains  |
| Installed version    | Confirms version matches expected    |
| Startup test         | Beeper actually launches             |

</details>

<details>
<summary><b>Self-Healing Actions</b></summary>

| Failure              | Diagnosis               | Fix Applied                       |
|----------------------|-------------------------|-----------------------------------|
| Download too small   | Incomplete transfer     | Clear temp, wait 2s, retry        |
| Missing critical files | Extraction failed     | Clear squashfs-root, re-extract   |
| Non-ELF binary       | Corrupted extraction    | Clear temp, re-download           |
| Wrong version        | Stale download          | Clear temp, fresh download        |
| Permission errors    | Wrong ownership         | Recursive chown/chmod fix         |
| Low disk space       | < 1200MB available      | Clear caches, warn user           |
| Startup crash        | Corrupted cache         | Clear Electron cache dirs         |
| All retries exhausted| Unrecoverable           | **Automatic rollback**            |

</details>

<details>
<summary><b>Code Safety Practices</b></summary>

| Practice                 | Implementation                              |
|--------------------------|---------------------------------------------|
| No directory leaks       | All `cd` commands run in subshells          |
| Safe file operations     | All paths quoted, absolute references        |
| Proper error handling    | 46+ commands protected with failure guards   |
| Clean exit               | Trap ensures temp cleanup                    |
| Idempotent operations    | Safe to run multiple times                   |
| Structured logging       | Events logged to persistent file             |
| Domain validation        | Downloads only from trusted Beeper domains   |
| ELF verification         | Binary type checked after extraction         |

</details>

---

## Requirements

| Requirement      | Notes                                                  |
|------------------|--------------------------------------------------------|
| **Architecture** | x86_64 only (Beeper doesn't provide ARM builds)       |
| **Distro**       | Arch Linux or Arch-based (Manjaro, EndeavourOS, etc.)  |
| **curl**         | Required — for downloading                             |
| **sudo**         | Required — for installing to /opt                      |
| **notify-send**  | Optional — for desktop notifications                   |

---

## File Locations

```
/opt/beeper/                                         ← Installation directory
/opt/beeper-backups/                                 ← Rolling backups (last 3 versions)
~/.config/BeeperTexts/                               ← User config + Electron caches
~/.local/share/update-beeper/update-beeper.log       ← Structured event log
~/.local/share/update-beeper/history.txt             ← Update history
~/.cache/update-beeper/checksums.txt                 ← SHA256 checksum cache
/tmp/beeper-update/                                  ← Temporary download/extract dir
```

---

## FAQ

<details>
<summary><b>Should I still use the AUR package?</b></summary>

Yes! This script works alongside the AUR package. When AUR catches up, you can run `yay -Syu beeper-v4-bin` to resync. The script tells you when this happens.

</details>

<details>
<summary><b>What if an update breaks something?</b></summary>

The script automatically rolls back to your previous working version. You can also manually rollback with `update-beeper --rollback`.

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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

MIT

---

<p align="center">
  <sub>Made with 🐝 for the Beeper community</sub><br>
  <sub><i>Because "Update Available" should mean something</i></sub>
</p>
