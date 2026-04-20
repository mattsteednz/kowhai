import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:audiovault/models/bookmark.dart';
import 'package:audiovault/services/position_service.dart';

Future<PositionService> _makeService() async {
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
        await db.execute(
            'CREATE INDEX idx_bookmarks_book_path ON bookmarks(book_path)');
      },
    ),
  );
  return PositionService.withDatabase(db);
}

Bookmark _bm(String bookPath,
        {int chapterIndex = 0,
        int positionMs = 60000,
        String label = 'Test',
        String? notes}) =>
    Bookmark(
      bookPath: bookPath,
      chapterIndex: chapterIndex,
      positionMs: positionMs,
      label: label,
      notes: notes,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PositionService bookmark CRUD', () {
    test('addBookmark returns bookmark with assigned id', () async {
      final svc = await _makeService();
      final saved = await svc.addBookmark(_bm('/book/a'));
      expect(saved.id, isNotNull);
      expect(saved.id, greaterThan(0));
    });

    test('getBookmarks returns bookmarks ordered by position_ms', () async {
      final svc = await _makeService();
      await svc.addBookmark(_bm('/book/a', positionMs: 90000, label: 'Later'));
      await svc.addBookmark(_bm('/book/a', positionMs: 30000, label: 'Earlier'));
      await svc.addBookmark(_bm('/book/a', positionMs: 60000, label: 'Middle'));

      final bookmarks = await svc.getBookmarks('/book/a');
      expect(bookmarks.map((b) => b.label), ['Earlier', 'Middle', 'Later']);
    });

    test('getBookmarks returns empty list for unknown book', () async {
      final svc = await _makeService();
      expect(await svc.getBookmarks('/unknown'), isEmpty);
    });

    test('getBookmarks isolates by book_path', () async {
      final svc = await _makeService();
      await svc.addBookmark(_bm('/book/a', label: 'A'));
      await svc.addBookmark(_bm('/book/b', label: 'B'));

      expect((await svc.getBookmarks('/book/a')).map((b) => b.label), ['A']);
      expect((await svc.getBookmarks('/book/b')).map((b) => b.label), ['B']);
    });

    test('deleteBookmark removes the bookmark', () async {
      final svc = await _makeService();
      final saved = await svc.addBookmark(_bm('/book/a'));
      await svc.deleteBookmark(saved.id!);
      expect(await svc.getBookmarks('/book/a'), isEmpty);
    });

    test('deleteBookmark does not affect other bookmarks', () async {
      final svc = await _makeService();
      final a = await svc.addBookmark(_bm('/book/a', label: 'Keep'));
      final b = await svc.addBookmark(_bm('/book/a', positionMs: 90000, label: 'Delete'));
      await svc.deleteBookmark(b.id!);

      final remaining = await svc.getBookmarks('/book/a');
      expect(remaining.length, 1);
      expect(remaining.first.id, a.id);
    });

    test('updateBookmark changes label and notes', () async {
      final svc = await _makeService();
      final saved = await svc.addBookmark(_bm('/book/a', label: 'Old'));
      await svc.updateBookmark(saved.id!, label: 'New', notes: 'A note');

      final bookmarks = await svc.getBookmarks('/book/a');
      expect(bookmarks.first.label, 'New');
      expect(bookmarks.first.notes, 'A note');
    });

    test('updateBookmark can clear notes by passing null', () async {
      final svc = await _makeService();
      final saved =
          await svc.addBookmark(_bm('/book/a', notes: 'Some note'));
      await svc.updateBookmark(saved.id!, label: saved.label, notes: null);

      final bookmarks = await svc.getBookmarks('/book/a');
      expect(bookmarks.first.notes, isNull);
    });

    test('bookmark preserves chapterIndex and positionMs', () async {
      final svc = await _makeService();
      final saved = await svc.addBookmark(
          _bm('/book/a', chapterIndex: 5, positionMs: 123456));
      final bookmarks = await svc.getBookmarks('/book/a');
      expect(bookmarks.first.chapterIndex, 5);
      expect(bookmarks.first.positionMs, 123456);
    });
  });
}
