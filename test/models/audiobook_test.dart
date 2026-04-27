import 'package:flutter_test/flutter_test.dart';
import 'package:kowhai/models/audiobook.dart';

void main() {
  group('Audiobook', () {
    test('chapterIndexAt returns correct index for M4B timestamps', () {
      final book = Audiobook(
        title: 'Test',
        path: '/dummy',
        audioFiles: [],
        chapters: [
          Chapter(title: 'Intro', start: Duration.zero),
          Chapter(title: 'Chapter 1', start: Duration(minutes: 10)),
          Chapter(title: 'Chapter 2', start: Duration(minutes: 25)),
          Chapter(title: 'Epilogue', start: Duration(minutes: 40)),
        ],
      );

      // Edge case: Exactly at 0
      expect(book.chapterIndexAt(Duration.zero), 0);

      // Between Chapter 1 and Chapter 2
      expect(book.chapterIndexAt(Duration(minutes: 15)), 1);

      // Exactly at Chapter 2 start
      expect(book.chapterIndexAt(Duration(minutes: 25)), 2);

      // Deep into Chapter 2
      expect(book.chapterIndexAt(Duration(minutes: 39)), 2);

      // After last chapter starts
      expect(book.chapterIndexAt(Duration(minutes: 50)), 3);
    });

    test('chapterIndexAt returns 0 if no chapters', () {
      final book = Audiobook(
        title: 'Test',
        path: '/dummy',
        audioFiles: [],
        chapters: [],
      );

      expect(book.chapterIndexAt(Duration(minutes: 15)), 0);
    });
  });

  group('Audiobook.copyWith', () {
    test('overrides specified fields and preserves the rest', () {
      final original = Audiobook(
        title: 'Original',
        author: 'Author A',
        duration: const Duration(hours: 5),
        path: '/books/original',
        audioFiles: const ['a.mp3'],
        narrator: 'Narrator A',
        series: 'Series A',
        seriesIndex: 1,
      );

      final copy = original.copyWith(
        title: 'Updated',
        author: 'Author B',
        narrator: 'Narrator B',
      );

      // Overridden fields.
      expect(copy.title, 'Updated');
      expect(copy.author, 'Author B');
      expect(copy.narrator, 'Narrator B');

      // Preserved fields.
      expect(copy.path, '/books/original');
      expect(copy.duration, const Duration(hours: 5));
      expect(copy.audioFiles, const ['a.mp3']);
      expect(copy.series, 'Series A');
      expect(copy.seriesIndex, 1);
      expect(copy.source, AudiobookSource.local);
    });

    test('no overrides returns equivalent copy', () {
      final original = Audiobook(
        title: 'Test',
        path: '/dummy',
        audioFiles: const [],
        author: 'Someone',
      );
      final copy = original.copyWith();
      expect(copy.title, original.title);
      expect(copy.author, original.author);
      expect(copy.path, original.path);
    });
  });
}
