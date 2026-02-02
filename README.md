# update-beeper

```
    ╔══════════════════════════════════════════════════════════════════════════╗
    ║                                                                          ║
    ║   ██████╗ ███████╗███████╗██████╗ ███████╗██████╗                        ║
    ║   ██╔══██╗██╔════╝██╔════╝██╔══██╗██╔════╝██╔══██╗                       ║
    ║   ██████╔╝█████╗  █████╗  ██████╔╝█████╗  ██████╔╝                       ║
    ║   ██╔══██╗██╔══╝  ██╔══╝  ██╔═══╝ ██╔══╝  ██╔══██╗                       ║
    ║   ██████╔╝███████╗███████╗██║     ███████╗██║  ██║                       ║
    ║   ╚═════╝ ╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝                       ║
    ║                                                                          ║
    ║   ██╗   ██╗██████╗ ██████╗  █████╗ ████████╗███████╗██████╗              ║
    ║   ██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝██╔══██╗             ║
    ║   ██║   ██║██████╔╝██║  ██║███████║   ██║   █████╗  ██████╔╝             ║
    ║   ██║   ██║██╔═══╝ ██║  ██║██╔══██║   ██║   ██╔══╝  ██╔══██╗             ║
    ║   ╚██████╔╝██║     ██████╔╝██║  ██║   ██║   ███████╗██║  ██║             ║
    ║    ╚═════╝ ╚═╝     ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝             ║
    ║                                                                          ║
    ║                🐝  Self-healing • Auto-rollback • Arch Linux  🐝         ║
    ║                                                                          ║
    ╚══════════════════════════════════════════════════════════════════════════╝
```

<p align="center">
  <a href="https://www.beeper.com/changelog/desktop">
    <img src="https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/beeper-community/update-beeper/master/.github/badges/beeper-version.json&style=for-the-badge" alt="Beeper Latest">
  </a>
  &nbsp;&nbsp;
  <a href="https://aur.archlinux.org/packages/beeper-v4-bin">
    <img src="https://img.shields.io/aur/version/beeper-v4-bin?label=AUR&style=for-the-badge&color=1793d1" alt="AUR Version">
  </a>
</p>

<p align="center">
  <i>Is AUR behind? This script gets you the latest directly from Beeper!</i>
</p>

<p align="center">
  <a href="https://github.com/beeper-community/update-beeper/actions/workflows/lint.yml">
    <img src="https://github.com/beeper-community/update-beeper/actions/workflows/lint.yml/badge.svg" alt="Lint">
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT">
  </a>
</p>

A self-healing Beeper Desktop updater for Linux, built specifically for Arch Linux users.

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

## Why This Exists

### The Problem: Beeper's Built-in Updater Doesn't Work on Arch

If you've installed Beeper from the AUR (`beeper-v4-bin`), you've probably noticed that clicking **"Update Available"** inside Beeper does... nothing. The app downloads the update, prompts you to restart, and then you're still on the old version.

**Why?** Beeper's built-in updater is designed for standalone AppImage installations where it can replace itself. But on Arch Linux, Beeper is managed by pacman/yay through the AUR package. The app can't overwrite files that pacman owns—so the update silently fails, leaving you stuck on the old version with no error message.

### The Problem: AUR Is Always Behind

Even if you run `yay -Syu beeper-v4-bin`, you're often still behind. The AUR package depends on a maintainer to notice a new release, update the `PKGBUILD`, and push it. This can take hours or even days. Meanwhile, Beeper has already released a newer version that you can't get.

**This script solves both problems:**
- ✅ Downloads directly from Beeper's API (always the latest)
- ✅ Installs immediately without waiting for AUR
- ✅ Tells you when AUR catches up so you can resync

### Bonus: Self-Healing After a Real Failure

During development, a routine update broke everything—the AppImage extraction silently failed, leaving critical V8 snapshot files missing:

```
FATAL:gin/v8_initializer.cc:705] Error loading V8 startup snapshot file
```

Beeper crashed on startup. No warning during install. No automatic recovery. This script now verifies every critical file and automatically rolls back if anything goes wrong.

## How Beeper Updates Work (And Why They Break)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BEEPER'S BUILT-IN UPDATE (Broken on Arch)                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   1. Beeper detects new version via API                                     │
│   2. Downloads update in background                                         │
│   3. Prompts: "Restart to update"                                           │
│   4. User restarts...                                                       │
│   5. ❌ Update fails silently (pacman owns the files)                       │
│   6. User is still on old version, confused                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    THIS SCRIPT (Works on Arch)                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   1. Queries Beeper API for latest version                                  │
│   2. Compares against installed version                                     │
│   3. Downloads AppImage directly from Beeper                                │
│   4. Extracts and verifies all critical files                               │
│   5. Backs up current installation                                          │
│   6. Installs with proper permissions (sudo)                                │
│   7. Verifies Beeper starts and runs stable                                 │
│   8. ✅ You're on the latest version!                                       │
│                                                                             │
│   If anything fails → automatic rollback to backup                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Features

```
  ┌─────────────────────────────────────────────────────────────────┐
  │  🚀 DIRECT DOWNLOAD   Gets latest from Beeper API, skip AUR    │
  │  🔄 SELF-HEALING      Retries with targeted fixes              │
  │  ⏪ AUTO-ROLLBACK     Restores previous version on failure     │
  │  🏥 HEALTH MONITOR    Auto-restarts on blank screen (NEW!)     │
  │  🗣️  NATURAL LANGUAGE  "Update Beeper" just works (NEW!)       │
  │  🛫 PRE-FLIGHT        Validates permissions, space, network    │
  │  📦 AUR AWARE         Tells you when AUR catches up            │
  │  📊 VERSION STATUS    --versions shows all version info        │
  │  ⏰ AUTO UPDATES      Systemd timer for set-and-forget         │
  │  🖥️  WAYLAND NATIVE   Auto-configures for Hyprland/Sway/etc    │
  │  🔒 LOCKFILE          Prevents concurrent update runs          │
  │  🤫 QUIET MODE        Silent operation for cron/systemd        │
  └─────────────────────────────────────────────────────────────────┘
```

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/beeper-community/update-beeper/master/install.sh | bash
```

### Manual Install

```bash
# Download scripts
curl -o ~/.local/bin/update-beeper \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/update-beeper
curl -o ~/.local/bin/beeper-version \
  https://raw.githubusercontent.com/beeper-community/update-beeper/master/beeper-version

# Make executable
chmod +x ~/.local/bin/update-beeper ~/.local/bin/beeper-version
```

### Clone & Install

```bash
git clone https://github.com/beeper-community/update-beeper.git
cd update-beeper
./install.sh
```

Make sure `~/.local/bin` is in your PATH.

## Usage

### Check Version Status

```bash
beeper-version
```

```
🐝 Beeper Version Status
─────────────────────────────────────

  Installed:  4.2.482
  Latest:     4.2.482
  AUR:        4.2.455

  ✓ You're on the latest version!
  ℹ AUR is behind by ~27 releases
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
update-beeper --version    # Show script version
```

### Options

| Option | Short | Description |
|--------|-------|-------------|
| `--check` | `-c` | Check for updates without installing |
| `--changelog` | `-l` | Show changelog for installed version |
| `--notify` | `-n` | Send desktop notification (for cron/timer use) |
| `--force` | `-f` | Force update even if already on latest |
| `--quiet` | `-q` | Quiet mode - only output on errors (for cron/systemd) |
| `--versions` | | Show all version info (installed, latest, AUR) |
| `--rollback` | `-r` | Rollback to previous backup version |
| `--version` | `-v` | Show script version |
| `--help` | `-h` | Show help message |

## Automatic Updates (Systemd)

Set up automatic daily update checks with desktop notifications:

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

The timer runs daily between 10:00-14:00 (randomized to avoid hammering Beeper's servers).

## Natural Language Commands

```
    ╭───────────────────────────────────────────────────────────────╮
    │                                                               │
    │      "Update Beeper"         ───▶   🐝 Updating...           │
    │      "Is Beeper up to date?" ───▶   🐝 Checking...           │
    │      "Beeper version"        ───▶   🐝 v4.2.495              │
    │      "Rollback Beeper"       ───▶   🐝 Restoring...          │
    │                                                               │
    │            ╱╲                                                  │
    │           ╱  ╲     Talk to your updater like a human!        │
    │          ╱ 🐝 ╲    Works with Claude Code, Bash, or Jarvis   │
    │         ╱______╲                                              │
    │                                                               │
    ╰───────────────────────────────────────────────────────────────╯
```

### Shell Aliases (Bash/Zsh)

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Quick shortcuts
alias bu='~/bin/update-beeper'
alias bv='~/bin/beeper-version'

# Natural language wrapper
beeper() {
    case "$1" in
        update|upgrade) shift; ~/bin/update-beeper "$@" ;;
        version|--version|-v) ~/bin/beeper-version ;;
        *) echo "Usage: beeper {update|version}" ;;
    esac
}
```

Then use: `bu`, `bv`, `beeper update`, `beeper version`

### Jarvis Wrapper (Natural Language CLI)

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

### Claude Code Integration

The update-beeper skill auto-activates when you say things like:
- "I need to update Beeper"
- "Update Beeper to latest"
- "Is Beeper up to date?"
- "Check Beeper version"

## Health Monitoring (Auto-Recovery)

```
    ┌─────────────────────────────────────────────────────────────┐
    │                 🏥 BEEPER HEALTH MONITOR                    │
    ├─────────────────────────────────────────────────────────────┤
    │                                                             │
    │   Every 5 minutes:                                          │
    │                                                             │
    │   ┌─────────┐     ┌──────────┐     ┌────────────┐          │
    │   │ Process │────▶│  Window  │────▶│   Status   │          │
    │   │ Running?│     │ Visible? │     │            │          │
    │   └────┬────┘     └────┬─────┘     └────────────┘          │
    │        │               │                                    │
    │        │ NO            │ NO (blank screen!)                 │
    │        ▼               ▼                                    │
    │   [Log: not      [Auto-restart with                        │
    │    running]       XWayland mode]                           │
    │                                                             │
    │   🔧 Fixes the dreaded "blank screen after sleep" bug      │
    │                                                             │
    └─────────────────────────────────────────────────────────────┘
```

### Install Health Monitor

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

## Wayland Support (Hyprland, Sway, etc.)

Beeper uses Electron, which can have rendering issues on Wayland compositors. **Blank/white windows** are a common symptom when Electron tries to use XWayland instead of native Wayland rendering.

### Automatic Configuration

When running on Wayland (detected via `$WAYLAND_DISPLAY`), this script automatically:

1. **Tests startup with Wayland flags** - Uses `--enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu-compositing`
2. **Creates desktop file override** - Installs to `~/.local/share/applications/beeper.desktop`

This ensures Beeper always launches with native Wayland rendering, fixing:
- Blank/white windows on startup
- Blank screen after sleep/wake/screensaver cycles

### Manual Fix (if needed)

If you installed Beeper before this feature was added, run:

```bash
update-beeper --force
```

This will reinstall and configure Wayland support.

### What Doesn't Work

Beeper bundles its own Electron runtime, so these common approaches **don't work**:

- `~/.config/electron-flags.conf` - Not read by bundled Electron
- `~/.config/beepertexts-flags.conf` - Same reason
- `ELECTRON_OZONE_PLATFORM_HINT` env var - Not respected

The desktop file override is the reliable solution.

## Self-Healing Pipeline

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            UPDATE PIPELINE                               │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   📥 Download ──► 📦 Extract ──► 📁 Install ──► 🔍 Verify ──► 🚀 Start  │
│       │              │              │              │              │      │
│       ▼              ▼              ▼              ▼              ▼      │
│   [>150MB?]    [V8 files?]    [Perms OK?]   [Version?]    [Stable?]     │
│       │              │              │              │              │      │
│       │ FAIL         │ FAIL         │ FAIL         │ FAIL         │ FAIL │
│       ▼              ▼              ▼              ▼              ▼      │
│   ┌──────────────────────────────────────────────────────────────┐      │
│   │              🔧 RETRY WITH TARGETED FIX (2x)                 │      │
│   │  • Clear temp dir, re-download                               │      │
│   │  • Clear extraction, retry                                   │      │
│   │  • Fix permissions recursively                               │      │
│   │  • Clear Electron cache                                      │      │
│   └──────────────────────────────────────────────────────────────┘      │
│                                      │                                   │
│                                      │ ALL RETRIES EXHAUSTED             │
│                                      ▼                                   │
│   ┌──────────────────────────────────────────────────────────────┐      │
│   │              ⏪ AUTOMATIC ROLLBACK                            │      │
│   │  • Restore from pre-update backup                            │      │
│   │  • Verify rollback works                                     │      │
│   │  • Notify user of failure                                    │      │
│   └──────────────────────────────────────────────────────────────┘      │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### Critical Files Verified

These files are checked after every extraction—if any are missing, the update retries:

| File | Purpose |
|------|---------|
| `beepertexts` | Main Electron binary |
| `snapshot_blob.bin` | V8 JavaScript snapshot |
| `v8_context_snapshot.bin` | V8 context snapshot |
| `resources/app/package.json` | Version source of truth |

### Self-Healing Actions

| Failure | Diagnosis | Fix Applied |
|---------|-----------|-------------|
| Download too small | Incomplete transfer | Clear temp, wait 2s, retry |
| Missing critical files | Extraction failed | Clear squashfs-root, re-extract |
| Wrong version | Stale download | Clear temp, fresh download |
| Startup crash | Corrupted cache | Clear Electron cache dirs |
| All retries exhausted | Unrecoverable | **Automatic rollback** |

### Code Safety

The script follows bash best practices to prevent common issues:

| Practice | Implementation |
|----------|----------------|
| **No directory leaks** | All `cd` commands run in subshells `(cd dir && ...)` |
| **Safe file operations** | All paths are quoted and use absolute references |
| **Proper error handling** | 46+ commands protected with `|| true` or `2>/dev/null` |
| **Clean exit** | Trap ensures `/tmp/beeper-update` is cleaned on exit |
| **Idempotent operations** | Safe to run multiple times without side effects |

## Requirements

| Requirement | Notes |
|-------------|-------|
| **Architecture** | x86_64 only (Beeper doesn't provide ARM builds) |
| **Distro** | Arch Linux or Arch-based (Manjaro, EndeavourOS, etc.) |
| **curl** | Required - for downloading |
| **sudo** | Required - for installing to /opt |
| **notify-send** | Optional - for desktop notifications |

### Compatibility Checks

The script automatically verifies your system before running:

```
✓ Architecture check (x86_64 required)
✓ Distro detection (warns if not Arch-based)
✓ Dependency check (curl, sudo)
✓ Optional: notify-send for notifications
```

If any required check fails, you'll get a clear error message with instructions.

## File Locations

```
/opt/beeper/              ← Installation directory
/opt/beeper-backups/      ← Rolling backups (last 3 versions)
~/.config/BeeperTexts/    ← User config + Electron caches
/tmp/beeper-update/       ← Temporary download/extract dir
```

## FAQ

**Q: Should I still use the AUR package?**

Yes! This script works alongside the AUR package. When AUR catches up, you can run `yay -Syu beeper-v4-bin` to resync. The script will tell you when this happens.

**Q: What if an update breaks something?**

The script automatically rolls back to your previous working version. You'll get a notification and can try again later or report the issue.

**Q: Can I automate this?**

Yes! See the [Automatic Updates](#automatic-updates-systemd) section for systemd timer setup.

**Q: How do I check my current version status?**

Run `beeper-version` for a quick overview of installed, latest, and AUR versions.

**Q: Does this work on other distros (Ubuntu, Fedora, etc.)?**

Partially. The core update functionality (download, extract, install) works on any Linux distro with x86_64 architecture. However:
- AUR version checking won't work (requires pacman)
- You'll see a warning about non-Arch distro
- The script still installs to `/opt/beeper`

**Q: Why x86_64 only?**

Beeper Desktop only provides x86_64 (64-bit Intel/AMD) builds. There are no ARM or 32-bit versions available from Beeper.

**Q: Beeper shows a blank/white window on Hyprland/Sway?**

This is an Electron + Wayland issue. Run `update-beeper --force` to reinstall with native Wayland support. The script automatically creates a desktop file override with the correct Ozone platform flags.

**Q: Beeper goes blank after sleep/wake or screensaver?**

This is fixed by the `--disable-gpu-compositing` flag, which the script now includes automatically. Run `update-beeper --force` to update your desktop file with this fix.

**Q: I'm on X11, will Wayland flags break anything?**

No. The script only applies Wayland configuration when `$WAYLAND_DISPLAY` is set. On X11, Beeper launches normally without any Wayland-specific flags.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

MIT

---

<p align="center">
  <i>Because Beeper's "Update Available" button should actually work</i> 🐝
</p>
