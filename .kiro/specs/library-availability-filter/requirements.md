# Requirements Document

## Introduction

This feature adds an "Availability" filter to the AudioVault library screen's existing filter sheet. The filter lets users narrow the library to books they can play right now without an internet connection ("Available offline") or to Drive books that have not yet been downloaded ("Drive only"). The default state ("All") preserves the current behaviour. The filter state persists across app restarts via SharedPreferences and interacts correctly with the existing status filter, search, and sort.

## Glossary

- **Library_Screen**: The main screen (`lib/screens/library_screen.dart`) that displays the user's audiobook collection.
- **Filter_Sheet**: The modal bottom sheet opened by the tune icon in the view bar, currently containing the PROGRESS filter section.
- **Availability_Filter**: The new single-select filter with three states: `all`, `availableOffline`, and `driveOnly`.
- **Local_Book**: An `Audiobook` whose `source` field equals `AudiobookSource.local`.
- **Drive_Book**: An `Audiobook` whose `source` field equals `AudiobookSource.drive`.
- **Downloaded_Drive_Book**: A Drive_Book whose `audioFiles` list is non-empty (all audio files have `DriveDownloadState.done` in the repository, meaning local paths exist on disk).
- **Undownloaded_Drive_Book**: A Drive_Book whose `audioFiles` list is empty (no audio files have been downloaded locally).
- **Offline_Available_Book**: Any Local_Book, or any Downloaded_Drive_Book.
- **AvailabilityFilterState**: An enum with values `all`, `availableOffline`, `driveOnly`.
- **Preferences_Service**: `lib/services/preferences_service.dart`, the SharedPreferences wrapper.
- **View_Bar**: The row below the search bar containing the book count, filter button, and sort button.
- **Drive_Connected**: A state where `DriveService.currentAccount` is non-null, meaning the user has an active Google Drive session.

---

## Requirements

### Requirement 1: Availability Filter State Model

**User Story:** As a developer, I want a well-defined filter state enum, so that the filter logic is type-safe and easy to extend.

#### Acceptance Criteria

1. THE Library_Screen SHALL define an `AvailabilityFilterState` enum with exactly three values: `all`, `availableOffline`, and `driveOnly`.
2. THE Library_Screen SHALL initialise the active `AvailabilityFilterState` to `all` on first launch when no persisted value exists.

---

### Requirement 2: Availability Filter Logic

**User Story:** As a listener, I want to filter my library by availability, so that I can quickly find books I can play right now or books I still need to download.

#### Acceptance Criteria

1. WHEN `AvailabilityFilterState` is `all`, THE Library_Screen SHALL include every book in the displayed list regardless of source or download status.
2. WHEN `AvailabilityFilterState` is `availableOffline`, THE Library_Screen SHALL include only Offline_Available_Books (Local_Books and Downloaded_Drive_Books) in the displayed list.
3. WHEN `AvailabilityFilterState` is `driveOnly`, THE Library_Screen SHALL include only Undownloaded_Drive_Books in the displayed list.
4. THE Library_Screen SHALL apply the Availability_Filter before applying the existing status (progress) filter, so that both filters compose correctly.
5. THE Library_Screen SHALL apply the Availability_Filter to the full sorted book list, so that the active sort order is preserved within the filtered result.
6. WHEN a Drive_Book transitions from Undownloaded to Downloaded while `AvailabilityFilterState` is `driveOnly`, THE Library_Screen SHALL remove that book from the displayed list without requiring a manual rescan.
7. WHEN a Drive_Book transitions from Undownloaded to Downloaded while `AvailabilityFilterState` is `availableOffline`, THE Library_Screen SHALL add that book to the displayed list without requiring a manual rescan.

---

### Requirement 3: Filter Sheet UI — Availability Section

**User Story:** As a listener, I want to see and change the Availability filter inside the existing filter sheet, so that all filter controls are in one place.

#### Acceptance Criteria

1. THE Filter_Sheet SHALL display an "AVAILABILITY" section label above the availability filter pills, styled consistently with the existing "PROGRESS" section label.
2. THE Filter_Sheet SHALL display three filter pills labelled "All", "Available offline", and "Drive only", each showing the count of matching books in parentheses.
3. WHEN the user taps a pill, THE Filter_Sheet SHALL update the active `AvailabilityFilterState` and refresh the pill selection state immediately without closing the sheet.
4. THE Filter_Sheet SHALL display the "Available offline" and "Drive only" pills only when at least one Drive_Book exists in the library; WHEN no Drive_Books exist, THE Filter_Sheet SHALL display only the "All" pill in the AVAILABILITY section.
5. THE Filter_Sheet's "Clear all" button SHALL reset the `AvailabilityFilterState` to `all` in addition to clearing the status filter.
6. THE Filter_Sheet SHALL display the entire AVAILABILITY section (including the "All" pill and section label) only when Drive_Connected is true; WHEN Drive_Connected is false, THE Filter_Sheet SHALL not render the AVAILABILITY section at all.

---

### Requirement 4: View Bar Active Indicator

**User Story:** As a listener, I want a visual cue in the view bar when the Availability filter is active, so that I know my library is filtered without opening the sheet.

#### Acceptance Criteria

1. WHEN `AvailabilityFilterState` is not `all`, THE View_Bar SHALL highlight the filter button (tune icon) using the same active style already applied when the status filter is active.
2. WHEN `AvailabilityFilterState` is not `all`, THE View_Bar SHALL append the active filter label (e.g. "Available offline" or "Drive only") to the summary text shown beside the book count, using the same primary-colour style as the existing sort summary.
3. WHEN both the status filter and the Availability_Filter are active simultaneously, THE View_Bar SHALL include both labels in the summary text, separated by " · ".
4. WHEN Drive_Connected is false and `AvailabilityFilterState` is not `all` (e.g. a persisted value from a previous session when Drive was connected), THE Library_Screen SHALL silently reset `_availabilityFilter` to `all` and not display any availability indicator in the View_Bar.

---

### Requirement 5: Persistence Across App Restarts

**User Story:** As a listener, I want my Availability filter choice to be remembered between sessions, so that I don't have to re-apply it every time I open the app.

#### Acceptance Criteria

1. THE Preferences_Service SHALL expose a `getAvailabilityFilter()` method that returns the persisted `AvailabilityFilterState`, defaulting to `AvailabilityFilterState.all` when no value has been stored.
2. THE Preferences_Service SHALL expose a `setAvailabilityFilter(AvailabilityFilterState value)` method that persists the filter state to SharedPreferences.
3. WHEN the Library_Screen initialises, THE Library_Screen SHALL load the persisted `AvailabilityFilterState` from Preferences_Service and apply it before displaying the book list.
4. WHEN the user changes the `AvailabilityFilterState` via the Filter_Sheet, THE Library_Screen SHALL persist the new value via Preferences_Service immediately.

---

### Requirement 6: Empty-State Messaging

**User Story:** As a listener, I want a clear message when the Availability filter produces no results, so that I understand why my library appears empty.

#### Acceptance Criteria

1. WHEN the Availability_Filter (or its combination with the status filter or search query) produces an empty result, THE Library_Screen SHALL display the existing no-matches view with a message that references the active filter(s).
2. WHEN `AvailabilityFilterState` is `availableOffline` and the result is empty, THE Library_Screen SHALL include the text "available offline" in the no-matches message.
3. WHEN `AvailabilityFilterState` is `driveOnly` and the result is empty, THE Library_Screen SHALL include the text "Drive only" in the no-matches message.
4. THE Library_Screen's "Clear filters" button in the no-matches view SHALL reset both the status filter and the `AvailabilityFilterState` to their default values.
