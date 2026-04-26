# Code Review — 2026-04-26

Full-codebase service review. Items grouped by category, each with rationale, priority, and outline implementation plan. Priority scale matches existing PRD convention: **P1** (must fix soon), **P2** (should fix), **P3** (nice to have), **P4** (deferred).

---

## Bugs

### B1 — Cast bookmark records local position instead of cast position ✅
- **Location:** `lib/screens/player_screen.dart:369-371`
- **Rationale:** Both branches of the ternary read `_audioHandler.player.position`. Bookmarks added while casting capture the (stale) local player position, not the actual playback point on the cast device. User-visible data corruption in a niche but real flow.
- **Priority:** P1
- **Plan:**
  1. Replace the ternary with `_audioHandler.isCasting ? _cast.position : _audioHandler.player.position` (or read from `effectivePositionStream`'s latest value via `MediaStateBroadcaster`).
  2. Add a unit test that verifies bookmark position when `isCasting == true` returns the cast controller's position.
  3. Manually verify by casting, scrubbing, then bookmarking.

### B2 — `hasWriteScope` triggers interactive consent ✅
- **Location:** `lib/services/drive_service.dart:264-271`
- **Rationale:** Method body is identical to `requestWriteScope()`. Doc comment says "Returns true if the write scope has already been granted," but the implementation calls `requestScopes()` which shows the consent UI. Any caller using this as a passive check will surprise the user with an OAuth prompt.
- **Priority:** P1
- **Plan:**
  1. Replace body with a non-interactive check: inspect `_signIn.currentUser?.serverAuthCode` / cached granted scopes, or use `canAccessScopes` API.
  2. Audit all call sites; some that today pre-prompt may need to be updated to call `requestWriteScope` explicitly.
  3. Add unit test with a mocked `GoogleSignIn` confirming no `requestScopes` call when scope already cached.

### B3 — Drive query injection via unescaped names ✅
- **Location:** `lib/services/drive_service.dart:281, 310, 342` (and similar)
- **Rationale:** Drive API `q` parameter strings interpolate user-controlled folder/file names directly. A folder named `it's mine` produces a malformed query and the operation fails or, worse, matches unintended objects. Not a security concern (own Drive only), but a correctness/UX one.
- **Priority:** P2
- **Plan:**
  1. Add a private `_escapeQ(String s) => s.replaceAll(r"\", r"\\").replaceAll("'", r"\'")` helper.
  2. Wrap every interpolation of a user-supplied string inside a `q=` param.
  3. Add unit tests: folders with `'`, `\`, and unicode names round-trip correctly.

### B4 — `setBookStatus` silently wipes saved position ✅
- **Location:** `lib/services/position_service.dart:153-168`
- **Rationale:** Public method writes `position_ms = 0, chapter_index = 0` alongside status. Any future caller (or refactor) that calls it on a book with progress destroys that progress. Currently mitigated only by `updateBookStatus`'s read-modify-write pattern, but the footgun remains.
- **Priority:** P2
- **Plan:**
  1. Either rename to `_resetBookWithStatus` and make private, OR change implementation to UPSERT only the `status` column (preserve existing position).
  2. Update `updateBookStatus` to call the new safe method.
  3. Add a regression test: `setBookStatus` on a book with non-zero position must not zero it.

### B5 — `enqueueBooks` silently drops concurrent calls ✅
- **Location:** `lib/services/enrichment_service.dart:122-150`
- **Rationale:** `if (_processing) return;` early-exits when a previous batch is still running. Books discovered mid-scan never get covers until the next app launch.
- **Priority:** P2
- **Plan:**
  1. Replace the boolean guard with an append-to-pending-queue pattern.
  2. After current iteration completes, drain the pending queue.
  3. Add test: enqueue, then enqueue again before the first finishes, assert all books processed.

### B6 — Cast stop reads pre-seek local position
- **Location:** `lib/services/cast_controller.dart:207-209`
- **Rationale:** After `localPlayer.seek(castPosition)`, the code immediately reads `localPlayer.position` and emits it to listeners. `seek` is async; the read may return the position before the seek lands, briefly showing a wrong position when transitioning cast → local.
- **Priority:** P3
- **Plan:**
  1. Either await the seek's effect (listen for first `positionStream` event after seek completes) or skip the immediate emit (let the next stream event broadcast the correct value).
  2. Add a fake-timer test that seeds a delayed positionStream and asserts no stale emission.

### B7 — `setState` after `await` without `mounted` check ✅
- **Location:** `lib/main.dart:202-236`, `lib/screens/onboarding_screen.dart:46-78`, `lib/screens/library_screen.dart:329-345`, others
- **Rationale:** Pattern repeats across screens. On fast unmount (e.g. user backs out during scan/sign-in) Flutter throws and a crash is logged to Crashlytics. Easy mechanical fix.
- **Priority:** P2
- **Plan:**
  1. Grep for `await` followed by `setState` within `State` subclasses.
  2. Add `if (!mounted) return;` after each await.
  3. Consider a custom `safeSetState` extension on `State` to make the pattern obvious.

### B8 — Null-bang on `driveMetadata!` with no guard
- **Location:** `lib/screens/book_details_screen.dart:181-191`
- **Rationale:** `widget.book.driveMetadata!` in `initState`. If a book is constructed with `source == drive` but null metadata (boundary error in Drive sync paths), the screen NPEs before painting.
- **Priority:** P3
- **Plan:**
  1. Add an early `if (widget.book.driveMetadata == null) { ... show error / pop ... }` guard.
  2. Consider modeling `Audiobook` so `source == drive` implies non-null metadata at the type level (sealed class or factory constructor).

---

## DRY / Refactors

### D1 — Extract `_EnrichmentAwareCover` to its own widget ✅
- **Location:** `lib/widgets/audiobook_card.dart:149-189`, `lib/widgets/audiobook_list_tile.dart:155-194`
- **Rationale:** Verbatim duplicate. Any future cover-enrichment behavior change has to land in two files; one will inevitably be missed.
- **Priority:** P2
- **Plan:**
  1. Create `lib/widgets/enrichment_aware_cover.dart` as a public widget.
  2. Delete the private copies, import the new widget in both files.
  3. Add a widget test (none currently exist for this).

### D2 — Replace ad-hoc duration formatters with `fmtHM`
- **Location:** `audiobook_list_tile.dart:145-150`, `book_details_screen.dart:148-153`, `player_screen.dart:323-329`, `mini_player.dart:166-171`
- **Rationale:** Four near-identical helpers. `lib/utils/formatters.dart` already exports `fmtHM`. Pure cleanup.
- **Priority:** P3
- **Plan:**
  1. Delete each `_formatDuration` / `_fmtRemaining` / `_fmtOverallRemaining`.
  2. Replace call sites with `fmtHM(duration)`.
  3. If sign/format differs (e.g. negative durations), extend `fmtHM` rather than duplicating.

### D3 — Consolidate chapter-start summation ✅
- **Location:** `mini_player.dart:52-57, 158-160`, `player_screen.dart:656-660` and `_BookmarksSheet:951-957`, `book_details_screen.dart:549-555`
- **Rationale:** `position_persister.dart` already has `calculateGlobalPosition`. The same arithmetic exists in 5 widgets.
- **Priority:** P3
- **Plan:**
  1. Confirm `calculateGlobalPosition` signature covers all four call sites.
  2. Replace inline math with the helper.
  3. Test parity by snapshotting current outputs before/after.

### D4 — Deduplicate `_chapterStartMs`
- **Location:** `player_screen.dart` (`_BookmarksSheet`) and `book_details_screen.dart` (`_BookmarksSection._jumpTo`)
- **Rationale:** Two private copies of the same chapter-start lookup.
- **Priority:** P3
- **Plan:**
  1. Add `chapterStartMs(Audiobook, int)` to `lib/utils/formatters.dart` (or a new `chapter_math.dart`).
  2. Replace both copies; covered by D3 if folded together.

### D5 — Replace `cast<T?>().firstWhere(orElse: () => null)` with `firstWhereOrNull` ✅
- **Location:** `library_screen.dart:517-520, 567-570`, `book_details_screen.dart:321-324`
- **Rationale:** Idiomatic Dart since `package:collection`. Three sites.
- **Priority:** P4
- **Plan:**
  1. Add `package:collection` to `pubspec.yaml` if not already pulled in transitively (check first).
  2. Import `package:collection/collection.dart`.
  3. Replace the pattern.

### D6 — Share natural-sort algorithm
- **Location:** `scanner_service.dart:413-431` (`_naturalSort`), `drive_service.dart:384-413` (`_naturalCompare`)
- **Rationale:** Same algorithm operating on different element types. Risk of divergence (sort orders differ between local and Drive views).
- **Priority:** P3
- **Plan:**
  1. Add `int naturalCompare(String a, String b)` to a new `lib/utils/natural_sort.dart`.
  2. Both services call the shared comparator with a key extractor.
  3. Single test file covering numeric runs, leading zeros, locale.

### D7 — Share cover-priority selection
- **Location:** `scanner_service.dart:397-409`, `drive_service.dart:366-378`
- **Rationale:** Same priority list (`cover.jpg` > `cover.png` > first image > …) implemented twice.
- **Priority:** P3
- **Plan:**
  1. Extract a generic `T? pickBestCover<T>(Iterable<T>, String Function(T) name)` to `lib/utils/cover_picker.dart`.
  2. Replace both call sites.

### D8 — Single `StreamBuilder` in MiniPlayer
- **Location:** `lib/widgets/mini_player.dart:38, 108`
- **Rationale:** Two nested StreamBuilders subscribe to the same `effectivePositionStream`, doubling rebuild cost (~5 fps becomes ~10 fps of work).
- **Priority:** P3
- **Plan:**
  1. Hoist a single outer `StreamBuilder` whose builder passes `position` down.
  2. Verify with the Flutter inspector that rebuild count halves.

### D9 — Delete unused `CacheManager`
- **Location:** `lib/services/cache_manager.dart` and `test/services/cache_manager_test.dart`
- **Rationale:** 220 lines of code never imported anywhere. Confirmed via grep. Carries a maintenance cost (compiled, linted, tested) for zero runtime value.
- **Priority:** P2
- **Plan:**
  1. `git rm lib/services/cache_manager.dart test/services/cache_manager_test.dart`.
  2. Run `flutter analyze` and `flutter test` to confirm nothing breaks.

### D10 — Wire up or remove `_scanStatus` label
- **Location:** `lib/screens/library_screen.dart:240, 351`
- **Rationale:** Field is set once to "Scanning your library…" and never updated, despite the changelog (1.3.0) advertising "Startup loading labels". Either dead UI or an unfinished feature.
- **Priority:** P3
- **Plan:**
  1. Decide: restore the staged labels (Scanning → Reading metadata → Syncing Drive → Fetching covers) OR remove the field and `_DriveScanOverlay` parameter.
  2. If restoring, set the label at each phase boundary in `_scan()`.
  3. If removing, drop the field and simplify the overlay.

---

## Performance / Hardening

### H1 — Cache prefs reads in `audio_handler` ✅
- **Location:** `lib/services/audio_handler.dart:342-363` (`fastForward`/`rewind`), `:236-267` (`play()`)
- **Rationale:** Every skip-button tap awaits `getSkipInterval()`/`getAutoRewind()` from SharedPreferences. Cheap, but adds latency to every gesture and creates a settings-vs-action race.
- **Priority:** P3
- **Plan:**
  1. Cache values in fields, refreshed on app start and when settings change.
  2. Have `SettingsScreen` notify the handler (via existing `PreferencesService` or a stream) when values change.
  3. Test that updating settings while playing changes the next skip interval.

### H2 — `flutter pub upgrade` dry-run for safe minor bumps
- **Rationale:** Several deps have low-risk patches available (`http`, `xml`, `sqflite`, `get_it`, `package_info_plus`, `url_launcher`, `connectivity_plus`, `just_audio`, `audio_service`).
- **Priority:** P3
- **Plan:**
  1. `flutter pub upgrade --dry-run` to list candidates.
  2. Bump in one branch; run `flutter analyze --fatal-warnings` and `flutter test`.
  3. Smoke test the app: scan, play, cast, Drive sync.

### H3 — Upgrade `google_sign_in` to 7.x
- **Location:** `lib/services/drive_service.dart` throughout
- **Rationale:** v6 is two majors behind. `signInSilently` (used at L87) is deprecated. v7 restructures auth flow significantly.
- **Priority:** P2 (defer until a Drive-touching release window)
- **Plan:**
  1. Read 6→7 migration guide; map deprecated APIs.
  2. Update `_signIn` setup, silent-sign-in, scope-request flows.
  3. Re-test full Drive flow end to end on Android (and iOS if relevant).
  4. There's already `prd-22-P2-unpin-path-provider-android.md` — consider bundling the dep work.

### H4 — `path_provider_android` unpin re-check
- **Location:** `pubspec.yaml:47-54`
- **Rationale:** Existing tracked workaround. Worth periodically retesting with current Flutter NDK.
- **Priority:** P3 (already tracked by PRD-22)
- **Plan:** Already covered — see [prd-22-P2-unpin-path-provider-android.md](PRD/prd-22-P2-unpin-path-provider-android.md).

### H5 — Defer non-critical startup work past first frame
- **Location:** `lib/main.dart:96-105`
- **Rationale:** `getAllPositions()` for Drive sync runs before UI shows. Could be deferred to first-frame callback to cut TTI on cold start.
- **Priority:** P4
- **Plan:**
  1. Move Drive position-restore inside `WidgetsBinding.instance.addPostFrameCallback`.
  2. Measure cold-start timing before/after.

---

## Suggested execution order

1. **B1, B2** (P1 bugs) — small, isolated, high impact
2. **D9** (delete dead `CacheManager`) — instant cleanup, reduces noise
3. **B3, B4, B5, B7, D1, H3** (P2 batch) — bug fixes + refactor groundwork
4. **B6, B8, D2–D8, D10, H1, H5** (P3/P4 polish) — pick up opportunistically as related screens are touched
5. **H2** — once weekly/monthly hygiene task, not gated on the above
