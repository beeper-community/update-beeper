# v1.9.0 Interactive Menu + Branch Support + Changelog Pipeline — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an interactive CLI menu, branch switching (stable/nightly/beta), and a changelog pipeline sourced from beeper-intel's automated GitHub Action.

**Architecture:** TTY-detected menu dispatches to fzf/dialog/whiptail/pure-bash backends. Branch config persists in `~/.config/update-beeper/config`. Changelog data fetched from beeper-intel raw GitHub URLs with local 6h TTL cache. A Playwright-based GitHub Action in beeper-intel scrapes versions and changelogs daily.

**Tech Stack:** Bash 5+ (menu, branch, display), Node.js 20 + Playwright (GitHub Action scraper), jq (JSON parsing in bash), curl (data fetching)

**Design doc:** `docs/plans/2026-03-10-cli-menu-branch-changelog-design.md`

---

## Task 1: Unified Box Rendering System

Refactor the hardcoded 38-char box rendering into shared primitives with dynamic width. This must come first because all subsequent tasks (menu, branch status, changelog display) depend on these primitives.

**Files:**
- Modify: `update-beeper:7` (SCRIPT_VERSION bump)
- Modify: `update-beeper:271-329` (replace pad_row + summary_box)
- Modify: `update-beeper:1663-1676` (dry-run box)

**Step 1: Add BOX_WIDTH computation after color definitions (line ~69)**

Insert after `NC='\033[0m'` (line 69):

```bash
# ── Dynamic Box Width ────────────────────────────────────────────────────
# Responsive to terminal size, clamped between 36-56 inner chars
BOX_WIDTH=$(( $(tput cols 2>/dev/null || echo 80) - 6 ))
(( BOX_WIDTH > 56 )) && BOX_WIDTH=56
(( BOX_WIDTH < 36 )) && BOX_WIDTH=36
```

**Step 2: Replace pad_row() and add box primitives (lines 271-282)**

Replace the existing `pad_row()` function and add the full box primitive set:

```bash
#──────────────────────────────────────────────────────────────────────────────
# BOX RENDERING PRIMITIVES
#──────────────────────────────────────────────────────────────────────────────

# Strip ANSI escape codes to get visible character count
strip_ansi() {
    echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

# Top border: ╭──── [optional title] ─╮
box_top() {
    local title="$1"
    if [[ -n "$title" ]]; then
        local visible
        visible=$(strip_ansi "$title")
        local title_len=${#visible}
        local bar_len=$(( BOX_WIDTH - title_len - 3 ))
        (( bar_len < 1 )) && bar_len=1
        log "  ${INFO}╭─$(printf '─%.0s' $(seq 1 $bar_len)) ${NC}${title}${INFO} ─╮${NC}"
    else
        log "  ${INFO}╭$(printf '─%.0s' $(seq 1 $BOX_WIDTH))╮${NC}"
    fi
}

# Bottom border: ╰──────────────────╯
box_bottom() {
    log "  ${INFO}╰$(printf '─%.0s' $(seq 1 $BOX_WIDTH))╯${NC}"
}

# Content row: │ content      │  (ANSI-safe padding)
box_row() {
    local content="$1"
    local inner_width=$(( BOX_WIDTH - 2 ))  # subtract 2 for padding spaces
    local visible
    visible=$(strip_ansi "$content")
    local vlen=${#visible}
    local pad=$(( inner_width - vlen ))
    (( pad < 0 )) && pad=0
    log "  ${INFO}│${NC} ${content}$(printf '%*s' "$pad" '') ${INFO}│${NC}"
}

# Empty row: │               │
box_blank() {
    log "  ${INFO}│${NC}$(printf '%*s' $(( BOX_WIDTH - 0 )) '')${INFO}│${NC}"
}

# Separator: ├── label ──────┤  or  ├──────────────┤
box_sep() {
    local label="$1"
    if [[ -n "$label" ]]; then
        local label_len=${#label}
        local bar_len=$(( BOX_WIDTH - label_len - 4 ))
        (( bar_len < 1 )) && bar_len=1
        log "  ${INFO}├── ${DIM}${label}${NC}${INFO} $(printf '─%.0s' $(seq 1 $bar_len))┤${NC}"
    else
        log "  ${INFO}├$(printf '─%.0s' $(seq 1 $BOX_WIDTH))┤${NC}"
    fi
}

# Backward compat: pad_row is now an alias for box_row
pad_row() { box_row "$@"; }
```

**Step 3: Refactor summary_box() to use primitives (lines 284-329)**

Replace the summary_box function:

```bash
summary_box() {
    local status="$1"
    local elapsed=$((SECONDS - START_TIME))
    local duration
    if [[ $elapsed -ge 60 ]]; then
        duration="$((elapsed / 60))m $((elapsed % 60))s"
    else
        duration="${elapsed}s"
    fi

    log ""
    box_top

    if [[ "$status" == "success" ]]; then
        box_row "${OK}${BOLD}✓ Update complete${NC}"
    else
        box_row "${ERR}${BOLD}✗ Update failed${NC}"
    fi

    box_blank
    box_row "${ACCENT}Version${NC}   ${INSTALLED:-?} → ${LATEST}"
    box_row "${ACCENT}Method${NC}    ${UPDATE_METHOD:-Direct install}"
    box_row "${ACCENT}Duration${NC}  ${duration}"

    if [[ -n "$RETRIES_USED" ]]; then
        box_row "${ACCENT}Retries${NC}   ${RETRIES_USED}"
    fi

    if [[ -n "$WAYLAND_DISPLAY" ]]; then
        box_row "${ACCENT}Wayland${NC}   Configured"
    fi

    if [[ -f "$USER_DESKTOP_FILE" ]]; then
        box_row "${ACCENT}Desktop${NC}   $(basename "$USER_DESKTOP_FILE")"
    fi

    if [[ "$status" == "failure" && -n "$2" ]]; then
        box_row "${ACCENT}Action${NC}    $2"
    fi

    box_bottom
    log ""
}
```

**Step 4: Refactor dry-run box (lines 1661-1676)**

Replace the dry-run hardcoded box with primitives:

```bash
if [[ "$DRY_RUN" == true ]]; then
    log ""
    box_top
    box_row "${ACCENT}${BOLD}Dry run${NC} — no changes"
    box_blank
    box_row "${ACCENT}Version${NC}   ${INSTALLED:-unknown} → $LATEST"
    if [[ "$AUR" != "unknown" ]] && version_gte "$AUR" "$LATEST"; then
        box_row "${ACCENT}Method${NC}    AUR (yay)"
    elif [[ "$AUR" != "unknown" ]]; then
        box_row "${ACCENT}Method${NC}    Direct install (AUR behind)"
    else
        box_row "${ACCENT}Method${NC}    Direct install"
    fi
    box_row "${ACCENT}Pacman${NC}    $(if [[ "$PACMAN_TRACKED" == true ]]; then echo "tracked"; else echo "untracked"; fi)"
    box_row "${ACCENT}Backup${NC}    $BACKUP_DIR"
    box_bottom
    log ""
    hint "Run without --dry-run to perform the update."
    log_event "DRY_RUN from=${INSTALLED:-unknown} to=$LATEST"
    exit 0
fi
```

**Step 5: Test box rendering**

```bash
# Test at different terminal widths
COLUMNS=40 bash -c 'source update-beeper; BOX_WIDTH=36; box_top "test"; box_row "hello world"; box_sep "section"; box_row "more content"; box_bottom'
COLUMNS=80 bash -c 'source update-beeper; BOX_WIDTH=56; box_top "test"; box_row "hello world"; box_sep "section"; box_row "more content"; box_bottom'

# Test existing functionality still works
./update-beeper --dry-run
./update-beeper --versions
```

Expected: Boxes render with consistent width, borders aligned, no ANSI artifacts.

**Step 6: Commit**

```bash
git add update-beeper
git commit -m "refactor: unified box rendering system with dynamic width

Replace hardcoded 38-char boxes with shared primitives (box_top, box_bottom,
box_row, box_blank, box_sep). BOX_WIDTH computed from terminal size (36-56).
Refactored summary_box and dry-run panel to use new primitives."
```

---

## Task 2: Branch System

Add persistent branch config, `--branch` flag, and dynamic URL construction.

**Files:**
- Modify: `update-beeper:9` (BEEPER_API becomes dynamic)
- Modify: `update-beeper:73-84` (add new flag variables)
- Modify: `update-beeper:89-117` (update usage)
- Modify: `update-beeper:124-142` (add --branch parsing)
- Modify: `update-beeper:462-518` (check_versions with branch-aware URL)
- Modify: `update-beeper:640-672` (show_versions enhanced for multi-branch)

**Step 1: Add branch config constants and reader (after line 32)**

Insert after `HISTORY_FILE=...` (line 32):

```bash
# Branch configuration
BRANCH_CONFIG_DIR="$HOME/.config/update-beeper"
BRANCH_CONFIG_FILE="$BRANCH_CONFIG_DIR/config"
BEEPER_API_TEMPLATE="https://api.beeper.com/desktop/download/linux/x64/%s/com.automattic.beeper.desktop"

read_config_branch() {
    if [[ -f "$BRANCH_CONFIG_FILE" ]]; then
        local branch
        branch=$(grep -oP '^BRANCH=\K\S+' "$BRANCH_CONFIG_FILE" 2>/dev/null)
        if [[ "$branch" =~ ^(stable|nightly|beta)$ ]]; then
            echo "$branch"
            return
        fi
    fi
    echo "stable"
}

write_config_branch() {
    mkdir -p "$BRANCH_CONFIG_DIR"
    echo "BRANCH=$1" > "$BRANCH_CONFIG_FILE"
}

ACTIVE_BRANCH=$(read_config_branch)
```

**Step 2: Replace hardcoded BEEPER_API (line 9)**

Change:
```bash
BEEPER_API="https://api.beeper.com/desktop/download/linux/x64/stable/com.automattic.beeper.desktop"
```
To:
```bash
# BEEPER_API is set dynamically after branch config is read (see read_config_branch)
```

Then after the `read_config_branch` block, add:
```bash
# Build API URL from active branch
BEEPER_API=$(printf "$BEEPER_API_TEMPLATE" "$ACTIVE_BRANCH")
```

**Step 3: Add new flag variables (after line 84)**

```bash
SHOW_WHATS_NEW=false
SHOW_MENU=false
SET_BRANCH=""
SHOW_BRANCH=false
```

**Step 4: Update usage() (lines 89-117)**

Add these lines in the Options section before the closing `exit 0`:

```bash
    echo "  --branch [NAME]   Set or show active branch (stable, nightly)"
    echo "  --whats-new, -w   Show changes since installed version"
    echo "  --menu, -m        Force interactive menu"
```

**Step 5: Add new flag parsing (in the case statement, lines 124-142)**

Add before the `*) echo "Unknown option..."` line:

```bash
        --branch)
            if [[ -n "${2:-}" ]] && [[ "$2" =~ ^(stable|nightly|beta)$ ]]; then
                SET_BRANCH="$2"; shift 2
            elif [[ -n "${2:-}" ]] && [[ "$2" != --* ]]; then
                echo "Unknown branch: $2 (valid: stable, nightly)"; exit 1
            else
                SHOW_BRANCH=true; shift
            fi
            ;;
        --whats-new|-w) SHOW_WHATS_NEW=true; shift ;;
        --menu|-m) SHOW_MENU=true; shift ;;
```

**Step 6: Add branch handling in early-exit section (after line 1575)**

Insert after the changelog early exit block:

```bash
# Handle branch set/show (early exit)
if [[ -n "$SET_BRANCH" ]]; then
    local old_branch="$ACTIVE_BRANCH"
    write_config_branch "$SET_BRANCH"
    ACTIVE_BRANCH="$SET_BRANCH"
    BEEPER_API=$(printf "$BEEPER_API_TEMPLATE" "$ACTIVE_BRANCH")
    print_header
    if [[ "$old_branch" == "$SET_BRANCH" ]]; then
        pass "Already on ${BOLD}${SET_BRANCH}${NC} branch"
    else
        pass "Switched from ${BOLD}${old_branch}${NC} to ${BOLD}${SET_BRANCH}${NC}"
    fi
    log ""
    exit 0
fi

if [[ "$SHOW_BRANCH" == true ]]; then
    echo "$ACTIVE_BRANCH"
    exit 0
fi
```

**Step 7: Enhance show_versions() for multi-branch (lines 640-672)**

Replace `show_versions()`:

```bash
show_versions() {
    check_versions

    print_header

    # Fetch branch data from beeper-intel (if available)
    local branch_data=""
    branch_data=$(fetch_cached_data "branch-versions" 2>/dev/null)

    log ""
    box_top "${ACTIVE_BRANCH}"
    box_row "${ACCENT}Active branch${NC}   ${BOLD}${ACTIVE_BRANCH}${NC}"
    box_row "${ACCENT}Installed${NC}       ${BOLD}${INSTALLED:-unknown}${NC}"
    box_blank

    # Show current branch version from API
    box_row "${ACCENT}${ACTIVE_BRANCH}${NC}$(printf '%*s' $((14 - ${#ACTIVE_BRANCH})) '')${BOLD}${LATEST:-unknown}${NC}$(
        if [[ -n "$INSTALLED" && "$INSTALLED" != "unknown" && -n "$LATEST" && "$LATEST" != "unknown" ]]; then
            if version_gte "$INSTALLED" "$LATEST"; then
                echo -e "  ${OK}✓ up to date${NC}"
            else
                echo -e "  ${WARN}⬆ update available${NC}"
            fi
        fi
    )"

    # Show other branches from cached beeper-intel data
    if [[ -n "$branch_data" ]] && command -v jq &>/dev/null; then
        local other_branches=("stable" "nightly")
        for b in "${other_branches[@]}"; do
            [[ "$b" == "$ACTIVE_BRANCH" ]] && continue
            local bver
            bver=$(echo "$branch_data" | jq -r ".branches.${b}.version // \"unknown\"")
            [[ "$bver" == "null" || -z "$bver" ]] && continue
            box_row "${ACCENT}${b}${NC}$(printf '%*s' $((14 - ${#b})) '')${bver}$(
                if [[ -n "$INSTALLED" && "$INSTALLED" != "unknown" && "$bver" != "unknown" ]]; then
                    if version_gte "$INSTALLED" "$bver"; then
                        echo -e "  ${OK}✓ matches${NC}"
                    else
                        echo -e "  ${INFO}⬆ ahead${NC}"
                    fi
                fi
            )"
        done
    fi

    box_blank
    box_row "${ACCENT}AUR${NC}             ${INFO}${AUR:-unknown}${NC}"
    box_row "${ACCENT}Pacman${NC}          $(if [[ "$PACMAN_TRACKED" == true ]]; then echo -e "${OK}tracked${NC}"; else echo -e "${WARN}untracked${NC}"; fi)"
    box_bottom
    log ""

    exit 0
}
```

**Step 8: Update backup naming to include branch**

Find the backup directory creation (search for `BACKUP_DIR` usage near backup logic) and add branch suffix:

```bash
# In the backup logic, change the backup subdir naming to include branch:
local backup_subdir="beeper-backup-${INSTALLED}-${ACTIVE_BRANCH}"
```

**Step 9: Test branch system**

```bash
# Show current branch (default: stable)
./update-beeper --branch
# Expected: stable

# Switch to nightly
./update-beeper --branch nightly
# Expected: Switched from stable to nightly

# Verify config persisted
cat ~/.config/update-beeper/config
# Expected: BRANCH=nightly

# Check versions shows multi-branch
./update-beeper --versions
# Expected: Box with active branch, installed, stable + nightly versions

# Switch back
./update-beeper --branch stable

# Invalid branch
./update-beeper --branch canary
# Expected: "Unknown branch: canary (valid: stable, nightly)"
```

**Step 10: Commit**

```bash
git add update-beeper
git commit -m "feat: branch support — stable/nightly/beta channel switching

Add --branch flag to set/show active download channel. Branch persists
in ~/.config/update-beeper/config. Download URL dynamically constructed
from active branch. --versions enhanced to show multi-branch status."
```

---

## Task 3: Data Fetching & Caching Layer

Add functions to fetch JSON from beeper-intel raw GitHub URLs with local caching and TTL.

**Files:**
- Modify: `update-beeper` (add after branch config section, before check_versions)

**Step 1: Add cache constants and fetch functions**

Insert after the branch config code:

```bash
#──────────────────────────────────────────────────────────────────────────────
# DATA FETCHING & CACHING (beeper-intel)
#──────────────────────────────────────────────────────────────────────────────

INTEL_RAW_URL="https://raw.githubusercontent.com/robertogogoni/beeper-intel/main/data"
CACHE_DIR="$HOME/.cache/update-beeper"
CACHE_TTL_SECONDS=21600  # 6 hours

# Ensure cache directory exists
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Fetch data with local cache. Returns cached content if within TTL.
# Usage: fetch_cached_data "branch-versions"  →  prints JSON to stdout
fetch_cached_data() {
    local name="$1"
    local cache_file="$CACHE_DIR/${name}.json"
    local url="${INTEL_RAW_URL}/${name}.json"

    # Check cache freshness
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
        if (( cache_age < CACHE_TTL_SECONDS )); then
            cat "$cache_file"
            return 0
        fi
    fi

    # Fetch fresh data
    local data
    data=$(curl -sL -m 10 "$url" 2>/dev/null)
    if [[ -n "$data" ]] && echo "$data" | head -c1 | grep -q '{'; then
        echo "$data" > "$cache_file"
        echo "$data"
        return 0
    fi

    # Fallback to stale cache
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
        return 0
    fi

    return 1
}

# Get human-readable cache age for display
cache_age_display() {
    local name="$1"
    local cache_file="$CACHE_DIR/${name}.json"
    if [[ -f "$cache_file" ]]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
        if (( age < 60 )); then echo "just now"
        elif (( age < 3600 )); then echo "$((age / 60))m ago"
        elif (( age < 86400 )); then echo "$((age / 3600))h ago"
        else echo "$((age / 86400))d ago"
        fi
    else
        echo "never"
    fi
}
```

**Step 2: Test caching**

```bash
# First fetch (should hit network)
source <(grep -A50 'fetch_cached_data()' update-beeper | head -50)
fetch_cached_data "branch-versions" | head -5

# Second fetch within TTL (should be instant, from cache)
time fetch_cached_data "branch-versions" > /dev/null

# Check cache file exists
ls -la ~/.cache/update-beeper/branch-versions.json
```

Note: This will fail until beeper-intel has the actual `branch-versions.json` file. That's expected — Task 7 creates it.

**Step 3: Commit**

```bash
git add update-beeper
git commit -m "feat: add data fetching layer with 6h TTL cache

Fetch JSON from beeper-intel raw GitHub URLs. Cache locally in
~/.cache/update-beeper/ with 6-hour TTL. Falls back to stale cache
on network failure."
```

---

## Task 4: Changelog Display Functions

Add "What's new" (version diff) and enhanced "Show changelog" (full history in terminal).

**Files:**
- Modify: `update-beeper:430-460` (replace show_changelog)

**Step 1: Replace show_changelog() and add show_whats_new()**

Replace the existing `show_changelog()` (lines 430-460) with:

```bash
show_changelog() {
    local data
    data=$(fetch_cached_data "desktop-changelog" 2>/dev/null)

    if [[ -z "$data" ]] || ! command -v jq &>/dev/null; then
        # Fallback: open browser (original behavior)
        local version=""
        if [[ -f "$INSTALL_DIR/resources/app/package.json" ]]; then
            version=$(grep -oP '"version":\s*"\K[0-9]+\.[0-9]+\.[0-9]+' "$INSTALL_DIR/resources/app/package.json" | head -1)
        fi
        print_header
        log "  ${ACCENT}Changelog${NC}"
        log ""
        detail "Opening in browser..."
        if command -v xdg-open &>/dev/null; then
            xdg-open "$CHANGELOG_URL" 2>/dev/null &
        elif command -v open &>/dev/null; then
            open "$CHANGELOG_URL" 2>/dev/null &
        else
            warn "Could not open browser"
            detail "Visit: ${CHANGELOG_URL}"
        fi
        hint "Cached changelog data not available. Install jq for in-terminal display."
        return 0
    fi

    # Parse and display changelog entries
    local output=""
    local count
    count=$(echo "$data" | jq '.versions | length')

    print_header
    log "  ${ACCENT}${BOLD}Changelog${NC} — ${INFO}${count} versions${NC}  ${DIM}(checked $(cache_age_display "desktop-changelog"))${NC}"
    log ""

    local i=0
    while (( i < count )); do
        local ver date
        ver=$(echo "$data" | jq -r ".versions[$i].version")
        date=$(echo "$data" | jq -r ".versions[$i].date // \"\"")

        log "  ${BOLD}${ver}${NC}${date:+ ${DIM}(${date})${NC}}"

        # New features
        local feat_count
        feat_count=$(echo "$data" | jq ".versions[$i].new_features | length")
        local f=0
        while (( f < feat_count )); do
            local feat
            feat=$(echo "$data" | jq -r ".versions[$i].new_features[$f]")
            log "    ${OK}✨${NC} ${feat}"
            (( f++ ))
        done

        # Fixes
        local fix_count
        fix_count=$(echo "$data" | jq ".versions[$i].fixes | length")
        local x=0
        while (( x < fix_count )); do
            local fix
            fix=$(echo "$data" | jq -r ".versions[$i].fixes[$x]")
            log "    ${WARN}🐛${NC} ${fix}"
            (( x++ ))
        done

        log ""
        (( i++ ))
    done

    return 0
}

show_whats_new() {
    local installed=""
    if [[ -f "$INSTALL_DIR/resources/app/package.json" ]]; then
        installed=$(grep -oP '"version":\s*"\K[0-9]+\.[0-9]+\.[0-9]+' "$INSTALL_DIR/resources/app/package.json" | head -1)
    fi

    if [[ -z "$installed" ]]; then
        fail "Could not determine installed version"
        return 1
    fi

    # Try version-diffs first for precomputed delta
    local diffs
    diffs=$(fetch_cached_data "version-diffs" 2>/dev/null)

    # Also get branch data for latest version
    local branch_data latest_ver
    branch_data=$(fetch_cached_data "branch-versions" 2>/dev/null)
    if [[ -n "$branch_data" ]] && command -v jq &>/dev/null; then
        latest_ver=$(echo "$branch_data" | jq -r ".branches.${ACTIVE_BRANCH}.version // \"unknown\"")
    fi
    [[ -z "$latest_ver" || "$latest_ver" == "null" ]] && latest_ver="unknown"

    print_header

    if version_gte "$installed" "${latest_ver:-0}"; then
        log ""
        box_top
        box_row "${OK}${BOLD}✓ You're up to date${NC}"
        box_blank
        box_row "${ACCENT}Installed${NC}   ${installed} (${ACTIVE_BRANCH})"
        box_row "${ACCENT}Latest${NC}      ${latest_ver}"
        box_bottom
        log ""
        return 0
    fi

    # Build "what's new" from changelog data
    local changelog
    changelog=$(fetch_cached_data "desktop-changelog" 2>/dev/null)

    log ""
    box_top "What's New"
    box_row "${ACCENT}You${NC}  ${installed} → ${ACCENT}Latest${NC}  ${BOLD}${latest_ver}${NC} (${ACTIVE_BRANCH})"
    box_blank

    if [[ -n "$changelog" ]] && command -v jq &>/dev/null; then
        local features=() fixes=() versions_spanned=0
        local count
        count=$(echo "$changelog" | jq '.versions | length')

        local i=0
        while (( i < count )); do
            local ver
            ver=$(echo "$changelog" | jq -r ".versions[$i].version" | sed 's/^v//')
            # Include versions newer than installed
            if [[ "$ver" != "$installed" ]] && ! version_gte "$installed" "$ver"; then
                (( versions_spanned++ ))

                local feat_count
                feat_count=$(echo "$changelog" | jq ".versions[$i].new_features | length")
                local f=0
                while (( f < feat_count )); do
                    features+=("$(echo "$changelog" | jq -r ".versions[$i].new_features[$f]")")
                    (( f++ ))
                done

                local fix_count
                fix_count=$(echo "$changelog" | jq ".versions[$i].fixes | length")
                local x=0
                while (( x < fix_count )); do
                    fixes+=("$(echo "$changelog" | jq -r ".versions[$i].fixes[$x]")")
                    (( x++ ))
                done
            fi
            # Stop once we pass our installed version
            if [[ "$ver" == "$installed" ]] || version_gte "$installed" "$ver"; then
                break
            fi
            (( i++ ))
        done

        if (( ${#features[@]} > 0 )); then
            box_sep "New Features"
            for feat in "${features[@]}"; do
                box_row "  ${OK}✨${NC} ${feat}"
            done
        fi

        if (( ${#fixes[@]} > 0 )); then
            box_sep "Fixes"
            for fix in "${fixes[@]}"; do
                box_row "  ${WARN}🐛${NC} ${fix}"
            done
        fi

        if (( versions_spanned > 1 )); then
            box_blank
            box_row "${DIM}Spans ${versions_spanned} versions${NC}"
        fi
    else
        box_row "${INFO}Changelog data not available${NC}"
        box_row "${INFO}Install jq and wait for beeper-intel refresh${NC}"
    fi

    box_bottom
    log ""
    return 0
}
```

**Step 2: Add --whats-new early exit handler (after changelog early exit)**

```bash
# Handle what's new display (early exit)
if [[ "$SHOW_WHATS_NEW" == true ]]; then
    show_whats_new
    exit $?
fi
```

**Step 3: Test changelog display**

```bash
# With jq installed and beeper-intel data available:
./update-beeper --changelog
# Expected: In-terminal formatted changelog with versions, features, fixes

# Without jq:
./update-beeper --changelog
# Expected: Falls back to opening browser

# What's new:
./update-beeper --whats-new
# Expected: Version diff box showing changes since installed version
```

**Step 4: Commit**

```bash
git add update-beeper
git commit -m "feat: in-terminal changelog and what's-new display

Replace browser-opening changelog with jq-parsed in-terminal display.
Add --whats-new flag showing version diff between installed and latest.
Falls back to browser when jq unavailable or cache empty."
```

---

## Task 5: Interactive Menu — Pure Bash Backend

Build the pure bash arrow-key selector first (the universal fallback), then layer other backends on top.

**Files:**
- Modify: `update-beeper` (add menu system after box primitives, before check_versions)

**Step 1: Add menu item definitions**

```bash
#──────────────────────────────────────────────────────────────────────────────
# INTERACTIVE MENU SYSTEM
#──────────────────────────────────────────────────────────────────────────────

# Menu items: key|display_name|description|group
MENU_ITEMS=(
    "update|Update Beeper|Install latest from current branch|Actions"
    "switch-branch|Switch branch|Change between stable and nightly|Actions"
    "rollback|Rollback|Restore previous backup|Actions"
    "dry-run|Dry run|Preview update without changes|Actions"
    "check|Check for updates|Compare installed vs latest|Information"
    "branch-status|Branch status|Versions across all branches|Information"
    "whats-new|What's new|Changes since installed version|Information"
    "changelog|Show changelog|Full version history|Information"
    "history|Show update history|Past update log|Information"
    "desktop|Validate desktop|Check shortcut, icon, desktop entry|Maintenance"
    "help|Help|Show all flags and usage|"
    "exit|Exit||"
)
```

**Step 2: Add pure bash selector**

```bash
# Pure bash arrow-key menu selector
# Returns selected key via stdout
menu_bash() {
    local items=("${MENU_ITEMS[@]}")
    local count=${#items[@]}
    local selected=0
    local current_group=""

    # Hide cursor
    printf '\033[?25l'
    # Restore cursor on exit
    trap 'printf "\033[?25l\033[?25h"' RETURN

    while true; do
        # Move cursor to top of menu area
        if [[ -n "$_menu_drawn" ]]; then
            # Move up to redraw
            local total_lines=$(( count + 10 ))  # items + separators + header/footer
            printf "\033[${total_lines}A"
        fi
        _menu_drawn=1

        # Header
        local branch_badge=""
        [[ "$ACTIVE_BRANCH" != "stable" ]] && branch_badge=" ${INFO}[${ACTIVE_BRANCH}]${NC}"
        echo -e ""
        echo -e "  ${PURPLE}${BOLD}🐝 Beeper Updater${NC} ${INFO}v${SCRIPT_VERSION}${NC}${branch_badge}"
        echo -e ""

        current_group=""
        local item_index=0
        local display_line=0

        for item in "${items[@]}"; do
            IFS='|' read -r key name desc group <<< "$item"

            # Group separator
            if [[ -n "$group" && "$group" != "$current_group" ]]; then
                current_group="$group"
                echo -e "  ${DIM}── ${current_group} ──${NC}"
            elif [[ -z "$group" && -n "$current_group" ]]; then
                current_group=""
                echo -e "  ${DIM}──${NC}"
            fi

            # Item (highlighted if selected)
            if (( item_index == selected )); then
                echo -e "  ${PURPLE}${BOLD}▸ ${name}${NC}"
            else
                echo -e "    ${name}"
            fi

            (( item_index++ ))
        done

        echo -e ""
        echo -e "  ${DIM}↑↓ navigate  Enter select  q quit${NC}"

        # Read keypress
        local key
        IFS= read -rsn1 key

        case "$key" in
            $'\x1b')  # Escape sequence
                read -rsn2 -t 0.1 key
                case "$key" in
                    '[A') (( selected > 0 )) && (( selected-- )) ;;          # Up
                    '[B') (( selected < count - 1 )) && (( selected++ )) ;;   # Down
                esac
                ;;
            '')  # Enter
                IFS='|' read -r selected_key _ _ _ <<< "${items[$selected]}"
                printf '\033[?25h'  # Show cursor
                echo "$selected_key"
                return 0
                ;;
            'q'|'Q')
                printf '\033[?25h'
                echo "exit"
                return 0
                ;;
            [0-9])
                # Number shortcuts: 1-9 map to items 0-8, 0 = last (exit)
                local num_target
                if [[ "$key" == "0" ]]; then
                    num_target=$(( count - 1 ))
                else
                    num_target=$(( key - 1 ))
                fi
                if (( num_target >= 0 && num_target < count )); then
                    selected=$num_target
                    IFS='|' read -r selected_key _ _ _ <<< "${items[$selected]}"
                    printf '\033[?25h'
                    echo "$selected_key"
                    return 0
                fi
                ;;
        esac
    done
}
```

**Step 3: Test pure bash menu**

```bash
# Source the menu functions and test
bash -c '
source update-beeper
ACTIVE_BRANCH=stable
SCRIPT_VERSION=1.9.0
result=$(menu_bash)
echo "Selected: $result"
'
```

Expected: Arrow keys navigate, Enter selects, q exits, numbers work as shortcuts.

**Step 4: Commit**

```bash
git add update-beeper
git commit -m "feat: pure bash interactive menu with arrow-key navigation

Add menu_bash() selector using ANSI escape sequences and read -rsn1.
Supports arrow keys, Enter, number shortcuts, and q to quit.
Zero external dependencies."
```

---

## Task 6: Interactive Menu — fzf, dialog, whiptail Backends + Dispatcher

Add the three enhanced backends and the main show_menu() dispatcher with TTY detection.

**Files:**
- Modify: `update-beeper` (add after menu_bash, before check_versions)
- Modify: `update-beeper:124-142` (add TTY detection after flag parsing)

**Step 1: Add fzf backend**

```bash
menu_fzf() {
    local items=("${MENU_ITEMS[@]}")
    local current_group=""
    local fzf_input=""

    for item in "${items[@]}"; do
        IFS='|' read -r key name desc group <<< "$item"

        # Group separator (non-selectable)
        if [[ -n "$group" && "$group" != "$current_group" ]]; then
            current_group="$group"
            fzf_input+="── ${current_group} ──\n"
        elif [[ -z "$group" && -n "$current_group" ]]; then
            current_group=""
            fzf_input+="──\n"
        fi

        if [[ -n "$desc" ]]; then
            fzf_input+="${key}|  ${name}  ·  ${desc}\n"
        else
            fzf_input+="${key}|  ${name}\n"
        fi
    done

    local branch_badge=""
    [[ "$ACTIVE_BRANCH" != "stable" ]] && branch_badge=" [$ACTIVE_BRANCH]"

    local result
    result=$(echo -e "$fzf_input" | grep -v '^──' | fzf \
        --height=~20 \
        --layout=reverse \
        --border=rounded \
        --prompt="  " \
        --header="🐝 Beeper Updater v${SCRIPT_VERSION}${branch_badge}" \
        --header-first \
        --delimiter='|' \
        --with-nth=2 \
        --ansi \
        --no-info \
        --color="header:#6953f2,pointer:#6953f2,marker:#50c878,prompt:#a08cff" \
        2>/dev/null)

    if [[ -n "$result" ]]; then
        echo "$result" | cut -d'|' -f1
    else
        echo "exit"
    fi
}
```

**Step 2: Add dialog backend**

```bash
menu_dialog() {
    local items=("${MENU_ITEMS[@]}")
    local dialog_args=()
    local current_group=""

    for item in "${items[@]}"; do
        IFS='|' read -r key name desc group <<< "$item"

        # Group separator
        if [[ -n "$group" && "$group" != "$current_group" ]]; then
            current_group="$group"
            dialog_args+=("" "── ${current_group} ──")
        elif [[ -z "$group" && -n "$current_group" ]]; then
            current_group=""
            dialog_args+=("" "──")
        fi

        dialog_args+=("$key" "${name}${desc:+ — ${desc}}")
    done

    local branch_badge=""
    [[ "$ACTIVE_BRANCH" != "stable" ]] && branch_badge=" [$ACTIVE_BRANCH]"

    local result
    result=$(dialog \
        --title "Beeper Updater v${SCRIPT_VERSION}${branch_badge}" \
        --menu "Select an action:" \
        20 60 12 \
        "${dialog_args[@]}" \
        2>&1 >/dev/tty)

    if [[ -n "$result" ]]; then
        echo "$result"
    else
        echo "exit"
    fi
}
```

**Step 3: Add whiptail backend**

```bash
menu_whiptail() {
    local items=("${MENU_ITEMS[@]}")
    local wt_args=()
    local current_group=""

    for item in "${items[@]}"; do
        IFS='|' read -r key name desc group <<< "$item"

        if [[ -n "$group" && "$group" != "$current_group" ]]; then
            current_group="$group"
            wt_args+=("" "── ${current_group} ──")
        elif [[ -z "$group" && -n "$current_group" ]]; then
            current_group=""
            wt_args+=("" "──")
        fi

        wt_args+=("$key" "${name}${desc:+ — ${desc}}")
    done

    local branch_badge=""
    [[ "$ACTIVE_BRANCH" != "stable" ]] && branch_badge=" [$ACTIVE_BRANCH]"

    local result
    result=$(whiptail \
        --title "Beeper Updater v${SCRIPT_VERSION}${branch_badge}" \
        --menu "Select an action:" \
        20 60 12 \
        "${wt_args[@]}" \
        3>&1 1>&2 2>&3)

    if [[ -n "$result" ]]; then
        echo "$result"
    else
        echo "exit"
    fi
}
```

**Step 4: Add show_menu() dispatcher and switch_branch_menu()**

```bash
# Detect best available menu backend
detect_menu_backend() {
    if command -v fzf &>/dev/null; then echo "fzf"
    elif command -v dialog &>/dev/null; then echo "dialog"
    elif command -v whiptail &>/dev/null; then echo "whiptail"
    else echo "bash"
    fi
}

# Sub-menu for branch switching
switch_branch_menu() {
    local current="$ACTIVE_BRANCH"
    local branches=("stable" "nightly")
    local descs=("Production releases" "Pre-release fixes (~2 months ahead)")

    print_header
    log "  ${ACCENT}Current branch:${NC} ${BOLD}${current}${NC}"
    log ""

    local i=0
    for b in "${branches[@]}"; do
        (( i++ ))
        if [[ "$b" == "$current" ]]; then
            log "  ${PURPLE}${BOLD}${i}) ${b}${NC}  ${DIM}(current)${NC}  ${INFO}${descs[$((i-1))]}${NC}"
        else
            log "    ${i}) ${b}  ${INFO}${descs[$((i-1))]}${NC}"
        fi
    done

    log ""
    printf "  Select branch [1-${#branches[@]}, Enter to cancel]: "
    local choice
    read -r choice

    case "$choice" in
        1) write_config_branch "stable"; ACTIVE_BRANCH="stable"
           BEEPER_API=$(printf "$BEEPER_API_TEMPLATE" "$ACTIVE_BRANCH")
           [[ "$current" != "stable" ]] && pass "Switched to ${BOLD}stable${NC}" || pass "Already on ${BOLD}stable${NC}" ;;
        2) write_config_branch "nightly"; ACTIVE_BRANCH="nightly"
           BEEPER_API=$(printf "$BEEPER_API_TEMPLATE" "$ACTIVE_BRANCH")
           [[ "$current" != "nightly" ]] && pass "Switched to ${BOLD}nightly${NC}" || pass "Already on ${BOLD}nightly${NC}" ;;
        *) detail "Cancelled" ;;
    esac
    log ""
}

# Main menu loop
show_menu() {
    local backend
    backend=$(detect_menu_backend)

    while true; do
        local selected
        case "$backend" in
            fzf)      selected=$(menu_fzf) ;;
            dialog)   selected=$(menu_dialog) ;;
            whiptail) selected=$(menu_whiptail) ;;
            bash)     selected=$(menu_bash) ;;
        esac

        case "$selected" in
            update)        return 0 ;;  # Continue to main update flow
            switch-branch) switch_branch_menu; continue ;;
            rollback)      DO_ROLLBACK=true; return 0 ;;
            dry-run)       DRY_RUN=true; return 0 ;;
            check)         CHECK_ONLY=true; return 0 ;;
            branch-status) SHOW_VERSIONS=true; return 0 ;;
            whats-new)     SHOW_WHATS_NEW=true; return 0 ;;
            changelog)     SHOW_CHANGELOG=true; return 0 ;;
            history)       cat "$HISTORY_FILE" 2>/dev/null || echo "No update history yet."; continue ;;
            desktop)       CHECK_DESKTOP=true; return 0 ;;
            help)          usage ;;
            exit|"")       exit 0 ;;
        esac
    done
}
```

**Step 5: Add TTY detection and menu trigger (after flag parsing, line ~142)**

Insert after the `done` of the while loop (line 142):

```bash
# Interactive menu: show when no flags passed and running in a TTY
_any_flag_set=false
$CHECK_ONLY || $NOTIFY || $FORCE || $SHOW_CHANGELOG || $QUIET || \
$DO_ROLLBACK || $SHOW_VERSIONS || $SKIP_CHECKSUM || $DRY_RUN || \
$CHECK_DESKTOP || $SHOW_WHATS_NEW || $SHOW_BRANCH || \
[[ -n "$SET_BRANCH" ]] && _any_flag_set=true

if [[ "$SHOW_MENU" == true ]] || { [[ "$_any_flag_set" == false ]] && [[ -t 0 ]]; }; then
    show_menu
fi
```

**Step 6: Test all backends**

```bash
# Test fzf backend (if installed)
./update-beeper --menu

# Force pure bash by hiding fzf
PATH_BACKUP="$PATH"
PATH=$(echo "$PATH" | tr ':' '\n' | grep -v fzf | tr '\n' ':')
./update-beeper --menu
PATH="$PATH_BACKUP"

# Test non-interactive (should NOT show menu)
echo "" | ./update-beeper --check
```

**Step 7: Commit**

```bash
git add update-beeper
git commit -m "feat: interactive menu with fzf/dialog/whiptail/bash backends

Add show_menu() dispatcher with progressive backend detection.
fzf backend with fuzzy search, dialog/whiptail with TUI menus,
pure bash with arrow-key navigation. TTY detection triggers menu
when no flags passed. --menu flag forces menu in any context."
```

---

## Task 7: beeper-intel GitHub Action — Version Polling + Playwright Changelog Scraper

Create the automated data pipeline in the beeper-intel repo.

**Files:**
- Create: `~/repos/beeper-intel/scripts/scrape-changelog.js`
- Create: `~/repos/beeper-intel/scripts/poll-versions.sh`
- Create: `~/repos/beeper-intel/data/branch-versions.json` (seed)
- Create: `~/repos/beeper-intel/data/version-diffs.json` (seed)
- Modify: `~/repos/beeper-intel/.github/workflows/update-data.yml`
- Modify: `~/repos/beeper-intel/data/desktop-changelog.json` (schema update)

**Step 1: Create version polling script**

File: `scripts/poll-versions.sh`

```bash
#!/bin/bash
# Poll all Beeper download channels for current versions
set -e

API_TEMPLATE="https://api.beeper.com/desktop/download/linux/x64/%s/com.automattic.beeper.desktop"
OUTPUT_FILE="${1:-data/branch-versions.json}"

get_branch_version() {
    local branch="$1"
    local url
    url=$(printf "$API_TEMPLATE" "$branch")
    local response
    response=$(curl -Ls -m 15 -o /dev/null -w "%{url_effective}" "$url" 2>/dev/null)

    local version filename
    filename=$(basename "$response")
    version=$(echo "$filename" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    echo "{\"version\":\"${version:-unknown}\",\"filename\":\"${filename}\"}"
}

echo "Polling branch versions..."

stable=$(get_branch_version "stable")
nightly=$(get_branch_version "nightly")
beta=$(get_branch_version "beta")

today=$(date -u +%Y-%m-%d)
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read existing history (if any)
existing_history="[]"
if [[ -f "$OUTPUT_FILE" ]]; then
    existing_history=$(jq '.history // []' "$OUTPUT_FILE")
fi

# Build new history entry
stable_ver=$(echo "$stable" | jq -r '.version')
nightly_ver=$(echo "$nightly" | jq -r '.version')
beta_ver=$(echo "$beta" | jq -r '.version')

new_entry="{\"date\":\"${today}\",\"stable\":\"${stable_ver}\",\"nightly\":\"${nightly_ver}\",\"beta\":\"${beta_ver}\"}"

# Append to history (deduplicate by date)
updated_history=$(echo "$existing_history" | jq --argjson entry "$new_entry" \
    '[.[] | select(.date != $entry.date)] + [$entry] | sort_by(.date) | reverse | .[0:90]')

# Write output
jq -n \
    --arg now "$now" \
    --argjson stable "$stable" \
    --argjson nightly "$nightly" \
    --argjson beta "$beta" \
    --argjson history "$updated_history" \
    '{
        last_checked: $now,
        branches: { stable: $stable, nightly: $nightly, beta: $beta },
        history: $history
    }' > "$OUTPUT_FILE"

echo "Stable: $stable_ver | Nightly: $nightly_ver | Beta: $beta_ver"
echo "Written to $OUTPUT_FILE"
```

**Step 2: Create Playwright changelog scraper**

File: `scripts/scrape-changelog.js`

```javascript
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const CHANGELOG_URL = 'https://www.beeper.com/changelog/desktop';
const OUTPUT_FILE = process.argv[2] || 'data/desktop-changelog.json';

async function scrapeChangelog() {
    console.log('Launching browser...');
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();

    console.log(`Navigating to ${CHANGELOG_URL}...`);
    await page.goto(CHANGELOG_URL, { waitUntil: 'networkidle', timeout: 30000 });

    // Wait for changelog content to render
    await page.waitForTimeout(3000);

    // Scroll to load all entries (lazy-loaded SPA)
    let previousHeight = 0;
    for (let i = 0; i < 10; i++) {
        await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
        await page.waitForTimeout(1000);
        const currentHeight = await page.evaluate(() => document.body.scrollHeight);
        if (currentHeight === previousHeight) break;
        previousHeight = currentHeight;
    }

    // Extract changelog entries from the DOM
    // The exact selectors depend on Beeper's current DOM structure
    // This uses a flexible approach that looks for version patterns
    const entries = await page.evaluate(() => {
        const results = [];
        // Look for headings or sections containing version numbers
        const allElements = document.querySelectorAll('h1, h2, h3, h4, [class*="version"], [class*="changelog"], [class*="release"]');

        let currentEntry = null;

        document.querySelectorAll('*').forEach(el => {
            const text = el.textContent.trim();

            // Match version headers like "v4.2.630" or "4.2.630"
            const versionMatch = text.match(/^v?(\d+\.\d+\.\d+)$/);
            if (versionMatch && el.tagName.match(/^H[1-4]$/)) {
                if (currentEntry) results.push(currentEntry);
                currentEntry = {
                    version: 'v' + versionMatch[1],
                    date: '',
                    new_features: [],
                    fixes: []
                };
                return;
            }

            // Match dates near version headers
            if (currentEntry && !currentEntry.date) {
                const dateMatch = text.match(/(\w+ \d+,?\s*\d{4}|\d{4}-\d{2}-\d{2})/);
                if (dateMatch) {
                    currentEntry.date = dateMatch[1];
                }
            }

            // Collect list items as features or fixes
            if (currentEntry && el.tagName === 'LI') {
                const itemText = el.textContent.trim();
                if (itemText.toLowerCase().match(/fix|bug|crash|issue|broken|resolve/)) {
                    currentEntry.fixes.push(itemText);
                } else {
                    currentEntry.new_features.push(itemText);
                }
            }
        });

        if (currentEntry) results.push(currentEntry);
        return results;
    });

    await browser.close();

    // Merge with existing data
    let existing = { source: 'beeper.com/changelog/desktop', versions: [] };
    if (fs.existsSync(OUTPUT_FILE)) {
        try {
            existing = JSON.parse(fs.readFileSync(OUTPUT_FILE, 'utf8'));
        } catch (e) {
            console.warn('Could not parse existing changelog, starting fresh');
        }
    }

    // Merge: keep existing entries, add new ones
    const existingVersions = new Set(existing.versions.map(v => v.version));
    let added = 0;
    for (const entry of entries) {
        if (!existingVersions.has(entry.version)) {
            existing.versions.push(entry);
            added++;
        }
    }

    // Sort by version (descending)
    existing.versions.sort((a, b) => {
        const va = a.version.replace('v', '').split('.').map(Number);
        const vb = b.version.replace('v', '').split('.').map(Number);
        for (let i = 0; i < 3; i++) {
            if (vb[i] !== va[i]) return vb[i] - va[i];
        }
        return 0;
    });

    existing.last_scraped = new Date().toISOString();
    existing.source = 'beeper.com/changelog/desktop (Playwright scrape)';

    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(existing, null, 2) + '\n');
    console.log(`Scraped ${entries.length} entries, added ${added} new. Total: ${existing.versions.length}`);
}

// Compute version diffs
function computeDiffs(changelogFile, outputFile) {
    const changelog = JSON.parse(fs.readFileSync(changelogFile, 'utf8'));
    const versions = changelog.versions;
    const diffs = [];

    for (let i = 0; i < versions.length - 1; i++) {
        const to = versions[i];
        const from = versions[i + 1];

        // Also compute cumulative diffs (from each version to latest)
        if (i > 0) {
            const cumulative = {
                from: from.version,
                to: versions[0].version,
                versions_spanned: i + 1,
                all_new_features: [],
                all_fixes: [],
                versions_included: []
            };
            for (let j = 0; j <= i; j++) {
                cumulative.all_new_features.push(...versions[j].new_features);
                cumulative.all_fixes.push(...versions[j].fixes);
                cumulative.versions_included.push(versions[j].version);
            }
            diffs.push(cumulative);
        }

        // Single-step diff
        diffs.push({
            from: from.version,
            to: to.version,
            versions_spanned: 1,
            all_new_features: to.new_features,
            all_fixes: to.fixes,
            versions_included: [to.version]
        });
    }

    const output = {
        generated_at: new Date().toISOString(),
        diffs
    };

    fs.writeFileSync(outputFile, JSON.stringify(output, null, 2) + '\n');
    console.log(`Computed ${diffs.length} diffs`);
}

scrapeChangelog()
    .then(() => computeDiffs(OUTPUT_FILE, 'data/version-diffs.json'))
    .catch(err => {
        console.error('Scrape failed:', err.message);
        process.exit(1);
    });
```

**Step 3: Create seed data files**

File: `data/branch-versions.json` (initial seed):

```json
{
  "last_checked": "2026-03-10T00:00:00Z",
  "branches": {
    "stable": { "version": "4.2.630", "filename": "Beeper-4.2.630-x86_64.AppImage" },
    "nightly": { "version": "4.2.632", "filename": "Beeper-Nightly-4.2.632-x86_64.AppImage" },
    "beta": { "version": "0.90.113", "filename": "BeeperNightly-0.90.113-linux-x64-ab95d01.AppImage" }
  },
  "history": [
    { "date": "2026-03-10", "stable": "4.2.630", "nightly": "4.2.632", "beta": "0.90.113" }
  ]
}
```

File: `data/version-diffs.json` (initial seed):

```json
{
  "generated_at": "2026-03-10T00:00:00Z",
  "diffs": []
}
```

**Step 4: Update desktop-changelog.json schema**

Ensure the existing file has a `versions` array wrapper. Read the current file and wrap if needed:

```json
{
  "source": "beeper.com/changelog/desktop (Playwright scrape)",
  "last_scraped": "2026-03-10T00:00:00Z",
  "versions": [
    {
      "version": "v4.2.630",
      "date": "2026-03-09",
      "new_features": ["Search bar in Settings window"],
      "fixes": ["Fixed iMessage reactions on macOS Tahoe and Sequoia", "Performance improvements for faster chat catchup", "Fixed missing names/avatars for participants"]
    }
  ]
}
```

**Step 5: Replace the placeholder GitHub Action**

File: `.github/workflows/update-data.yml`

```yaml
name: Update Intelligence Data

on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 06:00 UTC
  workflow_dispatch:

jobs:
  update-versions:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install jq
        run: sudo apt-get install -y jq

      - name: Poll branch versions
        run: |
          chmod +x scripts/poll-versions.sh
          bash scripts/poll-versions.sh data/branch-versions.json

      - name: Install Playwright
        run: |
          npm init -y
          npm install playwright
          npx playwright install chromium
        working-directory: scripts

      - name: Scrape changelog
        run: node scripts/scrape-changelog.js
        timeout-minutes: 5
        continue-on-error: true

      - name: Cleanup node artifacts
        run: rm -rf scripts/node_modules scripts/package.json scripts/package-lock.json

      - name: Check for changes
        id: changes
        run: |
          git diff --quiet data/ && echo "changed=false" >> $GITHUB_OUTPUT || echo "changed=true" >> $GITHUB_OUTPUT

      - name: Commit and push
        if: steps.changes.outputs.changed == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add data/
          git commit -m "data: update branch versions and changelog [skip ci]"
          git push
```

**Step 6: Make poll script executable and test locally**

```bash
cd ~/repos/beeper-intel
chmod +x scripts/poll-versions.sh
bash scripts/poll-versions.sh data/branch-versions.json
cat data/branch-versions.json | jq .
```

**Step 7: Commit beeper-intel changes**

```bash
cd ~/repos/beeper-intel
git add scripts/ data/branch-versions.json data/version-diffs.json .github/workflows/update-data.yml
git commit -m "feat: automated version polling and changelog scraping pipeline

Add daily GitHub Action that polls stable/nightly/beta branch versions
and scrapes beeper.com/changelog/desktop with Playwright. Produces
branch-versions.json, updates desktop-changelog.json, and computes
version-diffs.json. Seed data included."
```

**Step 8: Push and trigger workflow**

```bash
git push
# Manually trigger to test
gh workflow run update-data.yml -R robertogogoni/beeper-intel
```

---

## Task 8: Version Bump, README Update, Final Integration

Bump version to 1.9.0, update README with new flags and menu documentation, push both repos.

**Files:**
- Modify: `~/repos/update-beeper/update-beeper:7` (version bump)
- Modify: `~/repos/update-beeper/README.md` (new flags, menu docs)
- Modify: `~/repos/update-beeper/CHANGELOG.md` (v1.9.0 entry)

**Step 1: Bump version**

Change line 7:
```bash
SCRIPT_VERSION="1.9.0"
```

**Step 2: Update README**

Add to the Options table:
```
  --branch [NAME]   Set or show active branch (stable, nightly)
  --whats-new, -w   Show changes since installed version
  --menu, -m        Force interactive menu
```

Add a new "Interactive Menu" section describing the TTY-triggered menu, backend chain, and branch switching.

**Step 3: Add CHANGELOG entry**

```markdown
## [1.9.0] - 2026-03-10

### Added
- Interactive CLI menu with progressive backend detection (fzf → dialog → whiptail → pure bash)
- Branch support: switch between stable and nightly channels (`--branch`)
- In-terminal changelog display with version diffs (`--whats-new`)
- Unified box rendering system with dynamic terminal-width adaptation
- Data fetching from beeper-intel with 6-hour local cache
- beeper-intel GitHub Action for automated version polling and changelog scraping

### Changed
- `--changelog` now shows formatted changelog in terminal (falls back to browser)
- `--versions` now shows multi-branch status
- Running with no flags in TTY shows interactive menu (auto-update still works in cron/systemd)

### Technical
- Refactored summary_box and dry-run panel to shared box primitives
- Branch config persists in `~/.config/update-beeper/config`
- Cache stored in `~/.cache/update-beeper/`
```

**Step 4: Final commit and push**

```bash
cd ~/repos/update-beeper
git add update-beeper README.md CHANGELOG.md
git commit -m "release: v1.9.0 — interactive menu, branch support, changelog pipeline"
git push
```

---

## Execution Order Summary

| Task | Dependency | Description |
|------|-----------|-------------|
| 1 | None | Box rendering primitives |
| 2 | Task 1 | Branch system (config, flags, URLs) |
| 3 | None (parallel with 2) | Data fetching + caching layer |
| 4 | Tasks 1, 3 | Changelog display functions |
| 5 | Task 1 | Pure bash menu backend |
| 6 | Tasks 2, 4, 5 | All menu backends + dispatcher + TTY detection |
| 7 | None (parallel, different repo) | beeper-intel Action + scraper |
| 8 | Tasks 1-6 | Version bump, README, CHANGELOG, push |

Tasks 1+3 can run in parallel. Task 7 is independent (different repo). Tasks 5+2 can partially overlap.
