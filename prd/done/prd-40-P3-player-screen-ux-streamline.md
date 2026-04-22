# PRD-40 (P3): Player screen UX streamline

**Status:** Done
**Date:** 2025-04-22

## Problem
After adding chapter bookmarks (PRD-34), the player screen accumulated visual clutter and inconsistency:

1. **Title redundancy** — the book title appeared in both the AppBar and the info section below the cover, wasting vertical space.
2. **Flat info hierarchy** — title, author, narrator, and chapter label were stacked with only subtle opacity differences. The narrator line added noise without operational value during playback. The interactive chapter label didn't look tappable.
3. **Crowded bottom row** — three chips (Speed, Sleep Timer, Bookmarks) competed for horizontal space. Bookmarks is a navigation feature, not a quick-toggle setting like the other two.
4. **Inconsistent secondary UIs** — speed used an `AlertDialog`, sleep timer used a `PopupMenuButton`, bookmarks and chapters used `showModalBottomSheet`. Three different interaction patterns for conceptually similar controls.

## Changes Made

### 1. AppBar: removed title, added bookmarks icon
- Removed `title:` from the AppBar. The book title now appears once, prominently, below the cover art.
- Added a bookmark icon button (`bookmark_outline_rounded`) to the AppBar actions, before the info and cast icons. Tapping opens the existing bookmarks bottom sheet.

### 2. Info section: removed narrator, improved chapter label
- Removed the "Read by {narrator}" line. Narrator metadata remains available on the book details screen.
- Increased spacing before the chapter label (`SizedBox(height: 8)` vs previous `4`).
- Restyled the chapter label as a tappable pill/chip with a subtle primary-tinted background (`primary.withValues(alpha: 0.08)`) and rounded corners. Chapter title (when available) is now inline: "Ch. 3/12 · The Council" instead of stacked on two lines.

### 3. Bottom row: removed bookmarks chip
- Reduced from three chips to two: Speed and Sleep Timer.
- Added `Tooltip` and `Semantics` wrappers to the sleep timer chip (matching the speed chip's accessibility pattern).

### 4. Speed control: AlertDialog → bottom sheet
- Replaced `showDialog` with `showModalBottomSheet`. Same slider + preset chips layout, now with a drag handle and `Cancel`/`Done` buttons (Done uses `FilledButton` for visual weight).

### 5. Sleep timer: PopupMenuButton → bottom sheet
- Replaced the `PopupMenuButton` dropdown with `showModalBottomSheet` containing a `ListTile` list of timer options.
- Active option shows a check icon. "Custom…" option opens the existing stepper dialog from within the sheet context.
- The custom timer dialog now auto-dismisses the parent sheet on confirmation.

## Files Changed
- `lib/screens/player_screen.dart` — all changes in this single file

## Design Rationale
- **One title, one place:** follows the pattern of Spotify, Audible, and Apple Music where the AppBar is minimal and the title lives below the artwork.
- **Bookmarks in AppBar:** bookmarks is a "feature panel" (browse/add), not a quick-toggle like speed or sleep. AppBar actions are the standard home for feature entry points.
- **Bottom sheets everywhere:** standardising on sheets for all secondary controls gives users a single mental model — tap a chip or icon, sheet slides up, make a choice, sheet dismisses. Sheets also provide more room than dialogs or popup menus on mobile.
- **Chapter chip:** the pill background signals interactivity without being heavy. Inline chapter title reduces vertical space usage.

## Out of Scope
- Tabbed chapters/bookmarks sheet (considered but deferred — adds complexity for marginal gain).
- Bookmark ticks on the scrubber (deferred from PRD-34, still deferred).
