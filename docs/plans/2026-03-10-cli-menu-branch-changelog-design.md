# CLI Interactive Menu, Branch Support & Changelog Pipeline

**Goal:** Add an interactive menu that surfaces all existing flags, support stable/nightly/beta branches, and automate changelog collection from beeper-intel.

**Architecture:** TTY-detected menu with progressive backend enhancement (fzf → dialog → whiptail → pure bash). Branch selection stored in persistent config. Changelog data fetched from beeper-intel's GitHub-hosted JSON files, populated by a daily Playwright-based GitHub Action.

**Tech Stack:** Bash (menu + branch logic), Node.js/Playwright (changelog scraping in GitHub Actions), jq (JSON parsing), curl (data fetching)

---

## 1. Interactive Menu

### Trigger

When `update-beeper` runs with no flags in an interactive TTY (`[ -t 0 ]`), show the menu. Non-interactive contexts (systemd, cron, pipes) keep the current auto-update behavior. A `--menu` / `-m` flag forces the menu in any context.

### Backend Detection Chain

```
fzf → dialog → whiptail → pure bash
```

Detected once at startup via `command -v`. A single `show_menu()` function dispatches to the appropriate renderer. If a backend crashes mid-render, fall through to the next.

### Menu Layout

```
┌─ Beeper Updater v1.9.0 ──── [nightly] ─┐
│                                          │
│  ── Actions ──────────────────────────── │
│    Update Beeper                         │
│    Switch branch                         │
│    Rollback                              │
│    Dry run                               │
│                                          │
│  ── Information ─────────────────────── │
│    Check for updates                     │
│    Branch status                         │
│    What's new                            │
│    Show changelog                        │
│    Show update history                   │
│                                          │
│  ── Maintenance ─────────────────────── │
│    Validate desktop                      │
│                                          │
│  ─────────────────────────────────────── │
│    Help                                  │
│    Exit                                  │
└──────────────────────────────────────────┘
```

The `[nightly]` badge appears only when not on stable.

### Descriptions per Backend

| Backend | Descriptions | Groups | Input Method |
|---------|-------------|--------|--------------|
| fzf | Name + dim description | ANSI-colored separators (non-selectable) | Fuzzy search + arrow keys |
| dialog | Tag + description columns | Blank spacer rows | Arrow keys + Enter |
| whiptail | Tag + description columns | Blank spacer rows | Arrow keys + Enter |
| pure bash | Name only | Dim separator lines | Arrow keys + number shortcuts + Enter |

### Menu Items → Flag Mapping

| Menu Item | Maps To |
|-----------|---------|
| Update Beeper | Main update flow (default behavior) |
| Switch branch | Sub-menu: stable/nightly selection |
| Rollback | `DO_ROLLBACK=true` |
| Dry run | `DRY_RUN=true` |
| Check for updates | `CHECK_ONLY=true` |
| Branch status | `SHOW_VERSIONS=true` (enhanced) |
| What's new | `SHOW_WHATS_NEW=true` (new) |
| Show changelog | `SHOW_CHANGELOG=true` (enhanced) |
| Show update history | Print history file + exit |
| Validate desktop | `CHECK_DESKTOP=true` |
| Help | `usage()` |
| Exit | `exit 0` |

No new execution paths. The menu sets the same flag variables that CLI flags set.

### Pure Bash Arrow-Key Selector

Reads escape sequences with `read -rsn1`. Tracks selected index. Renders with ANSI reverse video for highlight. Supports:
- Arrow up/down to navigate
- Number keys 1-9, 0 as shortcuts
- Enter to select
- q or Ctrl+C to exit

~60 lines, zero dependencies.

---

## 2. Unified Box Rendering System

### Problem

Existing boxes hardcode 38-char inner width. The menu, branch status, changelog, and "what's new" boxes each need consistent rendering without copy-pasting magic numbers.

### Solution

Compute `BOX_WIDTH` once at startup. All box functions reference this single variable.

```bash
BOX_WIDTH=$(( $(tput cols 2>/dev/null || echo 80) - 6 ))
(( BOX_WIDTH > 56 )) && BOX_WIDTH=56
(( BOX_WIDTH < 36 )) && BOX_WIDTH=36
```

### Primitives

| Function | Renders | Unicode |
|----------|---------|---------|
| `box_top [title]` | Top border, optional right-aligned title | `╭──── [title] ─╮` |
| `box_bottom` | Bottom border | `╰──────────────╯` |
| `box_row "content"` | Padded row, ANSI-safe width calculation | `│ content      │` |
| `box_blank` | Empty row | `│               │` |
| `box_sep [label]` | Mid separator, optional label | `├── label ──────┤` |
| `box_header "text"` | Bold centered header row | `│   TEXT        │` |

### Migration

Existing `pad_row()` becomes a thin wrapper around `box_row()`. Existing `summary_box()` refactored to use `box_top`/`box_bottom`/`box_row`. Hardcoded border strings removed.

---

## 3. Branch System

### Config

Persistent branch stored in `~/.config/update-beeper/config`:

```bash
BRANCH=stable
```

Defaults to `stable` if file missing. Created on first branch switch.

### New Flags

| Flag | Description | Documented |
|------|-------------|-----------|
| `--branch stable` | Switch to stable channel | Yes |
| `--branch nightly` | Switch to nightly channel | Yes |
| `--branch beta` | Switch to beta channel | No (hidden) |
| `--branch` (no arg) | Show current branch | Yes |

### URL Construction

```bash
BRANCH=$(read_config_branch)  # defaults to "stable"
BEEPER_API="https://api.beeper.com/desktop/download/linux/x64/${BRANCH}/com.automattic.beeper.desktop"
```

Replaces the current hardcoded stable URL.

### Switch Branch Flow

In the menu, "Switch branch" shows a sub-selector with stable and nightly (not beta). On selection:
1. Write `BRANCH=<choice>` to config file
2. Print confirmation
3. Return to menu

### Safety Guards

| Guard | Behavior |
|-------|----------|
| Nightly → stable downgrade | Warn if installed version is newer than stable latest. Require `--force`. |
| Beta version mismatch | Warn if installed version matches `0.x.x` pattern (incompatible versioning). |
| Branch mismatch display | Menu header shows `[nightly]` or `[beta]` badge when not on stable. |

### Branch Status Display

```
╭─ Branch Status ─────────────────────────────────╮
│  Active branch:   nightly                        │
│  Installed:       4.2.630  (stable build)        │
│                                                   │
│  stable:          4.2.630  ✓ matches installed    │
│  nightly:         4.2.632  ⬆ 2 versions ahead    │
│                                                   │
│  Data from: beeper-intel (checked 2h ago)         │
╰──────────────────────────────────────────────────╯
```

Checks both stable and nightly regardless of active branch.

### Backup Naming

Includes branch: `beeper-backup-4.2.632-nightly/`

---

## 4. Changelog Pipeline (beeper-intel)

### GitHub Action

**File:** `.github/workflows/scrape-versions.yml` in beeper-intel repo

**Schedule:** Daily at 06:00 UTC

**Steps:**
1. Install Playwright chromium
2. Poll all 3 branch download URLs via `curl -ILs`, extract version from redirect filename
3. Render `beeper.com/changelog/desktop` with Playwright, wait for SPA content, scroll to load all entries
4. Extract structured changelog entries (version, date, features, fixes)
5. Merge new entries into existing JSON (append-only)
6. Compute version diffs between consecutive versions
7. Commit + push if data changed

### Data Files

**`data/branch-versions.json`** — live versions for all branches + daily history:
```json
{
  "last_checked": "2026-03-10T06:00:00Z",
  "branches": {
    "stable":  { "version": "4.2.630", "filename": "Beeper-4.2.630-x86_64.AppImage" },
    "nightly": { "version": "4.2.632", "filename": "Beeper-Nightly-4.2.632-x86_64.AppImage" },
    "beta":    { "version": "0.90.113", "filename": "BeeperNightly-0.90.113-linux-x64-ab95d01.AppImage" }
  },
  "history": [
    { "date": "2026-03-10", "stable": "4.2.630", "nightly": "4.2.632", "beta": "0.90.113" }
  ]
}
```

**`data/desktop-changelog.json`** — all scraped versions with features and fixes (expanded from current 4 versions to all available).

**`data/version-diffs.json`** — precomputed diffs between consecutive versions:
```json
{
  "diffs": [
    {
      "from": "4.2.605",
      "to": "4.2.630",
      "versions_spanned": 3,
      "all_new_features": ["Search bar in Settings", "..."],
      "all_fixes": ["iMessage reactions on macOS Tahoe", "..."],
      "versions_included": ["4.2.630", "4.2.620", "4.2.605"]
    }
  ]
}
```

### Scrape Script

**File:** `scripts/scrape-changelog.js` (Node.js, runs in Action only)

Uses Playwright to:
1. Navigate to changelog page
2. Wait for dynamic content render
3. Extract version entries from DOM
4. Return structured JSON

---

## 5. Changelog Display in update-beeper

### Data Source

Fetched from beeper-intel raw GitHub URL:
```
https://raw.githubusercontent.com/robertogogoni/beeper-intel/main/data/branch-versions.json
https://raw.githubusercontent.com/robertogogoni/beeper-intel/main/data/desktop-changelog.json
https://raw.githubusercontent.com/robertogogoni/beeper-intel/main/data/version-diffs.json
```

### Cache

Location: `~/.cache/update-beeper/`
- `branch-versions.json` — 6-hour TTL
- `desktop-changelog.json` — 6-hour TTL
- `version-diffs.json` — 6-hour TTL

Falls back to cached data on network failure. Falls back to "open browser" if cache empty and network down.

### "What's new" Display (`--whats-new` / `-w`)

Shows changes between installed version and latest on active branch:

```
╭─ What's New ────────────────────────────────────╮
│  You: 4.2.605 → Latest: 4.2.630 (stable)        │
│  2 versions ahead                                │
│                                                   │
│  ✨ New Features                                  │
│    • Search bar in Settings window                │
│    • Settings window redesigned                   │
│                                                   │
│  🐛 Fixes                                        │
│    • iMessage reactions on macOS Tahoe/Sequoia    │
│    • Faster chat catchup performance              │
│    • Missing names/avatars for participants       │
│                                                   │
│  Spans: v4.2.630, v4.2.620, v4.2.605             │
╰──────────────────────────────────────────────────╯
```

### "Show changelog" Display (`--changelog` / `-l`)

Full version history, piped through `less -R` when output exceeds terminal height:

```
v4.2.630 (2026-03-09)
  ✨ Search bar in Settings window
  🐛 iMessage reactions on macOS Tahoe and Sequoia
  🐛 Faster chat catchup

v4.2.605 (2026-03-03)
  ✨ Sidebar redesign (Space Bar)
  🐛 Message delivery reliability

v4.2.587 (2026-02-24)
  ...
```

Replaces the current browser-opening behavior. The browser fallback remains if JSON data is unavailable.

---

## 6. Complete Flag Map (v1.9.0)

| Flag | Short | Status | Description |
|------|-------|--------|-------------|
| `--check` | `-c` | Unchanged | Check for updates without installing |
| `--changelog` | `-l` | **Enhanced** | Show full changelog in terminal (was: open browser) |
| `--notify` | `-n` | Unchanged | Desktop notification for cron/timer |
| `--force` | `-f` | Unchanged | Force update even if on latest |
| `--quiet` | `-q` | Unchanged | Only output on errors |
| `--versions` | — | **Enhanced** | Show all branch versions (was: single branch) |
| `--skip-checksum` | — | Unchanged | Skip SHA256 verification |
| `--dry-run` | — | Unchanged | Preview without changes |
| `--history` | — | Unchanged | Show update history |
| `--check-desktop` | — | Unchanged | Validate desktop shortcut |
| `--rollback` | `-r` | Unchanged | Rollback to previous backup |
| `--version` | `-v` | Unchanged | Script version |
| `--help` | `-h` | Unchanged | Usage |
| `--branch [name]` | — | **New** | Set or show active branch |
| `--whats-new` | `-w` | **New** | Changes since installed version |
| `--menu` | `-m` | **New** | Force interactive menu |

---

## 7. What Does NOT Change

- systemd timers, cron jobs — non-TTY means auto-update as before
- All existing flags — same behavior (except `--changelog` and `--versions` enhanced)
- jarvis-beeper, beeper-health, beeper-version — unaffected
- Download, install, backup, rollback core logic — unchanged
- Lockfile, logging, self-healing retries — unchanged
- PKGBUILD dependencies — bash, curl, coreutils (no new required deps)
