import 'package:flutter_test/flutter_test.dart';
import 'package:kowhai/models/bookmark.dart';

void main() {
  group('Bookmark', () {
    Bookmark bm({
      int? id,
      String bookPath = '/books/dune',
      int chapterIndex = 3,
      int positionMs = 123456,
      String label = 'Great passage',
      String? notes = 'Some notes',
      int createdAt = 1000000,
    }) =>
        Bookmark(
          id: id,
          bookPath: bookPath,
          chapterIndex: chapterIndex,
          positionMs: positionMs,
          label: label,
          notes: notes,
          createdAt: createdAt,
        );

    group('toMap / fromMap round-trip', () {
      test('preserves all fields including notes', () {
        final original = bm(id: 42);
        final restored = Bookmark.fromMap(original.toMap());
        expect(restored.id, 42);
        expect(restored.bookPath, '/books/dune');
        expect(restored.chapterIndex, 3);
        expect(restored.positionMs, 123456);
        expect(restored.label, 'Great passage');
        expect(restored.notes, 'Some notes');
        expect(restored.createdAt, 1000000);
      });

      test('handles null id (new bookmark before insert)', () {
        final original = bm(id: null);
        final map = original.toMap();
        expect(map.containsKey('id'), isFalse);
      });

      test('handles null notes', () {
        final original = bm(notes: null);
        final restored = Bookmark.fromMap(original.toMap());
        expect(restored.notes, isNull);
      });
    });

    group('copyWith', () {
      test('overrides label and notes', () {
        final original = bm();
        final copy = original.copyWith(label: 'New label', notes: 'New notes');
        expect(copy.label, 'New label');
        expect(copy.notes, 'New notes');
        // Unchanged fields preserved.
        expect(copy.bookPath, original.bookPath);
        expect(copy.chapterIndex, original.chapterIndex);
        expect(copy.positionMs, original.positionMs);
        expect(copy.createdAt, original.createdAt);
      });

      test('preserves original values when no overrides given', () {
        final original = bm(label: 'Keep', notes: 'Also keep');
        final copy = original.copyWith();
        expect(copy.label, 'Keep');
        expect(copy.notes, 'Also keep');
      });
    });
  });
}
