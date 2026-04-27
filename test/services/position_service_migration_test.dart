import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kowhai/services/position_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v3 → v4 migration: bookmarks table created, positions data intact',
      () async {
    // Use a named temp file so we can close and re-open at a different version.
    const dbPath = 'migration_test_v3_to_v4.db';
    await databaseFactoryFfi.deleteDatabase(dbPath);

    // Build a v3 database with sample positions data.
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3,
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
        },
      ),
    );

    // Insert sample positions data at v3.
    await db.insert('positions', {
      'book_path': '/books/my-book',
      'chapter_index': 2,
      'position_ms': 45000,
      'global_position_ms': 120000,
      'total_duration_ms': 3600000,
      'updated_at': 1000000,
      'status': null,
    });
    await db.close();

    // Re-open at v4 — this triggers onUpgrade which adds the bookmarks table.
    final upgraded = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        singleInstance: false,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 4) {
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
            await db.execute(
                'CREATE INDEX idx_bookmarks_book_path ON bookmarks(book_path)');
          }
        },
      ),
    );

    // Positions data is intact.
    final positions = await upgraded.query('positions');
    expect(positions.length, 1);
    expect(positions.first['book_path'], '/books/my-book');
    expect(positions.first['chapter_index'], 2);

    // Bookmarks table exists and is empty.
    final bookmarks = await upgraded.query('bookmarks');
    expect(bookmarks, isEmpty);

    // Can insert into bookmarks table.
    await upgraded.insert('bookmarks', {
      'book_path': '/books/my-book',
      'chapter_index': 2,
      'position_ms': 45000,
      'label': 'Test bookmark',
      'notes': null,
      'created_at': 2000000,
    });
    final afterInsert = await upgraded.query('bookmarks');
    expect(afterInsert.length, 1);

    await upgraded.close();
    await databaseFactoryFfi.deleteDatabase(dbPath);
  });

  test('PositionService.withDatabase works with v4 schema', () async {
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

    final svc = PositionService.withDatabase(db);

    // Existing position methods still work.
    await svc.savePosition(
      bookPath: '/books/test',
      chapterIndex: 0,
      position: const Duration(seconds: 30),
      globalPositionMs: 30000,
      totalDurationMs: 3600000,
    );
    final pos = await svc.getPosition('/books/test');
    expect(pos, isNotNull);
    expect(pos!.chapterIndex, 0);
  });
}
