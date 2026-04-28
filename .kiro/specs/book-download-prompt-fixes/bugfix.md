# Bugfix Requirements Document

## Introduction

Two related issues affect the book download/player flow in Kōwhai:

1. **Missing file size on WiFi** — The download prompt (`_showDriveDownloadSheet` in `library_screen.dart`) only fetches and displays the book's file size when the device is on mobile data. When on WiFi, the prompt shows a generic message with no size information, even though the size is equally useful context for the user.

2. **"Start listening" bypasses download prompt** — On the book details screen (`book_details_screen.dart`), the "Start listening" button always navigates directly to `PlayerScreen` regardless of whether the book has been downloaded. For Drive books that have not been downloaded yet, this opens the player with no audio files, causing playback to fail silently. The correct behaviour is to show the same download prompt that the library screen already uses.

---

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the user opens the download prompt for a Drive book AND the device is connected via WiFi THEN the system displays a generic message ("This book hasn't been downloaded yet. Download it to start listening.") with no file size information.

1.2 WHEN the user opens the download prompt for a Drive book AND the device is connected via WiFi THEN the system shows the Download button label as "Download" with no size annotation.

1.3 WHEN the user taps "Start listening" on the book details screen for a Drive book that has not been downloaded THEN the system navigates to the player screen without triggering the download prompt.

1.4 WHEN the player screen opens for a Drive book with no local audio files THEN the system fails to play the book (no audio, no error message shown to the user).

### Expected Behavior (Correct)

2.1 WHEN the user opens the download prompt for a Drive book AND the device is connected via WiFi THEN the system SHALL fetch and display the book's file size in the prompt message.

2.2 WHEN the user opens the download prompt for a Drive book AND the device is connected via WiFi THEN the system SHALL annotate the Download button label with the formatted file size (e.g. "Download (245.3 MB)").

2.3 WHEN the user taps "Start listening" on the book details screen for a Drive book that has not been downloaded THEN the system SHALL show the download prompt instead of navigating to the player screen.

2.4 WHEN the download prompt is shown from the book details screen THEN the system SHALL behave identically to the prompt shown from the library screen, including file size display and the ability to start the download.

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the user opens the download prompt for a Drive book AND the device is on mobile data THEN the system SHALL CONTINUE TO fetch and display the file size with the mobile-data warning message.

3.2 WHEN the user opens the download prompt for a Drive book AND the device is on mobile data THEN the system SHALL CONTINUE TO annotate the Download button label with the formatted file size.

3.3 WHEN the user taps "Start listening" on the book details screen for a Drive book that is fully downloaded THEN the system SHALL CONTINUE TO navigate directly to the player screen.

3.4 WHEN the user taps "Start listening" on the book details screen for a local (non-Drive) book THEN the system SHALL CONTINUE TO navigate directly to the player screen.

3.5 WHEN the user taps "Download to device" on the book details screen for a not-yet-downloaded Drive book THEN the system SHALL CONTINUE TO start the download without showing the prompt.

3.6 WHEN the user taps a book card in the library grid for a Drive book that has not been downloaded THEN the system SHALL CONTINUE TO show the download prompt (existing library screen behaviour is unchanged).

---

**Status: COMPLETE** — Both bugs fixed. WiFi file size display implemented in `lib/utils/drive_download_sheet.dart`. Book details screen download prompt implemented in `lib/screens/book_details_screen.dart` via `showDriveDownloadSheet`. Regression tests passing.
