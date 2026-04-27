# Implementation Plan: Library Availability Filter

## Overview

Add an "Availability" filter to the AudioVault library screen. The implementation touches three files: a new model file for the enum, `PreferencesService` for persistence, and `library_screen.dart` for the filter logic, state, and UI. No new services or dependencies are required.

## Tasks

- [x] 1. Create `AvailabilityFilterState` enum model
  - Create `lib/models/availability_filter_state.dart` with the `AvailabilityFilterState` enum (`all`, `availableOffline`, `driveOnly`) and a `label` getter
  - This file is imported by both `library_screen.dart` and `preferences_service.dart` to avoid a circular dependency
  - _Requirements: 1.1_

- [x] 2. Add availability filter persistence to `PreferencesService`
  - [x] 2.1 Implement `getAvailabilityFilter` and `setAvailabilityFilter` in `lib/services/preferences_service.dart`
    - Add `static const _availabilityFilterKey = 'availability_filter'`
    - `getAvailabilityFilter()` reads the stored string, matches it to an enum value via `firstWhere(orElse: () => AvailabilityFilterState.all)`, and returns `AvailabilityFilterState.all` when unset or unrecognised
    - `setAvailabilityFilter(AvailabilityFilterState value)` writes `value.name` to SharedPreferences
    - Import `lib/models/availability_filter_state.dart`
    - _Requirements: 5.1, 5.2_

  - [x]* 2.2 Write unit tests for `PreferencesService` availability filter methods
    - Add to `test/services/preferences_service_test.dart`
    - Test: `getAvailabilityFilter` defaults to `all` when unset
    - Test: round-trip for each of the three enum values (`all`, `availableOffline`, `driveOnly`)
    - Test: unrecognised stored string falls back to `all`
    - _Requirements: 5.1, 5.2_

- [x] 3. Implement `applyAvailabilityFilter` pure function
  - [x] 3.1 Add `applyAvailabilityFilter` as a top-level function in `lib/screens/library_screen.dart`
    - Import `lib/models/availability_filter_state.dart`
    - `all` → returns `books` unchanged
    - `availableOffline` → keeps local books and Drive books with non-empty `audioFiles`
    - `driveOnly` → keeps only Drive books with empty `audioFiles`
    - _Requirements: 2.1, 2.2, 2.3_

  - [x]* 3.2 Write property test for `applyAvailabilityFilter` — Property 1: `all` is identity
    - Add to `test/screens/library_helpers_test.dart` using `package:fast_check`
    - Tag: `// Feature: library-availability-filter, Property 1: all filter is identity`
    - For any list of audiobooks, `applyAvailabilityFilter(books, all)` returns a list with the same books in the same order
    - **Property 1: `all` filter is identity**
    - **Validates: Requirements 2.1**

  - [x]* 3.3 Write property test for `applyAvailabilityFilter` — Property 2: `availableOffline` completeness and soundness
    - Tag: `// Feature: library-availability-filter, Property 2: availableOffline filter returns only offline-available books`
    - Every book in the output is a local book or a Drive book with non-empty `audioFiles`; every qualifying input book appears in the output
    - **Property 2: `availableOffline` filter returns only offline-available books**
    - **Validates: Requirements 2.2**

  - [x]* 3.4 Write property test for `applyAvailabilityFilter` — Property 3: `driveOnly` completeness and soundness
    - Tag: `// Feature: library-availability-filter, Property 3: driveOnly filter returns only undownloaded Drive books`
    - Every book in the output is a Drive book with empty `audioFiles`; every qualifying input book appears in the output
    - **Property 3: `driveOnly` filter returns only undownloaded Drive books**
    - **Validates: Requirements 2.3**

  - [x]* 3.5 Write property test for `applyAvailabilityFilter` — Property 4: sort order preserved
    - Tag: `// Feature: library-availability-filter, Property 4: availability filter preserves sort order`
    - For any book list and any `AvailabilityFilterState`, the relative order of books in the output matches their relative order in the input
    - **Property 4: Availability filter preserves sort order**
    - **Validates: Requirements 2.5**

  - [x]* 3.6 Write property test for `applyAvailabilityFilter` — Property 5: composition with status filter
    - Tag: `// Feature: library-availability-filter, Property 5: availability filter composes correctly with status filter`
    - For any book list, any `AvailabilityFilterState`, and any `BookStatus` filter, applying availability then status produces a subset of the availability-only result, and every book in the result satisfies both predicates independently
    - **Property 5: Availability filter composes correctly with status filter**
    - **Validates: Requirements 2.4**

- [x] 4. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Wire availability filter state into `_LibraryScreenState`
  - [x] 5.1 Add `_availabilityFilter` field and update `_displayedBooks` getter in `lib/screens/library_screen.dart`
    - Add `AvailabilityFilterState _availabilityFilter = AvailabilityFilterState.all` field to `_LibraryScreenState`
    - Update `_displayedBooks` getter to call `applyAvailabilityFilter(_books ?? [], _availabilityFilter)` first, then pass the result to `filterBooks`, then to `applyStatusFilter` (matching the pipeline in the design)
    - _Requirements: 1.2, 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 5.2 Load persisted `AvailabilityFilterState` on init in `_initLibrary`
    - In `_initLibrary`, call `prefs.getAvailabilityFilter()` and check `locator<DriveService>().currentAccount != null`
    - If Drive is connected, apply the persisted value; if not, reset to `AvailabilityFilterState.all` (silently discard any persisted non-`all` value)
    - Set `_availabilityFilter` via `setState` before the library is displayed
    - _Requirements: 4.4, 5.3_

  - [x] 5.3 Persist `AvailabilityFilterState` changes immediately when the user updates the filter
    - Whenever `_availabilityFilter` is changed (from the filter sheet), call `locator<PreferencesService>().setAvailabilityFilter(newValue)` immediately
    - _Requirements: 5.4_

- [x] 6. Update the filter sheet UI to include the AVAILABILITY section
  - [x] 6.1 Add AVAILABILITY section to `_openFilterSheet` in `lib/screens/library_screen.dart`
    - Wrap the entire AVAILABILITY section in a `if (locator<DriveService>().currentAccount != null)` guard — do not render the section at all when Drive is not connected
    - Compute availability pill counts from the search-filtered book list (same base as the PROGRESS counts): `applyAvailabilityFilter(searchFiltered, state).length` for each state
    - Add an "AVAILABILITY" section label styled identically to the existing "PROGRESS" label (same `labelSmall` + `letterSpacing` + `onSurfaceVariant` colour)
    - Render three pills: "All (N)", "Available offline (N)", "Drive only (N)"
    - Show "Available offline" and "Drive only" pills only when `_driveBooks.isNotEmpty`; when no Drive books exist, show only the "All" pill in the AVAILABILITY section
    - Tapping a pill calls `setState` on both the screen state and the sheet state, persists the new value via `PreferencesService`, and does not close the sheet
    - The "Clear all" button resets `_availabilityFilter` to `AvailabilityFilterState.all` in addition to clearing `_statusFilter`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [ ]* 6.2 Write property test for pill counts — Property 6
    - Add to `test/screens/library_helpers_test.dart`
    - Tag: `// Feature: library-availability-filter, Property 6: pill counts match actual filtered counts`
    - For any book list, the count for each availability state equals `applyAvailabilityFilter(books, state).length`
    - **Property 6: Pill counts match actual filtered counts**
    - **Validates: Requirements 3.2**

  - [ ]* 6.3 Write property test for Drive pill visibility — Property 7
    - Tag: `// Feature: library-availability-filter, Property 7: drive-book pill visibility`
    - For any book list, the "Available offline" and "Drive only" pills are visible if and only if at least one book has `source == AudiobookSource.drive`
    - **Property 7: Drive-book pill visibility**
    - **Validates: Requirements 3.4**

- [x] 7. Update the view bar active-filter indicator
  - Modify `_viewBar` in `lib/screens/library_screen.dart`:
    - Change `hasStatus` to also include `_availabilityFilter != AvailabilityFilterState.all` when computing whether the tune icon is highlighted (i.e. `active: hasStatus || _availabilityFilter != AvailabilityFilterState.all`)
    - Append the availability filter label to `summaryParts` when `_availabilityFilter != AvailabilityFilterState.all`, so it appears in the `" · "` separated summary text beside the book count
    - When both status and availability filters are active, both labels appear in the summary separated by `" · "`
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 8. Update the no-matches view for availability filter context
  - Modify `_noMatchesView` in `lib/screens/library_screen.dart`:
    - Extend the message-building logic to account for `_availabilityFilter != AvailabilityFilterState.all`
    - When `_availabilityFilter` is `availableOffline`, include "available offline" in the message
    - When `_availabilityFilter` is `driveOnly`, include "Drive only" in the message
    - Combine with search query and status filter messages using the same pattern as the existing logic
    - Update `_clearSearchAndFilters` to also reset `_availabilityFilter` to `AvailabilityFilterState.all` and persist the reset via `PreferencesService`
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 9. Handle reactive Drive download transitions
  - In `_refreshDriveBook` (called from `_onDriveDownloadEvent`), the existing call to `_applySort()` already triggers a re-render of `_displayedBooks`; verify that `_displayedBooks` now correctly reflects the updated `audioFiles` list after a download completes, so that:
    - A newly-downloaded Drive book disappears from the `driveOnly` filtered view (Requirement 2.6)
    - A newly-downloaded Drive book appears in the `availableOffline` filtered view (Requirement 2.7)
  - No code changes are expected here if the pipeline is wired correctly in task 5.1; add a code comment confirming the reactive behaviour is covered by the `_applySort` → `_displayedBooks` pipeline
  - _Requirements: 2.6, 2.7_

- [x] 10. Final checkpoint — Ensure all tests pass
  - Run `flutter analyze --fatal-warnings` and `flutter test`
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Property tests use `package:fast_check` (already listed in the design); each runs a minimum of 100 iterations
- Each task references specific requirements for traceability
- The filter pipeline order is: `applyAvailabilityFilter` → `filterBooks` (search) → `applyStatusFilter` — this matches the design and ensures correct composition
- `AvailabilityFilterState` lives in `lib/models/availability_filter_state.dart` to avoid a circular import between `library_screen.dart` and `preferences_service.dart`
