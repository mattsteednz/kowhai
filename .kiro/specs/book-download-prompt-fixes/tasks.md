# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - WiFi File Size Missing & Start Listening Bypasses Prompt
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bugs exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior — it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate both Bug A and Bug B exist
  - **Scoped PBT Approach**: Scope to the concrete failing cases for reproducibility:
    - Bug A: WiFi connectivity + undownloaded Drive book → `showDriveDownloadSheet` must show formatted size
    - Bug B: "Start listening" tap + undownloaded Drive book (not downloading) → must show download sheet, not navigate to PlayerScreen
  - Write widget tests that simulate the relevant user interactions:
    1. Stub connectivity as WiFi, call `showDriveDownloadSheet` for an undownloaded Drive book, assert the bottom sheet contains a formatted size string (e.g. "245.3 MB") — fails on unfixed code because `sizeBytes` is null on WiFi (`if (!isWifi)` guard skips the fetch)
    2. Same WiFi setup, assert the "Download" button text includes the formatted size (e.g. "Download (245.3 MB)") — fails on unfixed code
    3. Render `_ActionButtons` for an undownloaded Drive book (`audioFiles.isEmpty`, `!_isDownloading`), tap "Start listening", assert `PlayerScreen` is NOT pushed and the download sheet IS shown — fails on unfixed code because `Navigator.pushReplacement` is called unconditionally
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests FAIL (this is correct — it proves the bugs exist)
  - Document counterexamples found:
    - Bug A: `sizeBytes` is null on WiFi path → size string absent from sheet and button label
    - Bug B: `Navigator.pushReplacement` is called immediately → `PlayerScreen` appears instead of the download sheet
  - Mark task complete when tests are written, run, and failures are documented
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Mobile Data Path and Direct Navigation Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for non-buggy inputs (cases where `isBugConditionA` and `isBugConditionB` both return false):
    - Observe: mobile-data connectivity + undownloaded Drive book → sheet shows "You're on mobile data. This book is X. Download anyway?" with size in button label
    - Observe: "Start listening" tap on fully downloaded Drive book (`audioFiles.length >= totalFileCount`) → `PlayerScreen` is pushed directly
    - Observe: "Start listening" tap on local (non-Drive) book → `PlayerScreen` is pushed directly
    - Observe: "Download to device" `OutlinedButton` tap on undownloaded Drive book → `DriveLibraryService.startDownload` is called, no sheet shown
  - Write property-based tests capturing observed behavior patterns:
    1. Generate mobile-data connectivity states (`ConnectivityResult.mobile`), call `showDriveDownloadSheet` for undownloaded Drive books, assert mobile-data warning message and formatted size label are present
    2. Generate Drive books with varying `audioFiles.length` and `totalFileCount` where `fullyDownloaded == true`, tap "Start listening", assert `PlayerScreen` IS pushed without showing the sheet
    3. Generate local books (`AudiobookSource.local`), tap "Start listening", assert `PlayerScreen` IS pushed without showing the sheet
    4. Tap the "Download to device" `OutlinedButton` for an undownloaded Drive book, assert `startDownload` is called and no bottom sheet appears
  - Verify tests pass on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 3. Fix book download prompt bugs

  - [x] 3.1 Move/re-export `formatBytes` to `lib/utils/formatters.dart`
    - `formatBytes` is currently a top-level function in `lib/screens/library_screen.dart`
    - Move the implementation to `lib/utils/formatters.dart` so it is accessible to the new utility file without duplication
    - Update `library_screen.dart` to import from `lib/utils/formatters.dart` (or remove the local definition if re-exported)
    - _Requirements: 2.1, 2.2_

  - [x] 3.2 Extract `showDriveDownloadSheet` into `lib/utils/drive_download_sheet.dart`
    - Create new file `lib/utils/drive_download_sheet.dart`
    - Extract `_showDriveDownloadSheet` from `_LibraryScreenState` into a top-level `Future<void> showDriveDownloadSheet(BuildContext context, Audiobook book)` function
    - Import `formatBytes` from `lib/utils/formatters.dart`
    - **Remove the `!isWifi` guard**: change `if (!isWifi) { sizeBytes = await ...; }` to always call `totalSizeBytes`, making `sizeBytes` always non-null when the fetch succeeds
    - **Update WiFi branch prompt message**: change the `else` branch (currently "This book hasn't been downloaded yet. Download it to start listening.") to show the size: "This book is ${formatBytes(sizeBytes)}. Download it to start listening."
    - Keep the mobile-data warning message ("You're on mobile data. This book is X. Download anyway?") unchanged
    - _Bug_Condition: isBugConditionA(input) where input.connectivity ∈ {wifi, ethernet} AND book.audioFiles.isEmpty_
    - _Expected_Behavior: showDriveDownloadSheet always fetches totalSizeBytes and displays formatted size in both prompt message and Download button label_
    - _Preservation: mobile-data path message and button label remain unchanged_
    - _Requirements: 2.1, 2.2, 3.1, 3.2_

  - [x] 3.3 Update `LibraryScreen` to use the extracted function
    - In `lib/screens/library_screen.dart`, replace the body of `_showDriveDownloadSheet` with a call to the new top-level `showDriveDownloadSheet(context, book)`, or delete the private method and update the call site in `_openPlayer` to call the top-level function directly
    - Add `import '../utils/drive_download_sheet.dart';` to `library_screen.dart`
    - Remove the now-redundant local `formatBytes` definition (moved to `formatters.dart` in 3.1)
    - _Requirements: 3.6_

  - [x] 3.4 Fix "Start listening" button in `_ActionButtonsState` to check download state
    - In `lib/screens/book_details_screen.dart`, update `_ActionButtonsState.build`
    - Add download-state guard to `FilledButton.onPressed`: before navigating, check `if (isDrive && notDownloaded)` — if true, call `showDriveDownloadSheet(context, widget.book)` and return; otherwise proceed with `Navigator.pushReplacement`
    - Add `import '../utils/drive_download_sheet.dart';` to `book_details_screen.dart`
    - Make the `onPressed` callback `async` (or use `unawaited`) since `showDriveDownloadSheet` is async
    - _Bug_Condition: isBugConditionB(input) where tapTarget == 'Start listening' AND book.source == drive AND book.audioFiles.isEmpty AND !isDownloading_
    - _Expected_Behavior: showDriveDownloadSheet is called instead of Navigator.pushReplacement_
    - _Preservation: fully downloaded Drive books and local books continue to navigate directly to PlayerScreen_
    - _Requirements: 2.3, 2.4, 3.3, 3.4, 3.5_

  - [x] 3.5 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - WiFi File Size Missing & Start Listening Bypasses Prompt
    - **IMPORTANT**: Re-run the SAME tests from task 1 — do NOT write new tests
    - The tests from task 1 encode the expected behavior
    - When these tests pass, it confirms the expected behavior is satisfied for both Bug A and Bug B
    - Run bug condition exploration tests from step 1
    - **EXPECTED OUTCOME**: Tests PASS (confirms both bugs are fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [x] 3.6 Verify preservation tests still pass
    - **Property 2: Preservation** - Mobile Data Path and Direct Navigation Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all tests still pass after fix (no regressions)

- [x] 4. Checkpoint — Ensure all tests pass
  - Ensure all tests pass; ask the user if questions arise.
