import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:audiovault/models/audiobook.dart';
import 'package:audiovault/services/position_backup_service.dart';
import 'package:audiovault/services/position_service.dart';
import 'package:audiovault/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<PositionService> _makePositionService() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 4,
      singleInstance: false,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE positions (
            book_path TEXT PRIMARY KEY,
            chapter_index INTEGER NOT NULL DEFAULT 0,
            position_ms INTEGER NOT NULL DEFAULT 0,
            global_position_ms INTEGER NOT NULL DEFAULT 0,
            total_duration_ms INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL,
            status TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE bookmarks (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            book_path    TEXT NOT NULL,
            chapter_index INTEGER NOT NULL,
            position_ms  INTEGER NOT NULL,
            label        TEXT NOT NULL,
            notes        TEXT,
            created_at   INTEGER NOT NULL
          )
        ''');
      },
    ),
  );
  return PositionService.withDatabase(db);
}

void _setupLocator(PositionService svc) {
  final locator = GetIt.instance;
  if (locator.isRegistered<PositionService>()) locator.unregister<PositionService>();
  if (locator.isRegistered<PreferencesService>()) locator.unregister<PreferencesService>();
  locator.registerSingleton<PositionService>(svc);
  locator.registerSingleton<PreferencesService>(PreferencesService());
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('PositionBackupService path helpers', () {
    test('toRelative strips root prefix', () {
      expect(
        PositionBackupService.toRelativeForTesting(
            '/storage/books/Author/Book', '/storage/books'),
        'Author/Book',
      );
    });

    test('toRelative returns path unchanged when not under root', () {
      expect(
        PositionBackupService.toRelativeForTesting(
            '/other/path/Book', '/storage/books'),
        '/other/path/Book',
      );
    });

    test('toAbsolute joins root and relative path', () {
      expect(
        PositionBackupService.toAbsoluteForTesting(
            'Author/Book', '/storage/books'),
        '/storage/books/Author/Book',
      );
    });

    test('toAbsolute returns absolute path unchanged', () {
      expect(
        PositionBackupService.toAbsoluteForTesting(
            '/storage/books/Author/Book', '/storage/books'),
        '/storage/books/Author/Book',
      );
    });
  });

  group('PositionBackupService export/import', () {
    late Directory tempDir;
    late PositionService svc;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_test_');
      svc = await _makePositionService();
      _setupLocator(svc);
    });

    tearDown(() async {
      try { await tempDir.delete(recursive: true); } catch (_) {}
    });

    test('exportToJson writes valid JSON with relative paths', () async {
      final root = tempDir.path.replaceAll('\\', '/');
      await svc.savePosition(
        bookPath: '$root/Author/Book',
        chapterIndex: 2,
        position: const Duration(seconds: 30),
        globalPositionMs: 30000,
        totalDurationMs: 3600000,
      );

      final backup = PositionBackupService();
      await backup.exportToJson(root);

      final file = File('${tempDir.path}/positions.json');
      expect(await file.exists(), isTrue);

      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(data['version'], 1);
      final positions = data['positions'] as List;
      expect(positions.length, 1);
      expect(positions.first['book_path'], 'Author/Book');
      expect(positions.first['global_position_ms'], 30000);
    });

    test('importFromJson applies newer entries', () async {
      final root = tempDir.path.replaceAll('\\', '/');
      final absPath = '$root/Author/Book';

      final json = jsonEncode({
        'version': 1,
        'exported_at': 0,
        'positions': [
          {
            'book_path': 'Author/Book',
            'global_position_ms': 60000,
            'total_duration_ms': 3600000,
            'status': 'inProgress',
            'updated_at': 9999999,
          }
        ],
      });
      await File('${tempDir.path}/positions.json').writeAsString(json);

      final backup = PositionBackupService();
      await backup.importFromJson(root);

      final positions = await svc.getAllPositions();
      expect(positions.length, 1);
      expect(positions.first.bookPath, absPath);
      expect(positions.first.globalPositionMs, 60000);
    });

    test('importFromJson skips entries where local updated_at is newer', () async {
      final root = tempDir.path.replaceAll('\\', '/');
      final absPath = '$root/Author/Book';

      await svc.savePosition(
        bookPath: absPath,
        chapterIndex: 3,
        position: const Duration(seconds: 90),
        globalPositionMs: 90000,
        totalDurationMs: 3600000,
      );
      final localPositions = await svc.getAllPositions();
      final localUpdatedAt = localPositions.first.updatedAt;

      final json = jsonEncode({
        'version': 1,
        'exported_at': 0,
        'positions': [
          {
            'book_path': 'Author/Book',
            'global_position_ms': 1000,
            'total_duration_ms': 3600000,
            'status': 'notStarted',
            'updated_at': localUpdatedAt - 1000,
          }
        ],
      });
      await File('${tempDir.path}/positions.json').writeAsString(json);

      final backup = PositionBackupService();
      await backup.importFromJson(root);

      final positions = await svc.getAllPositions();
      expect(positions.first.globalPositionMs, 90000);
    });

    test('round-trip: export then import leaves positions unchanged', () async {
      final root = tempDir.path.replaceAll('\\', '/');
      await svc.savePosition(
        bookPath: '$root/Author/Book',
        chapterIndex: 1,
        position: const Duration(seconds: 45),
        globalPositionMs: 45000,
        totalDurationMs: 7200000,
      );

      final backup = PositionBackupService();
      await backup.exportToJson(root);

      final svc2 = await _makePositionService();
      _setupLocator(svc2);
      await backup.importFromJson(root);

      final positions = await svc2.getAllPositions();
      expect(positions.length, 1);
      expect(positions.first.globalPositionMs, 45000);
      expect(positions.first.totalDurationMs, 7200000);
    });

    test('importFromJson with malformed JSON does not throw', () async {
      final root = tempDir.path.replaceAll('\\', '/');
      await File('${tempDir.path}/positions.json').writeAsString('not valid json {{{{');

      final backup = PositionBackupService();
      await expectLater(backup.importFromJson(root), completes);

      expect(await svc.getAllPositions(), isEmpty);
    });

    test('importFromJson with missing file is a no-op', () async {
      final root = tempDir.path.replaceAll('\\', '/');
      final backup = PositionBackupService();
      await expectLater(backup.importFromJson(root), completes);
      expect(await svc.getAllPositions(), isEmpty);
    });
  });
}
