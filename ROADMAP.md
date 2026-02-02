# update-beeper Roadmap

```
    ___  ____  ____  ____  ____  ____     _   _  ____  ____    __   ____  ____  ____ 
   / __)(  __)(  __)(  _ \(  __)(  _ \   / ) ( \(  _ \(    \  /  \ (_  _)(  __)(  _ \
  (  (_ \) _)  ) _)  ) __/ ) _)  )   /  ( (_/ / ) __/ ) D ( (  _ ) _)(_  ) _)  )   /
   \___/(____)(____)(__) (____)(__)_)    \___/ (__)  (____/  \__/ (____)(____)(__)_)
   ____  _  _   ___      __   ____  ___  _  _     _  _  __  __ _  ____  __ _ 
  (  __)( \/ ) / __)    / _\ (  _ \/ __)( )( )   / )( \(  )(  ( \(  __)(  ( \
   ) _) / \/ \( (_ \   /    \ )   /( (__ ) __ (  ) \/ ( )( /    / ) _) /    /
  (__)  \_)(_/ \___/   \_/\_/(__\_) \___)\_)(_/  \____/(__/\_)__)(____)\_)__)

                      🐝 Because the Update Available button should work 🐝
```

---

## Executive Summary

**update-beeper** is a self-healing Beeper Desktop updater for Arch Linux that solves the problem of Beeper's built-in updater not working with pacman-managed installations.

| Metric | Status |
|--------|--------|
| **Current Version** | v1.3.0 |
| **License** | MIT |
| **Test Coverage** | Manual + GitHub Actions CI |
| **Platform** | Arch Linux (x86_64) |
| **Dependencies** | curl, sudo, bash |

### Why This Exists

Beeper's built-in updater doesn't work on Arch Linux when installed from AUR. The app downloads updates but can't overwrite pacman-managed files. This script:

1. Downloads directly from Beeper's API (bypassing the broken updater)
2. Bypasses often-outdated AUR packages (maintainer delay)
3. Provides automatic rollback if updates fail
4. Handles Wayland-specific rendering issues

---

## Version History Timeline

```
2026-01-16          2026-01-24          2026-01-28          2026-02-02
    │                   │                   │                   │
    ▼                   ▼                   ▼                   ▼
┌─────────┐       ┌─────────┐       ┌─────────┐       ┌─────────┐
│  v1.0   │──────▶│  v1.1   │──────▶│  v1.2   │──────▶│  v1.3   │
│ Initial │       │Reliable │       │UX & Mon │       │Security │
└─────────┘       └─────────┘       └─────────┘       └─────────┘
```

---

### v1.0.0 (2026-01-16) - Initial Release

The foundation. A self-healing updater that just works.

**Core Features:**
- Self-healing update system with automatic retry
- Download verification (size > 150MB)
- Extraction verification (V8 snapshots, binaries)
- Startup health check (10s stability test)
- Automatic rollback when all recovery attempts fail
- Pre-flight system validation (network, disk space, permissions)

**New Scripts:**
- `beeper-version` - Quick status check showing installed/latest/AUR versions

**Automation:**
- Systemd timer and service files for automatic daily updates
- `install.sh` for one-command installation

**CLI Options:**
- `--check` / `-c` - Check without installing
- `--changelog` / `-l` - Open changelog in browser
- `--force` / `-f` - Force reinstall
- `--notify` / `-n` - Desktop notifications
- `--help` / `-h` - Show help

**Quality:**
- GitHub Actions workflow for shellcheck linting
- CONTRIBUTING.md guidelines
- CHANGELOG.md with full version history

---

### v1.1.0 (2026-01-24) - Reliability

Focus on concurrent safety and operational flexibility.

**Concurrency Protection:**
- Flock-based lockfile (`/tmp/update-beeper.lock`)
- Shows PID of blocking process if lock already held
- Automatically released on exit (including crashes)

**New CLI Options:**
- `--quiet` / `-q` - Silent mode for cron/systemd (only outputs on errors)
- `--rollback` / `-r` - Manual rollback to previous backup version
- `--version` / `-v` - Show script version

**Wayland Support:**
- Automatic detection via `$WAYLAND_DISPLAY`
- Native Wayland rendering with Ozone platform flags
- Desktop file override at `~/.local/share/applications/beeper.desktop`
- `--disable-gpu-compositing` for sleep/wake stability

**System Compatibility:**
- Architecture verification (x86_64 required)
- Distro detection (warns if not Arch-based)
- Dependency check (curl, sudo required; notify-send optional)

**Bug Fixes:**
- Directory leak in `backup_current()` - now uses subshell
- Directory leak in extraction loop
- Removed hardcoded username/UID from systemd service

---

### v1.2.0 (2026-01-28) - UX & Monitoring

Making updates conversational and adding health monitoring.

**Natural Language Commands:**
- Shell aliases: `bu`, `bv`, `beeper update`, `beeper version`
- Jarvis wrapper: `jarvis-beeper "update beeper"`
- Claude Code skill integration

**New CLI Options:**
- `--versions` - Show all version info at a glance (installed, latest, AUR)

**Health Monitoring:**
- New `beeper-health` script detects unresponsive Beeper
- Checks if process running but window missing (blank screen symptom)
- Auto-restarts with XWayland mode if blank screen detected
- Systemd timer for 5-minute monitoring interval

**Critical Bug Fixes:**
- Version detection now uses `package.json` (source of truth) instead of `pacman -Q`
- Arithmetic expansion crash when versions are "unknown"
- Non-POSIX regex (`\d` changed to `[0-9]`)
- Added curl timeout (10s) to prevent hanging

---

### v1.3.0 (2026-02-02) - Security Hardening

Focus on supply chain security and download integrity.

**Security Enhancements:**
- Domain validation: Verify download URLs come from trusted Beeper domains only
- HTTP status checking: Fail properly on API errors instead of silent failures
- Checksum verification: SHA256 trust-on-first-run model for download integrity
- Race condition fix: Safer backup cleanup using atomic find operations

**New CLI Options:**
- `--skip-checksum` - Bypass checksum verification for forced re-downloads

**Technical Details:**

| Protection | Attack Vector | Mitigation |
|------------|---------------|------------|
| Domain validation | MITM redirect to malicious site | Whitelist: beeper.com, todesktop.com |
| HTTP status check | API failures treated as success | Validate 200/302 responses |
| SHA256 checksum | Corrupted/tampered downloads | Trust-on-first-run verification |
| Atomic cleanup | TOCTOU race in backup deletion | Use find with pattern matching |

**File Locations:**
- Checksum cache: `~/.cache/update-beeper/checksums.txt`

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            UPDATE FLOW DIAGRAM                               │
└─────────────────────────────────────────────────────────────────────────────┘

     ┌──────────┐
     │  START   │
     └────┬─────┘
          │
          ▼
    ┌───────────┐     ┌──────────────────────────────────────────────────────┐
    │  Acquire  │     │ LOCKFILE (/tmp/update-beeper.lock)                   │
    │   Lock    │────▶│ • flock-based for atomic acquisition                 │
    └─────┬─────┘     │ • Shows PID of blocking process                      │
          │           │ • Auto-released on exit/crash                        │
          ▼           └──────────────────────────────────────────────────────┘
    ┌───────────┐
    │  System   │     Checks: x86_64, Arch-based, curl, sudo
    │  Compat   │
    └─────┬─────┘
          │
          ▼
    ┌───────────┐     ┌──────────────────────────────────────────────────────┐
    │   Check   │     │ VERSION SOURCES                                      │
    │ Versions  │────▶│ • Installed: /opt/beeper/resources/app/package.json  │
    └─────┬─────┘     │ • Latest: api.beeper.com redirect URL                │
          │           │ • AUR: aur.archlinux.org/packages/beeper-v4-bin      │
          │           └──────────────────────────────────────────────────────┘
          ▼
    ┌───────────┐  No Update
    │ Up-to-date├────────────────────────────────────────────┐
    │     ?     │                                            │
    └─────┬─────┘                                            │
          │ Update Available                                 │
          ▼                                                  │
    ┌───────────┐     ┌──────────────────────────────────────────────────────┐
    │ Download  │     │ DOWNLOAD VERIFICATION                                │
    │ AppImage  │────▶│ • Size > 150MB (MIN_APPIMAGE_SIZE)                   │
    └─────┬─────┘     │ • Retry up to MAX_DOWNLOAD_RETRIES (2)               │
          │           └──────────────────────────────────────────────────────┘
          ▼
    ┌───────────┐     ┌──────────────────────────────────────────────────────┐
    │  Extract  │     │ EXTRACTION VERIFICATION                              │
    │ squashfs  │────▶│ • Critical files: beepertexts, snapshot_blob.bin,    │
    └─────┬─────┘     │   v8_context_snapshot.bin, resources/app/package.json│
          │           │ • Retry up to MAX_EXTRACTION_RETRIES (2)             │
          ▼           └──────────────────────────────────────────────────────┘
    ┌───────────┐
    │  Apply    │     Patches: AppRun fix, auto-update disable
    │  Patches  │
    └─────┬─────┘
          │
          ▼
    ┌───────────┐     ┌──────────────────────────────────────────────────────┐
    │  Backup   │     │ BACKUP MANAGEMENT                                    │
    │  Current  │────▶│ • /opt/beeper-backups/beeper-backup-YYYYMMDD-HHMMSS  │
    └─────┬─────┘     │ • Keeps last 3 backups                               │
          │           └──────────────────────────────────────────────────────┘
          ▼
    ┌───────────┐     ┌──────────────────────────────────────────────────────┐
    │  Install  │     │ PERMISSION SETUP                                     │
    │   Files   │────▶│ • root:root ownership                                │
    └─────┬─────┘     │ • 755 for directories                                │
          │           │ • 4755 for chrome-sandbox (setuid)                   │
          ▼           └──────────────────────────────────────────────────────┘
    ┌───────────┐
    │  Verify   │     Check package.json version matches expected
    │  Version  │
    └─────┬─────┘
          │
          ▼
    ┌───────────┐     ┌──────────────────────────────────────────────────────┐
    │  Wayland  │     │ WAYLAND FLAGS (if $WAYLAND_DISPLAY set)              │
    │  Setup    │────▶│ --enable-features=UseOzonePlatform                   │
    └─────┬─────┘     │ --ozone-platform=wayland                             │
          │           │ --disable-gpu-compositing                            │
          ▼           └──────────────────────────────────────────────────────┘
    ┌───────────┐     ┌──────────────────────────────────────────────────────┐
    │  Health   │     │ STARTUP VERIFICATION                                 │
    │   Check   │────▶│ • Launch Beeper                                      │
    └─────┬─────┘     │ • Check process alive at 3s, 6s, 10s                 │
          │           │ • Retry up to MAX_STARTUP_RETRIES (2)                │
          │           └──────────────────────────────────────────────────────┘
          ▼
    ┌───────────┐                              ┌───────────┐
    │  SUCCESS  │◀────── If Failed ───────────▶│ ROLLBACK  │
    └───────────┘                              └───────────┘
                                                     │
                                                     ▼
                                               Restore from
                                               /opt/beeper-backups/
```

---

## Feature Matrix

| Feature | v1.0 | v1.1 | v1.2 | v1.3 |
|---------|:----:|:----:|:----:|:----:|
| **Core** |
| Self-healing download | ✅ | ✅ | ✅ | ✅ |
| Auto-rollback | ✅ | ✅ | ✅ | ✅ |
| Critical file verification | ✅ | ✅ | ✅ | ✅ |
| Startup health check | ✅ | ✅ | ✅ | ✅ |
| Pre-flight validation | ✅ | ✅ | ✅ | ✅ |
| **CLI Options** |
| `--check` | ✅ | ✅ | ✅ | ✅ |
| `--force` | ✅ | ✅ | ✅ | ✅ |
| `--notify` | ✅ | ✅ | ✅ | ✅ |
| `--changelog` | ✅ | ✅ | ✅ | ✅ |
| `--quiet` | - | ✅ | ✅ | ✅ |
| `--rollback` | - | ✅ | ✅ | ✅ |
| `--version` | - | ✅ | ✅ | ✅ |
| `--versions` | - | - | ✅ | ✅ |
| **Automation** |
| Systemd timer/service | ✅ | ✅ | ✅ | ✅ |
| One-command install | ✅ | ✅ | ✅ | ✅ |
| Concurrent run protection | - | ✅ | ✅ | ✅ |
| **Wayland** |
| Native rendering | - | ✅ | ✅ | ✅ |
| Desktop file override | - | ✅ | ✅ | ✅ |
| Sleep/wake stability | - | ✅ | ✅ | ✅ |
| **Monitoring** |
| beeper-version script | ✅ | ✅ | ✅ | ✅ |
| beeper-health script | - | - | ✅ | ✅ |
| Blank screen detection | - | - | ✅ | ✅ |
| **UX** |
| Natural language aliases | - | - | ✅ | ✅ |
| Jarvis wrapper | - | - | ✅ | ✅ |
| Claude Code skill | - | - | ✅ | ✅ |
| **Security** |
| Download URL validation | - | - | - | ✅ |
| HTTP status checking | - | - | - | ✅ |
| Checksum verification | - | - | - | ✅ |
| `--skip-checksum` | - | - | - | ✅ |

---

## Planned Features (v1.4.0+)

### Near-Term (v1.4.0)

| Feature | Priority | Description |
|---------|----------|-------------|
| Structured error codes | High | Exit codes for different failure types |
| JSON output mode | Medium | `--json` flag for machine-readable output |
| Logging to file | Medium | Optional `--log` flag for debugging |
| AUR package submission | Low | Submit `update-beeper` itself to AUR for easy installation |

### Mid-Term (v1.5.0)

| Feature | Priority | Description |
|---------|----------|-------------|
| Delta updates | High | Download only changed files (significant bandwidth savings) |
| Multi-version management | Medium | Keep multiple Beeper versions, switch between them |
| Config backup/restore | Medium | Backup `~/.config/BeeperTexts` during updates |
| Notification channels | Low | Webhook support for update notifications |

### Long-Term (v2.0.0)

| Feature | Priority | Description |
|---------|----------|-------------|
| GUI wrapper | Medium | Optional GTK/Qt interface for non-CLI users |
| Other distros | Medium | Debian/Ubuntu, Fedora support |
| ARM64 support | Low | When Beeper provides ARM builds |
| Plugin system | Low | User-extensible pre/post update hooks |

---

## Contributing

We welcome contributions! Here's how to get started.

### Quick Start

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/update-beeper.git
cd update-beeper

# Check syntax
bash -n update-beeper
bash -n beeper-version
bash -n beeper-health

# Run shellcheck
shellcheck update-beeper beeper-version beeper-health

# Test (safe, doesn't modify anything)
./update-beeper --check
./beeper-version
```

### Code Style

- Use `bash` (not `sh`)
- Use `[[ ]]` for conditionals, not `[ ]`
- Quote variables: `"$VAR"` not `$VAR`
- Use meaningful variable names
- Add comments for non-obvious logic
- Keep functions focused and small

### Testing Requirements

Before submitting a PR:

1. **Syntax check:** `bash -n update-beeper`
2. **Shellcheck:** `shellcheck update-beeper beeper-version beeper-health`
3. **Check mode:** `./update-beeper --check`
4. **Version display:** `./beeper-version`

### Commit Messages

- Use present tense: "Add feature" not "Added feature"
- First line: short summary (50 chars or less)
- Body: explain what and why, not how

### Philosophy

> **Simple, focused, reliable.**

This project aims to do one thing well: keep Beeper updated on Arch Linux. When considering new features, ask:

1. Does this solve a real problem users face?
2. Does it maintain the simplicity of the tool?
3. Can it fail gracefully?

---

## Resources

- **Repository:** https://github.com/beeper-community/update-beeper
- **Issues:** https://github.com/beeper-community/update-beeper/issues
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)
- **Contributing:** [CONTRIBUTING.md](CONTRIBUTING.md)
- **Beeper Desktop Changelog:** https://www.beeper.com/changelog/desktop

---

*Last updated: 2026-02-02 | Current version: v1.3.0*
