# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.8.1] - 2026-03-17

### Fixed

- **API version check timeout** — The curl call followed the API redirect (`-L`) and started downloading the ~200MB AppImage to `/dev/null`, always timing out (exit code 28) on slower connections
- **Version extraction false positives** — Fallback regex could match semver patterns in CDN domain/path prefixes (e.g., `cdn-v3.example.com`); now restricted to filename via `basename`

### Changed

- **Progressive URL resolution** — Replaced single curl call with 3-strategy fallback:
  1. **HEAD request** — reads Location header without following redirect (~0.7s)
  2. **Range 0-0** — follows redirects, requests 1 byte only (~1.0s)
  3. **Full GET** — last resort with `--max-filesize 1MB` bandwidth cap (~10s)
- **`set -e` safety** — All curl calls in version check now have `|| true` to prevent silent failures during future refactoring
- **Case-insensitive header parsing** — Location header extraction handles all case forms (`Location:`, `location:`, `LOCATION:`)

### Performance

| Metric | Before | After |
|--------|--------|-------|
| Version check | 30s timeout → exit 28 | **0.7s** → success |
| Full script to prereqs | Never reached | **4.1s** |

## [1.8.0] - 2026-03-09

### Added

- **Desktop entry validation** — New `validate_desktop_entry()` checks shortcut health: file exists, Exec binary resolves, version matches installed, icon resolves in theme, no stale duplicates
- **`--check-desktop` flag** — Standalone desktop shortcut validation without running an update
- **Icon installation** — New `install_icon()` copies bundled 512px Beeper icon to `~/.local/share/icons/hicolor/` so launchers display the icon properly
- **Stale shortcut cleanup** — New `cleanup_stale_desktop_files()` removes leftover `beeper.desktop` and `beepertexts.desktop` files that cause duplicate launcher entries
- **Desktop row in summary box** — Post-update summary now shows which desktop file is configured
- **`beeper-health --desktop`** — Delegates desktop validation to `update-beeper --check-desktop`

### Changed

- **Rewrote `setup_wayland_desktop_override()`** — Now uses bundled `/opt/beeper/beepertexts.desktop` as source (not the often-missing system file), creates `beeper-wayland.desktop` (matching user convention), detects `~/bin/beeper-wayland` wrapper script, stamps `X-AppImage-Version` for version tracking
- **Desktop file convention** — Changed from `beeper.desktop` to `beeper-wayland.desktop` to match actual user setup
- Uses `$INSTALL_DIR` variable instead of hardcoded `/opt/beeper` in desktop exec path

### Fixed

- **`set -e` crash in validation** — `grep -oP` returns exit 1 on no match, killing the script under `set -e`. Added `|| true` to all grep calls in `validate_desktop_entry()`

## [1.7.0] - 2026-03-03

### Added

- **Runtime dependency preservation** — New `preserve_runtime_deps()` function prevents orphan cleanup from silently removing Beeper's runtime dependencies after pacman deregistration
- **`BEEPER_RUNTIME_DEPS` constant** — Declares `libappindicator libnotify libsecret hicolor-icon-theme` as critical runtime deps
- Uses `pacman -D --asexplicit` (DB-only, no download) to mark deps as explicitly installed

### Fixed

- **Orphaned dependency removal** — After `deregister_pacman_tracking()` removed `beeper-v4-bin` from pacman's DB, dependencies like `libappindicator` became orphans and were silently removed by system update cleanup, breaking tray icons

## [1.6.0] - 2026-02-28

### Added

- **Pacman deregistration** — New `deregister_pacman_tracking()` function removes stale AUR package entry after successful direct install, preventing version desync between pacman DB and actual installed files
- Move-remove-restore strategy: moves `/opt/Beeper` aside, runs `pacman -Rdd`, restores files

## [1.5.0] - 2026-02-14

### Added

- **Beeper-branded true color palette** — Purple `#6953f2`, blue `#0c52f9`, muted emerald, soft red, warm amber, lavender-gray, light purple
- **256-color terminal fallback** — Automatic `$COLORTERM` detection degrades gracefully on older terminals
- **5-level typography hierarchy** — Phase headers, pass/fail/warn sub-steps, info text, action indicators, hints
- **8 numbered phases** `[n/8]` — Consolidated from 17 emoji-headed micro-phases into coherent steps
- **Collapsible check groups** — One-line summary when all checks pass, expands only on failure
- **Unicode summary box** — `╭╮╰╯│─` bordered completion panel with version, method, duration, retries
- **Branded dry-run box** — Labeled info panel matching the summary box style

### Changed

- Output reduced from ~60 lines to ~25 on success, 5 when already up-to-date
- All emoji removed from functional output (only `🐝` in header banner)
- All output flows through 7 helper functions (`pass`/`fail`/`warn`/`detail`/`action`/`hint`/`phase`)
- Dynamic step counter: 4 steps for AUR path, 8 for direct install

### Removed

- Generic ANSI color scheme (`RED`/`GREEN`/`YELLOW`/`CYAN` variables)
- All emoji from phase headers (`📥📦💾🔍🚀🔧🔐🖥️⚡🧪📋`)
- Backward compatibility color aliases

## [1.4.0] - 2026-02-14

### Added

- **`--dry-run` flag** — Preview what would happen without making changes
- **`--history` flag** — View past update attempts with timestamps and outcomes
- **Structured logging** — All events logged to `~/.local/share/update-beeper/update-beeper.log`
- **Update history file** — Persistent record at `~/.local/share/update-beeper/history.txt`
- **ELF binary verification** — Validates extracted binary is a real Linux ELF executable
- **Download resume** — `curl -C -` resumes interrupted downloads instead of restarting
- **Disk space pre-check** — Verifies 1200MB available on `/opt` before install
- **URL domain validation** — Verifies downloads come from trusted Beeper domains only
- **Install step failure guards** — `apply_patches`, `backup_current`, `install_files` abort on failure

### Changed

- **Single Beeper API call** — Combined two separate curl requests into one
- **AUR JSON RPC API** — Replaced fragile HTML scraping with `aur.archlinux.org/rpc/v5/info` endpoint
- **Dynamic update reasons** — `perform_update()` tracks why direct install was chosen

### Security

| Protection | Attack Vector | Mitigation |
|------------|---------------|------------|
| Domain validation | MITM redirect to malicious download | Whitelist trusted domains |
| ELF verification | Corrupted/trojanized binary | Validate file magic bytes |
| Install guards | Partial install on failure | Abort and rollback on any step failure |

## [1.3.0] - 2026-02-02

### Added

- **Omarchy Integration** - Prevents conflicts with AUR package
  - Documents proper coexistence with `beeper-v4-bin` AUR package
  - Provides migration script for omarchy users: removes AUR package tracking
  - Adds `beeper-v4-bin` to yay ignore list in `omarchy-update-system-pkgs`
  - See `learnings/beeper-package-conflict-fix.md` for details

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

[1.8.1]: https://github.com/beeper-community/update-beeper/releases/tag/v1.8.1

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

[1.8.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.8.0
[1.7.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.7.0
[1.6.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.6.0
[1.5.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.5.0
[1.4.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.4.0
[1.3.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.3.0
[1.2.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.2.0
[1.1.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.1.0
[1.0.0]: https://github.com/beeper-community/update-beeper/releases/tag/v1.0.0
