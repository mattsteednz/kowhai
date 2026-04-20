# Changelog

All notable changes to AudioVault are documented here.

## [Unreleased]

### Added

- **metadata.opf support (PRD-37)** — When scanning a book folder, AudioVault now reads a `metadata.opf` file (Calibre/OverDrive format) if present. OPF values take precedence over embedded audio tags for title, author, narrator, description, publisher, language, release date, and series (including series index). Series is displayed as e.g. “The Stormlight Archive #1” in the book details screen and metadata section. Narrator is shown in the player screen below the author. Books without an OPF file are unaffected.
- **Chapter bookmarks (PRD-34)** — Bookmark any moment while listening. Tap the Bookmarks chip in the player bottom row to view all bookmarks for the current book or add a new one. Adding a bookmark captures the current timestamp (`H:MM:SS`), with optional Name and Notes fields; if Name is left blank it defaults to `Chapter X — H:MM:SS`. Bookmarks are listed in the book details screen and tapping one jumps straight to the player at that position. Swipe-to-delete in both locations. A book-details info button has been added to the player AppBar.

### Accessibility

- **PRD-30** — Added `Semantics` labels to player play/pause, chapter label, and speed chip; added `tooltip` to all player transport icon buttons and custom timer +/− buttons; added `Semantics(label:, excludeSemantics: true)` to decorative badges (now playing, finished, DRM lock) in card and list tile widgets; added `tooltip` to mini player play/pause; wrapped settings dialog rows in `ConstrainedBox(minHeight: 48)` to meet the 48dp touch target minimum; added large-text (2×) widget tests confirming no overflow.

### Internal

- **PRD-15** — `EnrichmentService` now uses a reusable `http.Client` that is closed on `cancel()`, aborting any in-flight request immediately. A per-request timeout (10s search, 15s download) was already in place. A `withDatabase` constructor enables test injection without `path_provider`.
- **PRD-14** — Added depth boundary tests for `ScannerService.maxScanDepth`; confirms books at depth 3 are found and depth 4 are not.
- **PRD-13** — Extracted `_deriveStatus` helper in `PositionService`; `getBookStatus` and `getAllStatuses` now share a single source of truth for the unstarted/in-progress/finished thresholds.

### Security

- **Cast server session token** — The local HTTP server now generates a random 16-byte hex token on each Cast session start. All served URLs (`/audio/<token>/<index>`, `/cover/<token>`) embed the token; requests without a valid token return 404, preventing other LAN devices from enumerating or downloading audio files while casting is active.

---

## [1.4.0] — 2026-04-19

### Changed

- **Library header redesign** — The AppBar is pared back to Sleep Timer, Search, and a ⋯ overflow menu (Listen history, Rescan library, Settings). The title "My Library" is always fully visible.
- **Inline search bar** — Tapping Search expands an animated search bar below the header instead of replacing the title.
- **View bar** — A new pinned row below the header shows the filtered book count and active filter/sort summary, with grid/list toggle on the left and Filter + Sort buttons on the right.
- **Filter and Sort bottom sheets** — Progress filtering moves into a Filter sheet with an explicit "All" pill as the default. Sort moves into its own sheet — a simple list with a check against the active option and a Cancel action. Both sheets auto-apply on tap.
- **Coloured placeholder tiles** — Books without cover art now render as deterministic jewel-tone tiles allocated sequentially across the grid/list so adjacent placeholders never share a colour. The default book icon has been removed for a cleaner look.
- **Frosted-glass mini player** — The mini player uses a backdrop blur so it reads as a floating layer above the library content.
- **Drive tiles** — Removed the dark scrim over undownloaded Drive books; the download icon sits directly on the cover/placeholder for a lighter visual weight.

### Removed

- The old filter chip row above the library grid (replaced by the Filter sheet).
- The standalone sort icon, view-toggle icon, rescan icon, history icon, and settings icon in the AppBar (consolidated into the ⋯ menu and view bar).

---

## [1.3.0] — 2026-04-19

### Added

- **Library sort menu** — New sort picker in the library AppBar with Last played, Title (A–Z), Author (A–Z), Date added, and Duration (longest first). Selection persists across launches.
- **Sleep timer indicator outside the player** — A small countdown chip appears in the library AppBar when a sleep timer is running, so you can see remaining time without opening the player. Tap it to jump back into the current book.
- **Visual feedback during cover enrichment** — Books being enriched in the background show a subtle loading indicator on their cover until the new artwork arrives.
- **Playback error recovery** — Playback errors now surface a toast with a retry action instead of silently failing.
- **Startup loading labels** — The initial library scan screen now labels what it's doing (scanning folder, syncing Drive, etc.) so long waits aren't opaque.

### Changed

- **Combined search + filter empty state** — When a search query and a status filter both return nothing, the empty state names both constraints and offers a single "Clear filters" action.
- **Drive sign-in logs** — User email is no longer included in debug logs; sign-in and session-restore events log a generic status string instead.
- **Cast init errors** — Google Cast initialisation failures are now logged instead of being silently swallowed.

### Fixed

- **Library empty on launch when refresh-on-startup is off** — Previously discovered books (local and Drive) now load from cache on app open even when automatic rescan is disabled. Only the Drive network sync is skipped.

### Internal

- Extracted `PositionPersister`, `CastController`, `DriveRemovalScheduler`, and `MediaStateBroadcaster` out of `AudioVaultHandler`. PRD-12 archived.
- Extracted pure helpers from `LibraryScreen` (status filter, last-played sort, byte formatting) and `DriveDownloadManager` (queue-selection decision). Scanner recursion depth named, `unawaited` standardised, position-service status derivation DRY'd.
- 52+ new tests across Drive services, book repository, and player helpers. No behaviour change.

---

## [1.2.5] — 2026-04-16

### Added

- **Background library resync** — Existing books stay visible while a rescan runs. Local books stream into the list one by one as the scanner finds them; Drive books merge in at the end. Stale books are removed and the list re-sorts once at completion. The player remains fully accessible throughout.
- **Refresh library on startup** — New toggle in Settings (off by default). When off, the app opens instantly with no scan; tap the refresh button to scan manually. When on, a full scan runs every time the app opens.
- **Deep folder nesting** — The scanner now supports author/series grouping folders up to three levels deep (e.g. `Audiobooks / Author / Series / Book`), so libraries organised with an extra folder layer are fully indexed.
- **Book details screen** — Long-press a book to open a details sheet showing cover, title, author, format, file count, and total duration. Drive books include download/remove controls.

### Changed

- **Sync indicator** — The full-width `LinearProgressIndicator` bar is replaced by a spinning refresh icon in the AppBar, keeping the visual footprint minimal while a rescan is in progress.

### Fixed

- **Drive: cover preserved on undownload** — Removing a downloaded Drive book no longer clears its cover art in the library list.
- **Drive: stale download queue cleared on re-download** — Pending file entries from a previous failed download are removed before starting a fresh download attempt.
- **Drive: cover-only overlay** — Download progress overlay on book cards is now suppressed for cover-file events so it doesn't flash "downloaded" prematurely.
- **Drive: auto-retry failed downloads** — Individual file downloads retry up to 3 times before marking as failed; a 30-second per-chunk timeout prevents stalled transfers from blocking the queue.
- **Drive: onboarding** — Selecting only a Drive folder on first launch no longer shows "No library folder set".

---

## [1.2.0] — 2026-05-01

### Added

- **Book status tracking** — Each book is automatically tracked as Not started, In progress, or Finished. Status is derived from playback position for existing books and stored explicitly once set.
- **Status filter pills** — Horizontally scrollable filter chips at the top of the library (grid and list views) to filter by Not started, In progress, or Finished. Selecting an active pill deselects it to show all books.
- **Finished badge** — A checkmark badge appears on book covers and list tiles for finished books, alongside the existing playing indicator.
- **Drive: Remove when finished** — New toggle in Settings (Google Drive section). When enabled, downloaded audio files are deleted 1 minute after a book finishes, freeing storage while keeping the book in the library as Finished. The timer is cancelled if the user presses play within that window.
- **Disable autoplay on open** — Opening the player screen no longer auto-starts playback. A book already playing continues uninterrupted; the user controls playback explicitly.

### Changed

- `PositionService` migrated to DB schema v3, adding a `status` column to the `positions` table.

---

## [1.1.0] — 2026-04-11

### Added

- **Library search** — Tap the search icon in the library AppBar to filter books by title or author (case-insensitive, partial match). Clear button appears while typing; back arrow dismisses search and resets the list.
- **Fine-grained playback speed** — Speed chip opens a dialog with a 0.5×–3.0× slider (0.05× steps) and quick-select chips for 0.75×, 1.0×, 1.25×, 1.5×, 2.0×, 2.5×. Live preview while dragging; Cancel reverts.
- **Custom skip interval** — New "Skip interval" setting (10 / 15 / 30 / 45 / 60 s). Rewind and fast-forward buttons update to match, including notification controls.
- **Custom sleep timer** — "Custom…" option at the bottom of the sleep timer menu opens a 1–180 minute picker.

### Fixed

- **Player times blank on reopen** — Reopening the player for a paused book now shows the correct elapsed time, remaining time, and scrubber position immediately (previously all showed 0:00 until playback resumed).

### Changed

- **Auto-rescan on folder change** — Changing the audiobooks folder in Settings triggers a library rescan immediately, without needing to navigate back first.
- **Enrichment cache flush on rescan** — When "Get missing covers & metadata" is disabled, rescanning ignores previously cached enriched covers and reverts books to embedded artwork or the default icon. Re-enabling the setting restores cached covers on the next scan.

---

## [1.0.3] — 2026-04-09

### Added

- **About screen** — Accessible from the bottom of Settings. Shows app name, version, links to the AudioVault website, privacy policy, and source code, plus a full third-party licences screen.
- **Third-party licences screen** — Lists all direct open-source dependencies with SPDX badge, copyright, and expandable full licence text (verbatim where required by BSD/Apache-2.0 terms).
- **App icon** — Custom vault-door icon replaces the Flutter default, applied across all Android mipmap densities (mdpi → xxxhdpi) with adaptive foreground layer and a matching 512 × 512 Play Store asset.

### Fixed

- **`path_provider_android` pinned to 2.2.23** — Prevents `path_provider_android ≥ 2.3.x` from pulling in `jni`/`jni_flutter`, which require NDK to compile `libdartjni.so`. Without NDK the `.so` is absent from the APK and the scanner crashes at runtime.

### Dependencies

- Added `package_info_plus: ^8.0.0`
- Added `url_launcher: ^6.3.0`
- Bumped `firebase_core` → `^4.0.0`, `firebase_analytics` → `^12.0.0`, `firebase_crashlytics` → `^5.0.0`
- Bumped `flutter_lints` → `^6.0.0`
- `path_provider_android` held at `2.2.23` via `dependency_overrides`

---

## [1.0.2] — 2026-04-08

### Added

- **Smart rewind on resume** — Playback automatically rewinds when you resume after a break: 10 s after 5 min, 15 s after 1 hour, 30 s after 24 hours. Toggleable via a new "Smart rewind on resume" switch in Settings (on by default).
- **Full Cast playback routing** — All playback controls (play, pause, seek, chapter skip, rewind, fast-forward, speed) now route to the Cast device when a Cast session is active. Previously only load/connect was wired up; everything else still drove local playback.
- **VPN warning in Cast picker** — A warning banner is shown in the Cast device picker when a VPN connection is detected, as VPNs routinely prevent Cast discovery and streaming.
- **`CastServer`** — Lightweight on-device HTTP server (with HTTP Range support) that serves local audio files over the LAN so Cast devices can stream them directly.
- **`effectivePositionStream` / `effectiveDurationStream`** — New streams on `AudioVaultHandler` that transparently emit local or Cast position/duration depending on the active playback mode. All UI that previously read `player.positionStream` now reads these.
- **`TelemetryService.logEvent`** — Static helper for logging custom Firebase Analytics events; no-ops when Firebase is unavailable.
- **`get_it` service locator** — Services (`PositionService`, `PreferencesService`, `ScannerService`, `EnrichmentService`) are now registered as lazy singletons via `get_it` and resolved through `locator.dart`, enabling proper DI for testing.
- **Unit tests** — Tests for `AudioVaultHandler` (rewind offsets, global position calculation) and `ScannerService`.

### Fixed

- **Chapter index off-by-one at boundaries** — The chapter elapsed/remaining time display now uses the raw playback position for chapter lookup instead of a second-snapped value, preventing a ~1 s window where the previous chapter was shown right after crossing a chapter boundary.
- **Mini player position during Cast** — Mini player progress and remaining-time label now use `effectivePositionStream` and skip `player.currentIndex` when casting.
- **Hidden files and folders excluded from scan** — The library scanner now ignores files and directories whose names start with `.` (e.g. `.DS_Store`, `.Spotlight-V100`).

### Changed

- Service singletons (`PositionService`, `PreferencesService`, `ScannerService`, `EnrichmentService`) converted from factory constructors to `get_it` lazy singletons; singleton factories removed from the service classes themselves.
- `_globalPositionMs()` refactored into a public static `calculateGlobalPosition()` method (`@visibleForTesting`) for unit testability.
- Firebase is now initialized with `DefaultFirebaseOptions.currentPlatform` from the generated `firebase_options.dart`.

### Dependencies

- Added `get_it: ^9.2.1`
- Added `mockito: ^5.6.4` (dev)
- Added `build_runner: ^2.13.1` (dev)

---

## [1.0.1] — 2026-04-06

### Added

- **Google Cast support** — Cast button in the player AppBar opens a device picker to start or stop casting to nearby Google Cast devices.
- **Chapter list for M4B books** — Single-file M4B audiobooks with embedded QuickTime chapter tracks now display a tappable "Chapter X of Y" label and a navigable chapter list sheet, matching the existing experience for multi-file MP3 books.
- **Light/dark/system theme** — Color mode setting (Follow system / Light / Dark), persisted and applied live without restarting the app. Theme is read before the first frame to avoid a flash on launch.
- **Metadata enrichment** — New `EnrichmentService` fetches missing cover art from [Open Library](https://openlibrary.org) in the background after a library scan. Covers are downloaded to the app cache and persisted in a separate SQLite database (`audiovault_enrichment.db`). Already-enriched books are skipped; failed lookups are retried no more than once per day.
- **"Get missing covers & metadata" toggle** — Settings switch (enabled by default) to start or stop background enrichment. Turning it off immediately cancels any in-progress queue.
- **`Audiobook.copyWith`** — Immutable helper on the `Audiobook` model for updating `coverImagePath` or `coverImageBytes` without recreating the full object.
- **`BookCover` widget** — Shared widget for rendering cover art (image or placeholder icon), replacing duplicated `_cover`/`_placeholder` methods across five files.
- **`AudioHandlerScope` InheritedWidget** — Provides `audioHandler` and `themeModeNotifier` via the widget tree, replacing the top-level global variable.

### Fixed

- **Chapter time labels** — The time display below the player progress bar now shows elapsed and remaining time within the current chapter (`mm:ss` / `-mm:ss`) rather than the global book position and total duration. Both labels update in lock-step on the same second boundary.
- **M4B chapter parsing** — Single-file M4B audiobooks with QuickTime chapter tracks (iTunes/Audible format) now correctly parse and display chapter information. `co64` (64-bit chunk offsets) is also supported for future-proofing.
- **Natural file sort** — Audio files inside a folder are now sorted by the natural numeric order of their filenames (e.g. `2.mp3 < 10.mp3 < 100.mp3`) instead of lexicographic order, fixing chapter sequencing for multi-file audiobooks.
- **Audio stream error handling** — Added `onError` callbacks to `playbackEventStream` and `currentIndexStream` listeners so playback errors are logged rather than silently swallowed.
- **Sleep timer off-by-one** — Timer now decrements before checking the zero threshold, so a 5-minute timer runs for exactly 5 minutes.
- **Mini player progress** — Fixed mini player progress bar showing per-file progress instead of global book progress for multi-file audiobooks.
- **History screen unreachable** — Wired up the history button in the library AppBar; the screen was fully implemented but had no navigation path.
- **Playback completion** — Position is now saved when `processingState` reaches `completed`, so resume works correctly after finishing a book.
- **M4B notification chapter count** — Fixed notification metadata reporting 1 chapter (the file count) instead of the actual embedded chapter count.

### Changed

- **Settings screen redesigned** — Each setting now uses an icon + title + current-value subtitle layout. Color mode opens a dialog picker (icon, label, and checkmark for the active selection). Section groups are separated by plain dividers with no header labels.
- `chapterIndexAt` logic moved from `AudioVaultHandler` and `PlayerScreen` into the `Audiobook` model to eliminate duplication.
- `PreferencesService` is now a proper singleton with a cached `SharedPreferences` instance.
- `PreferencesService` gains `getThemeMode` / `setThemeMode` and `getMetadataEnrichment` / `setMetadataEnrichment` methods.
- Position is saved on `stop()` to prevent losing progress when the OS kills the audio service.
- Library scan now applies previously cached covers immediately (before enrichment runs) so the UI is populated from the first render.
- Completed PRDs moved to `prd/done/`.

### Dependencies

- Added `http: ^1.2.0` for Open Library API requests.

---

## [1.0.0] — 2025

Initial release.

- Audiobook library scanner (folder-based, M4B/MP3/FLAC/etc.)
- Full-screen player with chapter list and progress scrubbing
- Mini player in library grid/list view
- Resume playback from last position (SQLite persistence)
- Sort library by last played / alphabetical
- Firebase Analytics & Crashlytics (opt-in, consent gate)
- Android: `MANAGE_EXTERNAL_STORAGE` for full file system access
