# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-02-02

### Added

- **Domain Validation** - Protects against MITM attacks
  - Verifies download URLs come from trusted Beeper domains only
  - Trusted domains: `beeper.com`, `todesktop.com`, `github.com`
  - Exits with clear security warning if untrusted domain detected

- **HTTP Status Validation** - Properly handles API errors
  - Validates HTTP response codes from Beeper API, AUR, and downloads
  - Fails on 4xx/5xx errors instead of silently continuing
  - Reports specific HTTP status code in error messages

- **SHA256 Checksum Verification** - Ensures download integrity
  - Trust-on-first-run model: Records checksum on first download of each version
  - Subsequent downloads are verified against stored checksum
  - Detects corrupted or tampered downloads
  - Checksum cache: `~/.cache/update-beeper/checksums.txt`
  - New `--skip-checksum` flag to bypass verification for forced re-downloads

### Fixed

- **Race condition in backup cleanup** - Fixed TOCTOU vulnerability
  - Previous: `ls -t | tail -n +4 | xargs rm` (vulnerable to race conditions)
  - Now: Uses atomic `find` operations with pattern matching
  - Only affects `beeper-backup-*` directories, prevents accidental deletion

### Security

| Protection | Attack Vector | Mitigation |
|------------|---------------|------------|
| Domain validation | MITM redirect to malicious site | Whitelist trusted domains |
| HTTP status check | API failures treated as success | Validate 200/302 responses |
| SHA256 checksum | Corrupted/tampered downloads | Trust-on-first-run verification |
| Atomic cleanup | TOCTOU race in backup deletion | Use find with pattern matching |

## [1.2.0] - 2026-01-27

### Added

- **Natural Language Commands** - Multiple ways to trigger updates conversationally
  - Shell aliases: `bu`, `bv`, `beeper update`, `beeper version`
  - Jarvis wrapper: `jarvis-beeper "update beeper"`, `jarvis-beeper "is beeper up to date"`
  - Claude Code skill integration: Say "Update Beeper" or "I need to update Beeper"

- **`--versions` flag** - Show all version info at a glance
  - Displays installed, latest, and AUR versions in a clean table
  - Shows update status and AUR lag indicator

- **Health Monitoring** - Auto-recovery for the dreaded "blank screen" bug
  - New `beeper-health` script detects unresponsive Beeper
  - Checks if process is running but window is missing (blank screen symptom)
  - Auto-restarts with XWayland mode if blank screen detected
  - Systemd timer for 5-minute monitoring interval

### Fixed

- **Critical: Version detection bug** - Now uses `package.json` as source of truth
  - Previously used `pacman -Q` which returns AUR version, not actual installed version
  - This caused incorrect "up to date" reports when AUR was behind but direct install was current

- **Arithmetic expansion crash** in `beeper-version` when versions are "unknown"
  - Added validation guards before version comparisons
  - Gracefully handles network failures and missing data

- **AUR version extraction** - Fixed non-POSIX regex (`\d` → `[0-9]`)

- **Curl timeout** - Added 10-second timeout to prevent hanging on network issues

## [1.1.0] - 2026-01-24

### Added

- **Lockfile-based concurrency protection** using `flock`
  - Prevents multiple update-beeper instances from running simultaneously
  - Shows PID of blocking process if lock already held
  - Automatically released on exit (including crashes)

- **New CLI options**
  - `--quiet` / `-q`: Silent mode for cron/systemd (only outputs on errors)
  - `--rollback` / `-r`: Manual rollback to previous backup version
  - `--version` / `-v`: Show script version

- **Wayland native rendering support** for Hyprland, Sway, and other Wayland compositors
  - Automatically detects Wayland via `$WAYLAND_DISPLAY`
  - Tests Beeper startup with Ozone platform flags (`--enable-features=UseOzonePlatform --ozone-platform=wayland`)
  - Creates desktop file override at `~/.local/share/applications/beeper.desktop`
  - Fixes blank/white window issues on Wayland without XWayland

- **Sleep/wake stability fix** via `--disable-gpu-compositing` flag
  - Prevents blank screen after screensaver, screen lock, or system sleep
  - Included in Wayland flags by default

- **System compatibility checks** run automatically before updates
  - Architecture verification (x86_64 required)
  - Distro detection (warns if not Arch-based, still works)
  - Dependency check (curl, sudo required)
  - Optional dependency warning (notify-send)

### Changed

- Replaced process-grepping concurrent run detection with proper lockfile mechanism
- Version output now uses `log()` helper for quiet mode support

### Fixed

- **Directory leak in `backup_current()`** - Now uses subshell to prevent working directory changes from affecting the main script
- **Directory leak in extraction loop** - Extraction now runs in isolated subshell
- **UX: "Configuring Wayland" message** - Only displays when actually on Wayland
- Removed hardcoded username/UID from systemd service file
- Scripts now work for any user without modification

## [Unreleased]

(No unreleased changes)

## [1.0.0] - 2026-01-16

### Added

- **Self-healing update system** with automatic retry and targeted fixes
  - Download verification (size > 150MB)
  - Extraction verification (V8 snapshots, main binary)
  - Version verification (package.json check)
  - Startup health check (10s stability test)

- **Automatic rollback** when all recovery attempts fail
  - Keeps last 3 backups in `/opt/beeper-backups/`
  - Restores previous working version automatically

- **Pre-flight system checks**
  - Network connectivity
  - Disk space (500MB minimum)
  - Required permissions
  - Running Beeper detection

- **`beeper-version` script** for quick status check
  - Shows installed, latest, and AUR versions
  - Indicates if updates are available
  - Shows how far behind AUR is

- **CLI options**
  - `--check` / `-c`: Check without installing
  - `--changelog` / `-l`: Open changelog in browser
  - `--force` / `-f`: Force reinstall
  - `--notify` / `-n`: Desktop notifications
  - `--help` / `-h`: Show help

- **Systemd integration**
  - Timer and service files for automatic updates
  - Both system-wide and user service variants

- **GitHub Actions** for shellcheck linting

### Why This Exists

Beeper's built-in updater doesn't work on Arch Linux when installed from AUR.
The app downloads updates but can't overwrite pacman-managed files. This script
downloads directly from Beeper's API, bypassing both the broken built-in updater
and the often-outdated AUR package.

[1.3.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.3.0
[1.2.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.2.0
[1.1.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.1.0
[1.0.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.0.0
