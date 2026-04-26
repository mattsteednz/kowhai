# Book Download Prompt Fixes — Bugfix Design

## Overview

Two related bugs affect the Drive book download/playback flow:

1. **WiFi file size missing** — `_showDriveDownloadSheet` in `library_screen.dart` only fetches `totalSizeBytes` when `!isWifi`. Removing that condition makes the size always available, so the prompt message and button label are consistently annotated regardless of connection type.

2. **"Start listening" bypasses download prompt** — The `FilledButton` in `_ActionButtonsState.build` in `book_details_screen.dart` unconditionally navigates to `PlayerScreen`. For Drive books that have not been downloaded, this opens the player with no audio files and playback fails silently. The button must check the download state first and show the download prompt when needed.

Fixing bug #2 requires the download-prompt logic (currently private to `_LibraryScreenState`) to be callable from `BookDetailsScreen`. The chosen approach is to extract `_showDriveDownloadSheet` into a top-level function in a new shared utility file `lib/utils/drive_download_sheet.dart`, which both screens can import.

---

## Glossary

- **Bug_Condition (C)**: The set of inputs that trigger a defect — either (a) a WiFi connection when the download prompt is shown, causing the size to be omitted, or (b) a "Start listening" tap on an undownloaded Drive book, causing unconditional navigation to the player.
- **Property (P)**: The desired correct behavior for inputs in C — (a) the prompt always shows the file size, and (b) the prompt is shown instead of navigating to the player.
- **Preservation**: Existing behaviors that must remain unchanged — mobile-data size display, direct navigation for downloaded/local books, and the "Download to device" button on the details screen.
- **`_showDriveDownloadSheet`**: The private method in `_LibraryScreenState` (`lib/screens/library_screen.dart`) that shows a bottom sheet prompting the user to download a Drive book. It fetches connectivity and optionally file size, then presents Cancel / Download actions.
- **`showDriveDownloadSheet`**: The extracted top-level function in `lib/utils/drive_download_sheet.dart` that replaces the private method and is callable from any screen.
- **`_ActionButtonsState`**: The stateful widget in `lib/screens/book_details_screen.dart` that renders the "Start listening", download-progress, and remove buttons for a book.
- **`fullyDownloaded`**: True when `book.source == AudiobookSource.drive && total > 0 && downloaded >= total`. Already computed in `_ActionButtonsState.build`.
- **`notDownloaded`**: True when `isDrive && !fullyDownloaded && !_isDownloading`. Already computed in `_ActionButtonsState.build`.

---

## Bug Details

### Bug Condition

**Bug A — WiFi file size missing**

The download prompt only fetches `totalSizeBytes` when the device is on mobile data. On WiFi the size is skipped, so the prompt shows a generic message and an unlabelled "Download" button even though the size is equally useful context.

```
FUNCTION isBugConditionA(input)
  INPUT: input = { connectivity: ConnectivityResult, book: Audiobook }
  OUTPUT: boolean

  RETURN book.source == AudiobookSource.drive
         AND book.audioFiles.isEmpty
         AND (input.connectivity == ConnectivityResult.wifi
              OR input.connectivity == ConnectivityResult.ethernet)
END FUNCTION
```

**Bug B — "Start listening" bypasses download prompt**

The "Start listening" `FilledButton` in `_ActionButtonsState.build` calls `Navigator.pushReplacement` unconditionally, regardless of whether the Drive book has been downloaded.

```
FUNCTION isBugConditionB(input)
  INPUT: input = { book: Audiobook, tapTarget: String }
  OUTPUT: boolean

  RETURN input.tapTarget == 'Start listening'
         AND input.book.source == AudiobookSource.drive
         AND input.book.audioFiles.isEmpty
         AND NOT isDownloading(input.book)
END FUNCTION
```

### Examples

**Bug A:**
- User on WiFi opens the download prompt for a 312 MB Drive book → prompt shows "This book hasn't been downloaded yet. Download it to start listening." and button reads "Download" (no size). **Expected:** prompt shows size and button reads "Download (312.0 MB)".

**Bug B:**
- User taps "Start listening" on a Drive book with 0 downloaded files → `PlayerScreen` opens with an empty playlist and no audio plays. **Expected:** the download prompt sheet appears.
- User taps "Start listening" on a fully downloaded Drive book → `PlayerScreen` opens normally. **Expected (preserved):** same — no change.
- User taps "Start listening" on a local book → `PlayerScreen` opens normally. **Expected (preserved):** same — no change.

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- When the device is on mobile data, the download prompt MUST continue to show the file size with the mobile-data warning message ("You're on mobile data. This book is X. Download anyway?").
- When the device is on mobile data, the Download button label MUST continue to include the formatted size ("Download (X)").
- Tapping "Start listening" for a fully downloaded Drive book MUST continue to navigate directly to `PlayerScreen`.
- Tapping "Start listening" for a local (non-Drive) book MUST continue to navigate directly to `PlayerScreen`.
- The "Download to device" `OutlinedButton` on the details screen MUST continue to start the download directly without showing the prompt.
- Tapping a book card in the library grid for an undownloaded Drive book MUST continue to show the download prompt (existing `_openPlayer` path in `LibraryScreen` is unchanged).

**Scope:**
All inputs where `isBugConditionA` and `isBugConditionB` both return false are unaffected by this fix. This includes:
- Any interaction with local books.
- Any interaction with fully downloaded Drive books.
- Any interaction with Drive books that are currently downloading.
- Any non-"Start listening" button tap on the details screen.

---

## Hypothesized Root Cause

**Bug A:**
1. **Overly narrow connectivity guard**: The original author added `if (!isWifi)` before the `totalSizeBytes` fetch, intending to show the size only as a mobile-data warning. The size display was never wired up for the WiFi branch, so the WiFi message path has no size variable to reference.

**Bug B:**
1. **Missing download-state check in `_ActionButtonsState.build`**: The `FilledButton` `onPressed` callback was written without a guard. The download-state variables (`fullyDownloaded`, `notDownloaded`, `_isDownloading`) are computed in `build` but only used to conditionally render the secondary buttons — the primary "Start listening" button ignores them entirely.
2. **Download prompt logic is private**: `_showDriveDownloadSheet` is a private method on `_LibraryScreenState`, so `BookDetailsScreen` cannot call it without refactoring.

---

## Correctness Properties

Property 1: Bug Condition A — File Size Always Fetched for Download Prompt

_For any_ call to `showDriveDownloadSheet` where `book.source == AudiobookSource.drive` and `book.audioFiles.isEmpty`, the function SHALL fetch `totalSizeBytes` regardless of whether the device is on WiFi or mobile data, and SHALL display the formatted size in both the prompt message and the Download button label.

**Validates: Requirements 2.1, 2.2**

Property 2: Bug Condition B — "Start Listening" Shows Prompt for Undownloaded Drive Books

_For any_ tap of the "Start listening" button where `book.source == AudiobookSource.drive` and `book.audioFiles.isEmpty` and the book is not currently downloading, the `_ActionButtonsState` SHALL call `showDriveDownloadSheet` instead of navigating to `PlayerScreen`.

**Validates: Requirements 2.3, 2.4**

Property 3: Preservation — Mobile Data Path Unchanged

_For any_ call to `showDriveDownloadSheet` where the device is on mobile data, the function SHALL continue to display the file size with the mobile-data warning message and annotate the Download button label with the formatted size, identical to the pre-fix behavior.

**Validates: Requirements 3.1, 3.2**

Property 4: Preservation — Direct Navigation for Downloaded and Local Books

_For any_ tap of the "Start listening" button where `book.source == AudiobookSource.local` OR (`book.source == AudiobookSource.drive` AND `fullyDownloaded == true`), the `_ActionButtonsState` SHALL navigate directly to `PlayerScreen` without showing the download prompt, identical to the pre-fix behavior.

**Validates: Requirements 3.3, 3.4**

---

## Fix Implementation

### Changes Required

**Step 1 — Extract shared download-prompt function**

**New file**: `lib/utils/drive_download_sheet.dart`

Extract `_showDriveDownloadSheet` from `_LibraryScreenState` into a top-level `Future<void> showDriveDownloadSheet(BuildContext context, Audiobook book)` function. This file will also import `formatBytes` (currently a top-level function in `library_screen.dart`) — either re-export it from `lib/utils/formatters.dart` or duplicate the small helper.

**Specific Changes**:
1. **Remove `!isWifi` guard**: Change `if (!isWifi) { sizeBytes = await ...; }` to always call `totalSizeBytes`, making `sizeBytes` always non-null when the fetch succeeds.
2. **Update prompt message**: The existing conditional `if (sizeBytes != null)` branch already handles the mobile-data vs WiFi distinction in the message text — update the WiFi branch message to also show the size (e.g. "This book is ${formatBytes(sizeBytes)}. Download it to start listening.").
3. **Keep the mobile-data warning message** for the `isWifi == false` branch unchanged.
4. **Export `formatBytes`**: Move or re-export `formatBytes` from `lib/utils/formatters.dart` so it is accessible to the new utility file without duplicating it.

**Step 2 — Update `LibraryScreen` to use the extracted function**

**File**: `lib/screens/library_screen.dart`

Replace the body of `_showDriveDownloadSheet` with a call to the new top-level `showDriveDownloadSheet(context, book)`, or delete the private method and update the two call sites (`_openPlayer`) to call the top-level function directly.

**Step 3 — Fix "Start listening" button in `BookDetailsScreen`**

**File**: `lib/screens/book_details_screen.dart`

**Function**: `_ActionButtonsState.build`

**Specific Changes**:
1. **Add download-state guard to `FilledButton.onPressed`**: Before navigating, check `if (isDrive && notDownloaded)`. If true, call `showDriveDownloadSheet(context, widget.book)` and return. Otherwise proceed with `Navigator.pushReplacement`.
2. **Import `showDriveDownloadSheet`**: Add `import '../utils/drive_download_sheet.dart';` to `book_details_screen.dart`.
3. **Make `_ActionButtonsState.build` async** (or use `unawaited`) since `showDriveDownloadSheet` is async.

---

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate each bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate both bugs BEFORE implementing the fix. Confirm or refute the root cause analysis.

**Test Plan**: Write widget tests that simulate the relevant user interactions and assert on the resulting UI state. Run these tests on the UNFIXED code to observe failures.

**Test Cases**:
1. **WiFi prompt — no size shown (Bug A)**: Stub connectivity as WiFi, call `showDriveDownloadSheet` for an undownloaded Drive book, assert that the bottom sheet contains a formatted size string. Will fail on unfixed code because `sizeBytes` is null on WiFi.
2. **WiFi Download button — no size label (Bug A)**: Same setup, assert that the "Download" button text includes the formatted size. Will fail on unfixed code.
3. **Start listening — navigates without prompt (Bug B)**: Render `_ActionButtons` for an undownloaded Drive book, tap "Start listening", assert that `PlayerScreen` is NOT pushed and the download sheet IS shown. Will fail on unfixed code because navigation happens unconditionally.
4. **Start listening — fully downloaded Drive book (preservation)**: Render `_ActionButtons` for a fully downloaded Drive book, tap "Start listening", assert that `PlayerScreen` IS pushed. Should pass on both unfixed and fixed code.

**Expected Counterexamples**:
- Test 1/2: `sizeBytes` is null on WiFi path → size string absent from sheet.
- Test 3: `Navigator.pushReplacement` is called immediately → `PlayerScreen` appears instead of the download sheet.

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed code produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugConditionA(input) DO
  result := showDriveDownloadSheet_fixed(input.context, input.book)
  ASSERT sheetContainsFormattedSize(result)
  ASSERT downloadButtonLabelContainsSize(result)
END FOR

FOR ALL input WHERE isBugConditionB(input) DO
  result := onStartListeningTap_fixed(input.context, input.book)
  ASSERT downloadSheetShown(result)
  ASSERT playerScreenNotPushed(result)
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug conditions do NOT hold, the fixed code produces the same result as the original code.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugConditionA(input) AND NOT isBugConditionB(input) DO
  ASSERT original_behavior(input) == fixed_behavior(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many connectivity states and book configurations automatically.
- It catches edge cases (e.g. ethernet connection, partially downloaded books) that manual tests might miss.
- It provides strong guarantees that the mobile-data path and direct-navigation path are unchanged.

**Test Cases**:
1. **Mobile data path preserved**: Generate mobile-data connectivity, call `showDriveDownloadSheet`, assert mobile-data warning message and size label are present — same as before the fix.
2. **Fully downloaded Drive book navigates directly**: Generate Drive books with `audioFiles.length >= totalFileCount`, tap "Start listening", assert `PlayerScreen` is pushed without showing the sheet.
3. **Local book navigates directly**: Generate local books, tap "Start listening", assert `PlayerScreen` is pushed without showing the sheet.
4. **"Download to device" button unaffected**: Tap the `OutlinedButton` for a not-yet-downloaded Drive book, assert download starts without showing the prompt sheet.

### Unit Tests

- Test `showDriveDownloadSheet` with WiFi connectivity: assert `totalSizeBytes` is called and the returned sheet widget contains the formatted size.
- Test `showDriveDownloadSheet` with mobile-data connectivity: assert the mobile-data warning message is shown with the formatted size.
- Test `_ActionButtonsState` "Start listening" tap for each combination of `(isDrive, fullyDownloaded, isDownloading)` and assert the correct outcome (sheet vs navigation).
- Test `formatBytes` edge cases (0 bytes, exactly 1 KB, exactly 1 MB, large values).

### Property-Based Tests

- Generate random `ConnectivityResult` values and Drive books with `audioFiles.isEmpty == true`; assert `showDriveDownloadSheet` always fetches and displays a size.
- Generate random Drive books with varying `audioFiles.length` and `totalFileCount`; assert "Start listening" shows the prompt if and only if `audioFiles.isEmpty && !isDownloading`.
- Generate random non-Drive books; assert "Start listening" always navigates directly to `PlayerScreen`.

### Integration Tests

- Full flow: open `BookDetailsScreen` for an undownloaded Drive book, tap "Start listening", verify the download sheet appears, tap "Download", verify `DriveLibraryService.startDownload` is called.
- Full flow: open `BookDetailsScreen` for a fully downloaded Drive book, tap "Start listening", verify `PlayerScreen` is pushed.
- Cross-screen consistency: verify that the download sheet shown from `BookDetailsScreen` and the one shown from `LibraryScreen` (via `_openPlayer`) are visually and functionally identical.
