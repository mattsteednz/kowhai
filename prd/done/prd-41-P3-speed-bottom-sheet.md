# Playback Speed Bottom Sheet

**Product Requirements Document**

*AudioVault · June 2025*

---

## Overview

Replace the playback speed `AlertDialog` with a modal bottom sheet, matching the existing bookmarks and chapter list sheet pattern used elsewhere on the player screen.

---

## Problem

The current speed control opens as a centred `AlertDialog` with Cancel/Done buttons. This is inconsistent with the bookmarks sheet and chapter list, which both use `showModalBottomSheet` + `DraggableScrollableSheet`. The dialog also requires an explicit Cancel/Done decision — the bookmarks sheet applies changes immediately and dismisses on backdrop tap, which is faster and more natural for a single-value picker.

---

## Changes

### Replace `_showSpeedDialog()` with `_showSpeedSheet()`

Open a `showModalBottomSheet` (same call pattern as `_showBookmarksSheet` and `_showChapterList`) containing:

```
[drag handle]
Playback speed              ← sheet title

        1.25×               ← large current-speed label (headlineMedium, bold)

[────────●──────────────]   ← Slider (0.5×–3.0×, 0.05× steps)

[0.75×] [1.0×] [1.25×] [1.5×] [2.0×] [2.5×]   ← ChoiceChip quick-select row
```

#### Behaviour

- **Live-apply**: speed changes take effect immediately as the user drags the slider or taps a chip (call `_audioHandler.setSpeed(v)` on every change) — identical to the current dialog behaviour.
- **No Cancel/Done buttons**: dismissing the sheet (backdrop tap, drag-down, or system back) keeps whatever speed was last set. This matches how the bookmarks sheet works — there is no undo action.
- **State update**: when the sheet is dismissed, call `setState(() => _speed = currentSpeed)` so the bottom-row chip reflects the new value. Use the sheet's `WillPopScope` or the `showModalBottomSheet.then()` callback.

#### Visual spec

- Sheet structure: drag handle → title → speed label → slider → chip row. Use the same drag handle, title padding, and `DraggableScrollableSheet` wrapper as `_BookmarksSheet`.
- Since the content is fixed-height (no scrollable list), use a non-draggable sheet: set `isScrollControlled: true` on `showModalBottomSheet` and wrap content in a `Padding` inside a `Column` with `mainAxisSize: MainAxisSize.min` — no `DraggableScrollableSheet` needed.
- Chip row: reuse the existing `_commonSpeeds` list and `ChoiceChip` pattern from the current dialog.
- All colours use `colorScheme` tokens (no hardcoded hex).

### Update bottom-row chip

The speed chip in `_bottomRow()` currently calls `_showSpeedDialog()` — change to `_showSpeedSheet()`. No other changes to the chip widget.

---

## Out of scope

- Changes to the sleep timer or bookmarks controls
- Persisting speed per-book (speed remains a session-level setting)
- Changes to any screen other than the player screen

---

## Acceptance criteria

- [ ] Speed control opens as a bottom sheet (not an `AlertDialog`)
- [ ] Sheet contains: drag handle, "Playback speed" title, current speed label, slider (0.5×–3.0×, 0.05× steps), quick-select chips for 0.75×, 1.0×, 1.25×, 1.5×, 2.0×, 2.5×
- [ ] Slider and chip changes apply immediately to playback (no Done button required)
- [ ] Dismissing the sheet (backdrop tap, drag-down, back gesture) keeps the last-set speed
- [ ] Bottom-row speed chip updates to reflect the new speed after sheet dismissal
- [ ] Sheet visual style is consistent with the existing bookmarks and chapter list sheets (drag handle, title padding, colour tokens)
- [ ] No regressions to existing speed functionality (range, step size, display format)
