# PRD-39 (P2): Progress sync

## Problem
Book positions are stored only in the on-device SQLite database (`audiovault_positions.db`). If the user reinstalls the app, switches devices, or loses their phone, all reading progress is gone. There is no cross-device sync and no recovery path.

## Evidence
- `PositionService` writes exclusively to `audiovault_positions.db` in the app documents directory
- No export or backup mechanism exists
- Drive integration is read-only (streaming/downloading books); it never writes back to Drive

## Proposed Solution
Two complementary layers:

**Layer 1 — Local JSON (always on when a folder is set)**
Write a `positions.json` file into the audiobooks root folder alongside the books. This is automatic and requires no user action. It means progress is stored next to the audio files and survives an app reinstall as long as the folder is intact.

**Layer 2 — Drive sync (opt-in toggle)**
When a Google Drive account is connected, expose a "Sync progress to Drive" toggle in the Drive section of Settings. When enabled, `positions.json` is uploaded to `AudioVault/positions.json` in the user's Drive on app background and at most every 5 minutes while playing. On first launch with an empty local DB and Drive sync enabled, the app silently restores from Drive.

### Settings UI
In the Drive section (visible only when `_driveAccount != null`), add a toggle below "Remove when finished":

> **Sync progress to Drive**
> Backs up your listening progress so you can pick up where you left off on any device.

### JSON format
```json
{
  "version": 1,
  "exported_at": 1718000000000,
  "positions": [
    {
      "book_path": "Author/Book Title",
      "chapter_index": 3,
      "position_ms": 142000,
      "global_position_ms": 5342000,
      "total_duration_ms": 72000000,
      "status": "inProgress",
      "updated_at": 1717999000000
    }
  ]
}
```

`book_path` is stored **relative to the audiobooks root folder** so it survives reinstall and works across devices where the absolute path differs.

### Sync behaviour
- Local `positions.json` is written (debounced, max once per 30 s) after every position save, and immediately when the app backgrounds. Only written if an audiobooks folder is configured.
- Drive upload fires on app background and at most every 5 min while playing. Only runs when the "Sync progress to Drive" toggle is on. Upload is fire-and-forget; failures are logged silently.
- Restore merges into the local DB: only entries with a newer `updated_at` than the existing row are applied (last-write-wins per book). Existing rows with no JSON counterpart are untouched.

### Auto-restore
On startup, if `getAllPositions()` returns empty and Drive sync is enabled, silently download and merge from Drive. No dialog — positions are additive, no data loss risk.

## Acceptance Criteria
- [ ] `positions.json` is written to the audiobooks root folder within 30 s of any position change (when a folder is configured)
- [ ] `positions.json` is written immediately when the app backgrounds
- [ ] `book_path` values in JSON are relative to the audiobooks root, not absolute
- [ ] "Sync progress to Drive" toggle appears in the Drive section only when a Drive account is connected
- [ ] Toggle state persists across app restarts (`PreferencesService` key: `drive_progress_sync`)
- [ ] When toggle is on, `positions.json` is uploaded to `AudioVault/positions.json` in Drive within 5 min of any position change
- [ ] Drive upload fires on app backgrounding regardless of the 5-min timer
- [ ] No user-visible error if Drive upload fails
- [ ] Auto-restore runs silently on first launch with empty DB + sync enabled
- [ ] Restore merges correctly: newer `updated_at` wins; no rollback of newer local progress
- [ ] Unit tests cover serialisation, deserialisation, merge logic, and relative-path conversion

## Out of Scope
- Manual "Back up now" / "Restore from Drive" buttons (auto behaviour is sufficient for v1)
- Conflict resolution beyond last-write-wins
- Backup of bookmarks (PRD-34) — follow-up
- Backup of Drive book metadata (`drive_books` / `drive_book_files` tables)
- iCloud backup (iOS system backup already covers the documents directory)

## Implementation Plan
1. Add `PreferencesService` key `drive_progress_sync` (bool, default false) with getter/setter.
2. Create `lib/services/position_backup_service.dart`:
   - `exportToJson(String audiobooksRoot)` — reads all positions from `PositionService`, converts absolute `book_path` to relative, writes `audiobooksRoot/positions.json`; debounced 30 s
   - `importFromJson(String audiobooksRoot)` — reads the file, converts relative paths back to absolute, merges into `PositionService` (last-write-wins on `updated_at`)
   - `uploadToDrive()` — reads local JSON bytes, calls `DriveService.uploadFile()`; debounced 5 min; no-op if sync pref is off
   - `restoreFromDrive()` — downloads `AudioVault/positions.json` via `DriveService`, writes locally, calls `importFromJson`
3. Extend `DriveService` with write-scoped methods (add `drive.DriveApi.driveFileScope` to `GoogleSignIn` scopes — triggers re-consent for existing users; see Notes):
   - `Future<void> uploadFile(String parentFolderId, String fileName, List<int> bytes)`
   - `Future<List<int>?> downloadFileByName(String parentFolderId, String fileName)`
   - `Future<String> findOrCreateFolder(String parentId, String name)` — caches result in `SharedPreferences` key `drive_backup_folder_id`
4. Hook `PositionBackupService.exportToJson()` into `PositionService.savePosition()` — debounced call after every write (only if `PreferencesService.getLibraryPath()` is non-null).
5. Hook both `exportToJson` and `uploadToDrive` into `AppLifecycleListener.onPause` in `main.dart` — bypasses debounce timers.
6. Settings screen — inside the `if (_driveAccount != null)` block, add after "Remove when finished":
   ```dart
   ListTile(
     leading: const Icon(Icons.cloud_sync_rounded),
     title: const Text('Sync progress to Drive'),
     subtitle: const Text('Back up your listening progress so you can pick up where you left off on any device'),
     trailing: Switch(value: _driveProgressSync, onChanged: _setDriveProgressSync),
     onTap: () => _setDriveProgressSync(!_driveProgressSync),
     contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
   )
   ```
7. Auto-restore in `main.dart`: after services are ready, if `getAllPositions()` is empty and `drive_progress_sync` is true and Drive account is present, call `restoreFromDrive()`.
8. Register `PositionBackupService` in `locator.dart`.
9. Unit tests in `test/services/position_backup_service_test.dart`:
   - `exportToJson` produces correct relative paths and valid JSON
   - `importFromJson` skips rows where existing `updated_at` is newer
   - `importFromJson` applies rows where JSON `updated_at` is newer
   - Round-trip: export → import → positions unchanged
   - Malformed JSON → no throw, no DB changes

## Files Impacted
- `lib/services/position_backup_service.dart` (new)
- `lib/services/position_service.dart` (call debounced export after `savePosition`)
- `lib/services/drive_service.dart` (add `uploadFile`, `downloadFileByName`, `findOrCreateFolder`; add `driveFileScope`)
- `lib/services/preferences_service.dart` (add `drive_progress_sync` getter/setter)
- `lib/locator.dart` (register `PositionBackupService`)
- `lib/main.dart` (`AppLifecycleListener` hook; auto-restore on startup)
- `lib/screens/settings_screen.dart` ("Sync progress to Drive" toggle in Drive section)
- `test/services/position_backup_service_test.dart` (new)
- `CHANGELOG.md`

## Notes
- Adding `driveFileScope` alongside `driveReadonlyScope` will prompt re-consent for users who previously signed in with Drive. This is unavoidable for write access. The scope change only takes effect when the user next signs in or reconnects Drive — existing read-only sessions are unaffected until then.
- The `AudioVault/` folder ID is cached in `SharedPreferences` (`drive_backup_folder_id`) to avoid a folder-lookup API call on every upload.
