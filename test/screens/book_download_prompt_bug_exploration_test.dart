/// Bug condition exploration tests for book-download-prompt-fixes.
///
/// **Validates: Requirements 1.1, 1.2, 1.3**
///
/// These tests encode the EXPECTED (correct) behavior.
/// They are intentionally written to FAIL on unfixed code — failure confirms
/// the bugs exist. They will pass once the fix is implemented.
///
/// Bug A — WiFi file size missing:
///   `_showDriveDownloadSheet` in library_screen.dart only fetches
///   `totalSizeBytes` when `!isWifi`. On WiFi the size is skipped, so the
///   prompt shows a generic message and an unlabelled "Download" button.
///
///   On unfixed code, `lib/utils/drive_download_sheet.dart` does not exist,
///   so this file will fail to compile — that compile failure IS the
///   counterexample confirming Bug A.
///
/// Bug B — "Start listening" bypasses download prompt:
///   The FilledButton in _ActionButtonsState.build calls
///   Navigator.pushReplacement unconditionally, regardless of whether the
///   Drive book has been downloaded.
///
/// EXPECTED OUTCOME: All tests FAIL on unfixed code (this is correct).
/// EXPECTED OUTCOME: All tests PASS after the fix is implemented.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:audiovault/locator.dart';
import 'package:audiovault/models/audiobook.dart';
import 'package:audiovault/screens/book_details_screen.dart';
import 'package:audiovault/screens/player_screen.dart';
import 'package:audiovault/services/drive_book_repository.dart';
import 'package:audiovault/services/drive_download_manager.dart';
import 'package:audiovault/services/drive_library_service.dart';
import 'package:audiovault/services/position_service.dart';

// NOTE: This import targets the future extracted utility file.
// On unfixed code this file does not exist → compile error → confirms Bug A.
import 'package:audiovault/utils/drive_download_sheet.dart';

import 'book_download_prompt_bug_exploration_test.mocks.dart';

// ---------------------------------------------------------------------------
// Mock generation
// ---------------------------------------------------------------------------

@GenerateMocks([
  DriveLibraryService,
  DriveBookRepository,
  DriveDownloadManager,
  PositionService,
])

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Stubs the connectivity_plus platform channel to return [results].
///
/// `connectivity_plus` uses the `dev.fluttercommunity.plus/connectivity`
/// method channel. We stub `check` to return the encoded connectivity list
/// so that `Connectivity().checkConnectivity()` returns [results] in tests.
void _stubConnectivity(List<ConnectivityResult> results) {
  final encoded = results.map((r) => r.name).toList();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (MethodCall call) async {
      if (call.method == 'check') {
        return encoded;
      }
      return null;
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Shared test fixtures ──────────────────────────────────────────────────

  /// An undownloaded Drive book: source=drive, audioFiles empty, 3 files in Drive.
  /// totalSizeBytes for folderId 'folder-123' is stubbed to 257,363,968 bytes
  /// ≈ 245.3 MB.
  const undownloadedDriveBook = Audiobook(
    title: 'Test Drive Book',
    path: '/drive/test-drive-book',
    audioFiles: [],
    source: AudiobookSource.drive,
    driveMetadata: DriveBookMeta(
      folderId: 'folder-123',
      folderName: 'Test Drive Book',
      isShared: false,
      totalFileCount: 3,
    ),
  );

  // ── Service mocks ─────────────────────────────────────────────────────────

  late MockDriveLibraryService mockDriveLibraryService;
  late MockDriveBookRepository mockDriveBookRepository;
  late MockDriveDownloadManager mockDriveDownloadManager;
  late MockPositionService mockPositionService;

  setUp(() {
    mockDriveLibraryService = MockDriveLibraryService();
    mockDriveBookRepository = MockDriveBookRepository();
    mockDriveDownloadManager = MockDriveDownloadManager();
    mockPositionService = MockPositionService();

    // DriveDownloadManager.downloadEvents must return a stream (used by
    // _ActionButtonsState.initState).
    when(mockDriveDownloadManager.downloadEvents)
        .thenAnswer((_) => const Stream.empty());

    // DriveBookRepository.getFilesForBook returns empty list (no files
    // downloaded yet) — this is the bug condition for Bug B.
    when(mockDriveBookRepository.getFilesForBook(any))
        .thenAnswer((_) async => []);

    // totalSizeBytes returns a known value (257,363,968 bytes ≈ 245.3 MB).
    when(mockDriveLibraryService.totalSizeBytes(any))
        .thenAnswer((_) async => 257363968);

    // PositionService.getBookmarks returns empty list (no bookmarks).
    when(mockPositionService.getBookmarks(any))
        .thenAnswer((_) async => []);

    // Register mocks in the service locator.
    locator.allowReassignment = true;
    locator.registerLazySingleton<DriveLibraryService>(
        () => mockDriveLibraryService);
    locator.registerLazySingleton<DriveBookRepository>(
        () => mockDriveBookRepository);
    locator.registerLazySingleton<DriveDownloadManager>(
        () => mockDriveDownloadManager);
    locator.registerLazySingleton<PositionService>(
        () => mockPositionService);
  });

  tearDown(() async {
    locator.allowReassignment = true;
    if (locator.isRegistered<DriveLibraryService>()) {
      await locator.unregister<DriveLibraryService>();
    }
    if (locator.isRegistered<DriveBookRepository>()) {
      await locator.unregister<DriveBookRepository>();
    }
    if (locator.isRegistered<DriveDownloadManager>()) {
      await locator.unregister<DriveDownloadManager>();
    }
    if (locator.isRegistered<PositionService>()) {
      await locator.unregister<PositionService>();
    }
  });

  // ── Bug A: WiFi file size missing ─────────────────────────────────────────
  //
  // On unfixed code, `_showDriveDownloadSheet` skips the `totalSizeBytes`
  // fetch when `isWifi == true`, so `sizeBytes` is null and the sheet shows
  // a generic message with no size. These tests assert the CORRECT behavior
  // (size IS shown on WiFi) and therefore FAIL on unfixed code.
  //
  // Additionally, on unfixed code `lib/utils/drive_download_sheet.dart` does
  // not exist, so this file fails to compile — that is the primary
  // counterexample for Bug A.

  group('Bug A — WiFi file size missing', () {
    /// Pumps a minimal app that calls [showDriveDownloadSheet] with WiFi
    /// connectivity stubbed, then waits for the bottom sheet to appear.
    Future<void> pumpSheetOnWifi(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showDriveDownloadSheet(
                  context,
                  undownloadedDriveBook,
                  // Stub connectivity as WiFi so the bug condition is met.
                  connectivityOverride: [ConnectivityResult.wifi],
                );
              });
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );
      // Let the post-frame callback fire and the async sheet logic complete.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets(
      'bottom sheet contains a formatted size string on WiFi '
      '(fails on unfixed code — Bug A)',
      (tester) async {
        await pumpSheetOnWifi(tester);

        // The sheet must contain a formatted size string like "245.3 MB".
        // On unfixed code sizeBytes is null on WiFi, so no size is shown.
        expect(
          find.textContaining(RegExp(r'\d+(\.\d+)?\s*(B|KB|MB|GB)')),
          findsAtLeastNWidgets(1),
          reason:
              'Expected the bottom sheet to display a formatted file size '
              '(e.g. "245.3 MB") on WiFi, but no size string was found. '
              'Counterexample: sizeBytes is null on WiFi path → size string '
              'absent from sheet. This confirms Bug A.',
        );
      },
    );

    testWidgets(
      '"Download" button label includes formatted size on WiFi '
      '(fails on unfixed code — Bug A)',
      (tester) async {
        await pumpSheetOnWifi(tester);

        // The Download button must read "Download (245.3 MB)" or similar.
        // On unfixed code the button reads just "Download" on WiFi.
        expect(
          find.textContaining(RegExp(r'Download\s*\(\d+(\.\d+)?\s*(B|KB|MB|GB)\)')),
          findsOneWidget,
          reason:
              'Expected the Download button label to include the formatted '
              'file size (e.g. "Download (245.3 MB)") on WiFi, but the '
              'button showed no size annotation. '
              'Counterexample: sizeBytes is null on WiFi path → button label '
              'reads "Download" with no size. This confirms Bug A.',
        );
      },
    );
  });

  // ── Bug B: "Start listening" bypasses download prompt ────────────────────
  //
  // On unfixed code, the FilledButton in _ActionButtonsState.build calls
  // Navigator.pushReplacement unconditionally. For an undownloaded Drive
  // book this pushes PlayerScreen instead of showing the download sheet.
  // This test asserts the CORRECT behavior (sheet IS shown, PlayerScreen is
  // NOT pushed) and therefore FAILS on unfixed code.

  group('Bug B — "Start listening" bypasses download prompt', () {
    testWidgets(
      '"Start listening" shows download sheet (not PlayerScreen) for '
      'undownloaded Drive book (fails on unfixed code — Bug B)',
      (tester) async {
        // Stub connectivity so Connectivity().checkConnectivity() resolves
        // immediately in the test environment (avoids platform channel issues).
        _stubConnectivity([ConnectivityResult.wifi]);

        await tester.pumpWidget(
          MaterialApp(
            home: BookDetailsScreen(book: undownloadedDriveBook),
          ),
        );

        // Wait for _ActionButtonsState.initState async work to complete.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Tap "Start listening".
        final startListeningButton = find.text('Start listening');
        expect(startListeningButton, findsOneWidget,
            reason: 'Could not find the "Start listening" button.');
        await tester.tap(startListeningButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        // CORRECT behavior: PlayerScreen is NOT pushed.
        expect(
          find.byType(PlayerScreen),
          findsNothing,
          reason:
              'Expected PlayerScreen NOT to be pushed when tapping '
              '"Start listening" on an undownloaded Drive book, but '
              'PlayerScreen was found in the widget tree. '
              'Counterexample: Navigator.pushReplacement is called '
              'immediately → PlayerScreen appears instead of the download '
              'sheet. This confirms Bug B.',
        );

        // CORRECT behavior: the download sheet IS shown.
        expect(
          find.byType(BottomSheet),
          findsOneWidget,
          reason:
              'Expected the download bottom sheet to appear after tapping '
              '"Start listening" on an undownloaded Drive book, but no '
              'BottomSheet was found. '
              'Counterexample: Navigator.pushReplacement is called '
              'unconditionally → no sheet is shown. This confirms Bug B.',
        );
      },
    );
  });
}
