# PRD-39 (P3): UX/UI polish pass — Library & Player screens

## Problem
After the PRD-36 library redesign and the chapter bookmarks feature (PRD-34), several small UX/UI inconsistencies and gaps remain across the Library and Player screens. Individually minor, together they add up to a less polished experience than competing audiobook apps.

## Evidence
- Grid cards show title only — no author, making visually similar books hard to distinguish
- Grid aspect ratio (0.68) leaves little room for a second text line
- No pull-to-refresh on the library list/grid despite it being a standard mobile pattern
- Filter pills show no counts, leading to dead-end taps on empty categories
- View toggle icon shows the *opposite* mode, which can confuse users reading it as current state (acknowledged pattern, but worth labelling)
- Search icon is disabled during scan even though books stream in incrementally
- Bookmarks chip on the Player screen has a dropdown arrow but opens a sheet, not a menu
- Player screen shows chapter-scoped progress but no overall book progress
- Chapter label tap target is just the text — too small on compact screens
- Speed chip shows "1.0×" at default instead of a descriptive label
- Sleep timer chip shows "Off" instead of a feature-name label when inactive

## Proposed Solution
Eleven targeted tweaks, each independently shippable, grouped into one PRD for tracking.

---

### Change 1 — Author line on grid cards
Add a single-line author subtitle below the title in `AudiobookCard`. Use `maxLines: 1`, ellipsis overflow, muted colour (`onSurface` at 0.65 alpha).

**Files:** `lib/widgets/audiobook_card.dart`

**Acceptance criteria:**
- [ ] Grid cards show author below title when `book.author` is non-null
- [ ] Author text is muted, single-line, ellipsized
- [ ] Cards without an author show title only (no blank gap)

---

### Change 2 — Adjust grid aspect ratio
Change `childAspectRatio` from `0.68` to `0.62` to accommodate the new author line without cramping the cover art.

**Files:** `lib/screens/library_screen.dart`

**Acceptance criteria:**
- [ ] Grid cards have enough vertical space for cover + title (2 lines) + author (1 line)
- [ ] Cover art is not noticeably smaller than before

---

### Change 3 — Pull-to-refresh on library
Wrap the grid and list views in a `RefreshIndicator` wired to `_scan()`.

**Files:** `lib/screens/library_screen.dart`

**Acceptance criteria:**
- [ ] Pulling down on the grid or list triggers a library rescan
- [ ] The refresh indicator shows while `_syncing` is true
- [ ] Works in both grid and list view modes

---

### Change 4 — Filter pill counts
Show the number of books matching each status in the filter sheet pills, e.g. "In progress (3)".

**Files:** `lib/screens/library_screen.dart`

**Acceptance criteria:**
- [ ] Each status pill in the filter sheet shows a count in parentheses
- [ ] The "All" pill shows the total unfiltered (but search-respecting) count
- [ ] Counts update live as the underlying data changes

---

### Change 5 — View toggle tooltip clarity
The toggle already shows the opposite icon (list icon in grid mode, grid icon in list mode). Add explicit tooltip text: "Switch to list view" / "Switch to grid view" to remove ambiguity.

**Files:** `lib/screens/library_screen.dart`

**Acceptance criteria:**
- [ ] Tooltip reads "Switch to list view" when in grid mode
- [ ] Tooltip reads "Switch to grid view" when in list mode

---

### Change 6 — Enable search during scan
Allow the search icon to be tapped as soon as `_books` is non-null (even if still scanning), rather than requiring `_books!.isNotEmpty`.

**Files:** `lib/screens/library_screen.dart`

**Acceptance criteria:**
- [ ] Search icon is enabled as soon as the first book appears during a scan
- [ ] Search still disabled when `_books` is null (initial load before any books)

---

### Change 7 — Remove dropdown arrow from Bookmarks chip
The Bookmarks chip on the Player screen opens a bottom sheet, not a dropdown menu. Remove the `Icons.arrow_drop_down` trailing icon from the Bookmarks chip only. Speed and Sleep timer chips keep theirs (they open menus).

**Files:** `lib/screens/player_screen.dart`

**Acceptance criteria:**
- [ ] Bookmarks chip has no dropdown arrow
- [ ] Speed and Sleep timer chips still show the dropdown arrow
- [ ] Bookmarks chip still opens the bookmarks sheet on tap

---

### Change 8 — Overall book progress on Player screen
Add a secondary label below the chapter-scoped time labels showing total book remaining time (e.g. "4h 12m remaining overall"). Reuse the same calculation already in `MiniPlayer._remaining()`.

**Files:** `lib/screens/player_screen.dart`

**Acceptance criteria:**
- [ ] A "Xh Ym remaining overall" label appears below the chapter progress timestamps
- [ ] Label uses muted styling (bodySmall, reduced alpha)
- [ ] Label updates in real-time as playback progresses
- [ ] Hidden when total duration is unknown

---

### Change 9 — Larger chapter label tap target
Wrap the chapter label `GestureDetector` in sufficient padding so the touch target meets the 48dp minimum recommended by Material guidelines.

**Files:** `lib/screens/player_screen.dart`

**Acceptance criteria:**
- [ ] Chapter label tap target is at least 48dp tall
- [ ] Visual appearance is unchanged (padding is transparent)
- [ ] Tapping still opens the chapter list sheet

---

### Change 10 — Speed chip label at default
When playback speed is 1.0×, show "Speed" instead of "1.0×". When speed is anything else, continue showing the numeric value (e.g. "1.5×").

**Files:** `lib/screens/player_screen.dart`

**Acceptance criteria:**
- [ ] Chip reads "Speed" when speed is 1.0×
- [ ] Chip reads the numeric value (e.g. "1.25×") when speed ≠ 1.0×
- [ ] The `active` highlight still triggers only when speed ≠ 1.0×

---

### Change 11 — Sleep timer chip label when inactive
When no sleep timer is set, show "Sleep" instead of "Off". When a timer is active, continue showing the countdown or "End of ch.".

**Files:** `lib/screens/player_screen.dart`

**Acceptance criteria:**
- [ ] Chip reads "Sleep" when no timer is active
- [ ] Chip reads the countdown (e.g. "28:45") or "End of ch." when active
- [ ] The `active` highlight still triggers only when a timer is set

---

## Out of Scope
- Placeholder colour palette changes (light-mode variant) — tracked separately
- Extracting duplicated `_EnrichmentAwareCover` — code hygiene, not UX
- Mini player chapter info — deferred to a future pass
- Any changes to screens other than Library and Player

## Implementation Plan
Each change is a separate commit on a dedicated branch. The branch naming convention is `ui/prd-39-{n}-short-name`. After `flutter test` and `flutter analyze` pass, commit and move to the next change.

1. `ui/prd-39-1-grid-author` — Change 1
2. `ui/prd-39-2-grid-aspect-ratio` — Change 2
3. `ui/prd-39-3-pull-to-refresh` — Change 3
4. `ui/prd-39-4-filter-pill-counts` — Change 4
5. `ui/prd-39-5-view-toggle-tooltip` — Change 5
6. `ui/prd-39-6-search-during-scan` — Change 6
7. `ui/prd-39-7-bookmarks-chip-arrow` — Change 7
8. `ui/prd-39-8-overall-book-progress` — Change 8
9. `ui/prd-39-9-chapter-tap-target` — Change 9
10. `ui/prd-39-10-speed-chip-label` — Change 10
11. `ui/prd-39-11-sleep-timer-label` — Change 11

## Files Impacted
- `lib/widgets/audiobook_card.dart`
- `lib/screens/library_screen.dart`
- `lib/screens/player_screen.dart`
