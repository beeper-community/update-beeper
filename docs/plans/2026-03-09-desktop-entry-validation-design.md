# Desktop Entry Validation & Icon Management — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add desktop shortcut validation, icon installation, and stale shortcut cleanup to update-beeper, exposed both as a post-update step and a standalone `--check-desktop` flag.

**Architecture:** A `validate_desktop_entry()` function performs all checks (Exec binary, icon, version, stale duplicates) using the existing `check_add`/`check_flush` pattern. A `install_icon()` function copies the bundled icon into the hicolor theme. `setup_wayland_desktop_override()` is rewritten to use the bundled desktop file as source and create `beeper-wayland.desktop` (matching the user's actual convention). `beeper-health` gains a `--desktop` flag that calls `update-beeper --check-desktop`.

**Tech Stack:** Bash, XDG Desktop Entry spec, hicolor icon theme, gtk-update-icon-cache

**Key files:**
- Modify: `update-beeper` (main script, ~1400 lines)
- Modify: `beeper-health` (health checker, ~58 lines)

**Key reference paths:**
- Bundled desktop file: `/opt/beeper/beepertexts.desktop`
- Bundled icon (symlink target): `/opt/beeper/usr/share/icons/hicolor/512x512/apps/beepertexts.png`
- User desktop dir: `~/.local/share/applications/`
- User icon dir: `~/.local/share/icons/hicolor/512x512/apps/`
- User's wrapper script: `~/bin/beeper-wayland`
- Installed binary: `/opt/beeper/beepertexts`

---

## Task 1: Add `install_icon()` function

**Files:**
- Modify: `update-beeper` — insert after `setup_wayland_desktop_override()` (line ~1160)

**Step 1: Write the `install_icon()` function**

Insert after the closing `}` of `setup_wayland_desktop_override()` (~line 1160):

```bash
install_icon() {
    local bundled_icon="$INSTALL_DIR/usr/share/icons/hicolor/512x512/apps/beepertexts.png"
    local user_icon_dir="$HOME/.local/share/icons/hicolor/512x512/apps"
    local user_icon="$user_icon_dir/beepertexts.png"

    if [[ ! -f "$bundled_icon" ]]; then
        warn "Bundled icon not found, skipping icon install"
        return 0
    fi

    mkdir -p "$user_icon_dir"

    if [[ -f "$user_icon" ]] && cmp -s "$bundled_icon" "$user_icon"; then
        return 0  # Already up to date
    fi

    cp "$bundled_icon" "$user_icon"
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

    pass "Icon installed (512x512)"
    return 0
}
```

**Step 2: Call `install_icon` from Phase 7 (Configuring)**

In `do_direct_install()`, find the line `setup_wayland_desktop_override` (~line 1291) and add after it:

```bash
    install_icon
```

**Step 3: Test manually**

Run:
```bash
bash -x ~/repos/update-beeper/update-beeper --dry-run 2>&1 | grep -i icon
# Verify no errors from the function definition
```

Also test the function in isolation:
```bash
source ~/repos/update-beeper/update-beeper --help 2>/dev/null; install_icon
ls -la ~/.local/share/icons/hicolor/512x512/apps/beepertexts.png
```

**Step 4: Commit**

```bash
git add update-beeper
git commit -m "feat: install Beeper icon to hicolor theme during updates"
```

---

## Task 2: Rewrite `setup_wayland_desktop_override()`

The current function:
- Sources from `/usr/share/applications/beeper.desktop` (often doesn't exist after direct install)
- Creates `beeper.desktop` (doesn't match user's `beeper-wayland.desktop` convention)
- Uses generic `WAYLAND_FLAGS` (user actually needs XWayland mode with GPU disabled)

**Files:**
- Modify: `update-beeper` — replace `setup_wayland_desktop_override()` (lines 1138-1160)

**Step 1: Add constants near the top of the file**

After the existing `USER_DESKTOP_DIR` definition (line 15), add:

```bash
USER_DESKTOP_FILE="$USER_DESKTOP_DIR/beeper-wayland.desktop"
BUNDLED_DESKTOP="$INSTALL_DIR/beepertexts.desktop"
USER_ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
```

**Step 2: Replace `setup_wayland_desktop_override()`**

Replace the entire function (lines 1138-1160) with:

```bash
setup_wayland_desktop_override() {
    if [[ -z "$WAYLAND_DISPLAY" ]]; then
        return 0
    fi

    mkdir -p "$USER_DESKTOP_DIR"

    # Source: bundled desktop file from AppImage extraction
    local source_desktop="$BUNDLED_DESKTOP"

    if [[ ! -f "$source_desktop" ]]; then
        # Fallback: generate from scratch
        source_desktop=""
    fi

    # Determine Exec line based on wrapper script
    local exec_path="/opt/beeper/beepertexts"
    local exec_line

    if [[ -x "$HOME/bin/beeper-wayland" ]]; then
        # User has a custom wrapper — point to it
        exec_line="$HOME/bin/beeper-wayland %U"
    else
        # No wrapper — use binary directly with Wayland flags
        exec_line="$exec_path $WAYLAND_FLAGS --no-sandbox %U"
    fi

    if [[ -n "$source_desktop" ]]; then
        cp "$source_desktop" "$USER_DESKTOP_FILE"
        # Update Exec line
        sed -i "s|^Exec=.*|Exec=$exec_line|" "$USER_DESKTOP_FILE"
        # Update Name
        sed -i "s|^Name=.*|Name=Beeper|" "$USER_DESKTOP_FILE"
        # Ensure proper MIME types
        sed -i "s|^MimeType=.*|MimeType=x-scheme-handler/beeper;x-scheme-handler/matrix;x-scheme-handler/element;|" "$USER_DESKTOP_FILE"
    else
        # Generate desktop file from scratch
        cat > "$USER_DESKTOP_FILE" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Beeper
GenericName=Unified Messenger
Comment=The ultimate messaging app (Wayland optimized)
Exec=$exec_line
Icon=beepertexts
Terminal=false
StartupWMClass=BeeperTexts
MimeType=x-scheme-handler/beeper;x-scheme-handler/matrix;x-scheme-handler/element;
Categories=Network;InstantMessaging;
Keywords=chat;messaging;whatsapp;telegram;discord;
DESKTOP
    fi

    # Update version metadata
    local installed_version
    installed_version=$(grep -oP '"version":\s*"\K[0-9]+\.[0-9]+\.[0-9]+' \
        "$INSTALL_DIR/resources/app/package.json" 2>/dev/null | head -1)
    if [[ -n "$installed_version" ]]; then
        if grep -q '^X-AppImage-Version=' "$USER_DESKTOP_FILE"; then
            sed -i "s|^X-AppImage-Version=.*|X-AppImage-Version=$installed_version|" "$USER_DESKTOP_FILE"
        else
            echo "X-AppImage-Version=$installed_version" >> "$USER_DESKTOP_FILE"
        fi
    fi

    # Clean up stale desktop files
    cleanup_stale_desktop_files

    update-desktop-database "$USER_DESKTOP_DIR" 2>/dev/null || true

    pass "Desktop entry configured ($USER_DESKTOP_FILE)"
    return 0
}
```

**Step 3: Add `cleanup_stale_desktop_files()`**

Insert right before `setup_wayland_desktop_override()`:

```bash
cleanup_stale_desktop_files() {
    local stale_files=(
        "$USER_DESKTOP_DIR/beeper.desktop"
        "$USER_DESKTOP_DIR/beepertexts.desktop"
    )

    for f in "${stale_files[@]}"; do
        if [[ -f "$f" ]]; then
            rm -f "$f"
            detail "Removed stale: $(basename "$f")"
        fi
    done
}
```

**Step 4: Test**

```bash
# Verify the desktop file gets created correctly
bash -c 'source ~/repos/update-beeper/update-beeper --help' 2>/dev/null
```

Manually inspect `~/.local/share/applications/beeper-wayland.desktop` — Exec should point to `~/bin/beeper-wayland %U`.

**Step 5: Commit**

```bash
git add update-beeper
git commit -m "feat: rewrite desktop override to use bundled source and beeper-wayland.desktop"
```

---

## Task 3: Add `validate_desktop_entry()` function

**Files:**
- Modify: `update-beeper` — insert after `install_icon()`

**Step 1: Write the validation function**

```bash
validate_desktop_entry() {
    local errors=0

    check_reset

    # 1. Desktop file exists
    if [[ -f "$USER_DESKTOP_FILE" ]]; then
        check_add "desktop file" "pass"
    else
        check_add "desktop file" "fail" "not found: $USER_DESKTOP_FILE"
        check_flush
        return 1
    fi

    # 2. Exec binary resolves
    local exec_line
    exec_line=$(grep -m1 '^Exec=' "$USER_DESKTOP_FILE" | sed 's/^Exec=//' | awk '{print $1}')
    if [[ -x "$exec_line" ]]; then
        check_add "exec binary" "pass"
    else
        # Check if it's in PATH
        if command -v "$exec_line" &>/dev/null; then
            check_add "exec binary" "pass"
        else
            check_add "exec binary" "fail" "not found: $exec_line"
            errors=$((errors + 1))
        fi
    fi

    # 3. Exec binary points to correct version
    local desktop_version installed_version
    desktop_version=$(grep -oP 'X-AppImage-Version=\K.*' "$USER_DESKTOP_FILE" 2>/dev/null)
    installed_version=$(grep -oP '"version":\s*"\K[0-9]+\.[0-9]+\.[0-9]+' \
        "$INSTALL_DIR/resources/app/package.json" 2>/dev/null | head -1)

    if [[ -n "$desktop_version" ]] && [[ -n "$installed_version" ]]; then
        if [[ "$desktop_version" == "$installed_version" ]]; then
            check_add "version match" "pass"
        else
            check_add "version match" "warn" "desktop=$desktop_version installed=$installed_version"
        fi
    elif [[ -z "$desktop_version" ]]; then
        check_add "version match" "warn" "no version metadata in desktop file"
    fi

    # 4. Icon resolves
    local icon_name
    icon_name=$(grep -m1 '^Icon=' "$USER_DESKTOP_FILE" | sed 's/^Icon=//')
    if [[ -n "$icon_name" ]]; then
        if echo "$icon_name" | grep -q '/'; then
            # Absolute path
            if [[ -f "$icon_name" ]]; then
                check_add "icon" "pass"
            else
                check_add "icon" "fail" "path not found: $icon_name"
                errors=$((errors + 1))
            fi
        else
            # Theme name — check hicolor
            local found_icon=false
            for size_dir in "$USER_ICON_DIR" "$HOME/.local/share/icons/hicolor"/*/apps /usr/share/icons/hicolor/*/apps; do
                if [[ -f "$size_dir/$icon_name.png" ]] || [[ -f "$size_dir/$icon_name.svg" ]]; then
                    found_icon=true
                    break
                fi
            done
            if [[ "$found_icon" == true ]]; then
                check_add "icon" "pass"
            else
                check_add "icon" "warn" "\"$icon_name\" not found in icon theme — run update-beeper to install"
                errors=$((errors + 1))
            fi
        fi
    fi

    # 5. No stale duplicates
    local stale_count=0
    for f in "$USER_DESKTOP_DIR/beeper.desktop" "$USER_DESKTOP_DIR/beepertexts.desktop"; do
        if [[ -f "$f" ]]; then
            stale_count=$((stale_count + 1))
        fi
    done
    if [[ $stale_count -gt 0 ]]; then
        check_add "stale files" "warn" "$stale_count stale Beeper desktop file(s) found"
    fi

    check_flush

    if [[ $errors -gt 0 ]]; then
        return 1
    fi
    return 0
}
```

**Step 2: Commit**

```bash
git add update-beeper
git commit -m "feat: add validate_desktop_entry() for shortcut health checks"
```

---

## Task 4: Add `--check-desktop` CLI flag

**Files:**
- Modify: `update-beeper` — add flag parsing and early-exit handler

**Step 1: Add flag variable**

Near the other flag definitions (line ~80), add:

```bash
CHECK_DESKTOP=false
```

**Step 2: Add to argument parser**

In the `case` statement for argument parsing, add:

```bash
        --check-desktop) CHECK_DESKTOP=true ;;
```

**Step 3: Add to `usage()` output**

After the `--history` line (~line 97), add:

```bash
    echo "  --check-desktop   Validate Beeper desktop shortcut and icon"
```

**Step 4: Add early-exit handler**

After the `--versions` handler block (~line 1384), add:

```bash
# Handle desktop validation (early exit)
if [[ "$CHECK_DESKTOP" == true ]]; then
    print_header
    phase 1 1 "Desktop entry validation"
    validate_desktop_entry
    exit $?
fi
```

**Step 5: Test**

```bash
~/repos/update-beeper/update-beeper --check-desktop
```

Expected output:
```
  🐝 Beeper Updater v1.8.0

  [1/1] Desktop entry validation
    ✓ All 4 checks passed (desktop file, exec binary, version match, icon)
```

Or with issues:
```
  [1/1] Desktop entry validation
    ✓ desktop file
    ✗ icon — "beepertexts" not found in icon theme — run update-beeper to install
```

**Step 6: Commit**

```bash
git add update-beeper
git commit -m "feat: add --check-desktop flag for standalone shortcut validation"
```

---

## Task 5: Add desktop validation to post-update flow

**Files:**
- Modify: `update-beeper` — in `do_direct_install()`, after `install_icon`

**Step 1: Add validation call after icon install**

In `do_direct_install()`, after the `install_icon` call added in Task 1, add:

```bash
    validate_desktop_entry
```

**Step 2: Add `Desktop` row to summary box**

In `summary_box()` (~line 304), after the Wayland row block, add:

```bash
    # Desktop entry status
    if [[ -f "$USER_DESKTOP_FILE" ]]; then
        pad_row "${ACCENT}Desktop${NC}   $(basename "$USER_DESKTOP_FILE")"
    fi
```

**Step 3: Test with `--dry-run`**

```bash
~/repos/update-beeper/update-beeper --dry-run
```

Verify the summary box now includes a `Desktop` row.

**Step 4: Commit**

```bash
git add update-beeper
git commit -m "feat: run desktop validation post-update and show in summary box"
```

---

## Task 6: Integrate with `beeper-health`

**Files:**
- Modify: `beeper-health`

**Step 1: Add `--desktop` flag handling and update main logic**

Replace the entire `beeper-health` script with:

```bash
#!/bin/bash
# beeper-health - Monitor Beeper and restart if unresponsive
# Flags: --desktop (validate desktop shortcut via update-beeper)

set -e

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

BEEPER_WAYLAND=~/bin/beeper-wayland
LOG_FILE=/tmp/beeper-health.log
UPDATE_BEEPER="$HOME/.local/bin/update-beeper"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Parse args
CHECK_DESKTOP=false
for arg in "$@"; do
    case "$arg" in
        --desktop) CHECK_DESKTOP=true ;;
        --help|-h)
            echo "Usage: beeper-health [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --desktop    Validate desktop shortcut and icon"
            echo "  --help, -h   Show this help"
            echo ""
            echo "Without flags: checks if Beeper is responsive, restarts if not."
            exit 0
            ;;
    esac
done

# Desktop validation (delegates to update-beeper)
if [[ "$CHECK_DESKTOP" == true ]]; then
    if [[ -x "$UPDATE_BEEPER" ]]; then
        exec "$UPDATE_BEEPER" --check-desktop
    else
        echo -e "${RED}Error: update-beeper not found at $UPDATE_BEEPER${NC}" >&2
        exit 1
    fi
fi

check_beeper_responsive() {
    # Check if hyprctl is available (Hyprland-specific)
    if ! command -v hyprctl &>/dev/null; then
        echo -e "${RED}Error: hyprctl not found. This script requires Hyprland.${NC}" >&2
        return 1
    fi

    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: jq not found. Install with: sudo pacman -S jq${NC}" >&2
        return 1
    fi

    # Check if Beeper window exists and is mapped
    if ! hyprctl clients -j | jq -e '.[] | select(.class | test("eeper"; "i"))' > /dev/null 2>&1; then
        return 1  # No window found
    fi
    return 0
}

restart_beeper() {
    echo "[$(date)] Restarting Beeper with XWayland mode..." >> "$LOG_FILE"

    # Verify restart script exists
    if [[ ! -x "$BEEPER_WAYLAND" ]]; then
        echo "[$(date)] Error: $BEEPER_WAYLAND not found or not executable" >> "$LOG_FILE"
        return 1
    fi

    killall -9 beepertexts 2>/dev/null || true
    sleep 2
    nohup "$BEEPER_WAYLAND" > /dev/null 2>&1 &
}

# Main check
if pgrep -x beepertexts > /dev/null; then
    if ! check_beeper_responsive; then
        echo "[$(date)] Beeper process running but no window - restarting" >> "$LOG_FILE"
        restart_beeper
    fi
else
    echo "[$(date)] Beeper not running" >> "$LOG_FILE"
fi
```

**Step 2: Test**

```bash
~/repos/update-beeper/beeper-health --desktop
~/repos/update-beeper/beeper-health --help
```

**Step 3: Commit**

```bash
git add beeper-health
git commit -m "feat: add --desktop flag to beeper-health (delegates to update-beeper)"
```

---

## Task 7: Bump version and update help text

**Files:**
- Modify: `update-beeper` — line 7

**Step 1: Bump version**

```bash
SCRIPT_VERSION="1.8.0"
```

**Step 2: Update Wayland Support section in `usage()`**

Replace lines 105-108 with:

```bash
    echo "Wayland Support:"
    echo "  On Wayland (Hyprland, Sway, etc.), this script automatically:"
    echo "  - Creates ~/.local/share/applications/beeper-wayland.desktop"
    echo "  - Installs icon to hicolor theme for launcher display"
    echo "  - Validates desktop entry points to correct binary and version"
    echo "  - Cleans up stale Beeper shortcuts"
```

**Step 3: Commit**

```bash
git add update-beeper
git commit -m "chore: bump to v1.8.0, update help text for desktop management"
```

---

## Task 8: Run the icon install + desktop fix now

Since we just cleaned up the broken shortcuts earlier in this session, run the new functions to set things right with the proper `beeper-wayland.desktop` and icon.

**Step 1: Install the icon immediately**

```bash
mkdir -p ~/.local/share/icons/hicolor/512x512/apps
cp /opt/beeper/usr/share/icons/hicolor/512x512/apps/beepertexts.png \
   ~/.local/share/icons/hicolor/512x512/apps/beepertexts.png
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor 2>/dev/null || true
```

**Step 2: Verify icon shows in launcher**

```bash
ls -la ~/.local/share/icons/hicolor/512x512/apps/beepertexts.png
```

**Step 3: Run `--check-desktop` to validate everything**

```bash
~/repos/update-beeper/update-beeper --check-desktop
```

Expected: all checks pass.

---

## Summary of changes

| Component | Change | Lines affected |
|-----------|--------|---------------|
| `update-beeper` | Add `USER_DESKTOP_FILE`, `BUNDLED_DESKTOP`, `USER_ICON_DIR` constants | ~15-17 |
| `update-beeper` | Add `CHECK_DESKTOP` flag + arg parsing + early exit | ~80, ~130, ~1384 |
| `update-beeper` | Add `cleanup_stale_desktop_files()` | new function |
| `update-beeper` | Rewrite `setup_wayland_desktop_override()` | replace lines 1138-1160 |
| `update-beeper` | Add `install_icon()` | new function |
| `update-beeper` | Add `validate_desktop_entry()` | new function |
| `update-beeper` | Add Desktop row to `summary_box()` | ~308 |
| `update-beeper` | Bump version to 1.8.0 | line 7 |
| `update-beeper` | Update `usage()` help text | ~105-108 |
| `beeper-health` | Add `--desktop` flag, delegate to `update-beeper` | full rewrite |
