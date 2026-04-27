import 'package:flutter_test/flutter_test.dart';
import 'package:audiovault/services/drive_service.dart';
import 'package:audiovault/utils/cover_picker.dart';
import 'package:audiovault/utils/natural_sort.dart';

DriveFileInfo _img(String name) => DriveFileInfo(
      id: name,
      name: name,
      mimeType: 'image/jpeg',
      sizeBytes: 1,
    );

DriveFileInfo _audio(String name) => DriveFileInfo(
      id: name,
      name: name,
      mimeType: 'audio/mpeg',
      sizeBytes: 1,
    );

DriveFileInfo _other(String name, String mime) => DriveFileInfo(
      id: name,
      name: name,
      mimeType: mime,
      sizeBytes: 1,
    );

void main() {
  group('DriveFileInfo.extension / isAudio / isImage', () {
    test('extension is lowercased and includes the dot', () {
      expect(_img('Cover.JPG').extension, '.jpg');
      expect(_audio('Track01.MP3').extension, '.mp3');
    });

    test('no extension returns empty string', () {
      expect(_other('README', 'text/plain').extension, '');
    });

    test('isAudio matches common audio extensions', () {
      for (final ext in ['.mp3', '.m4a', '.aac', '.m4b', '.flac', '.ogg']) {
        expect(_other('song$ext', 'audio/$ext').isAudio, isTrue,
            reason: 'expected $ext to be audio');
      }
    });

    test('isAudio is false for images and text', () {
      expect(_img('cover.jpg').isAudio, isFalse);
      expect(_other('notes.txt', 'text/plain').isAudio, isFalse);
    });

    test('isImage matches common image extensions', () {
      for (final ext in ['.jpg', '.jpeg', '.png', '.webp']) {
        expect(_img('pic$ext').isImage, isTrue,
            reason: 'expected $ext to be image');
      }
    });

    test('isImage is false for audio', () {
      expect(_audio('track.mp3').isImage, isFalse);
    });
  });

  group('pickBestCover', () {
    test('returns null for empty list', () {
      expect(pickBestCover([], (f) => (f as DriveFileInfo).name), isNull);
    });

    test('prefers exact cover.jpg over everything else', () {
      final result = pickBestCover([
        _img('folder-art.jpg'),
        _img('cover.jpg'),
        _img('other-cover.png'),
      ], (f) => f.name);
      expect(result?.name, 'cover.jpg');
    });

    test('is case-insensitive for exact match', () {
      final result = pickBestCover([_img('other.jpg'), _img('COVER.JPG')], (f) => f.name);
      expect(result?.name, 'COVER.JPG');
    });

    test('accepts cover.jpeg and cover.png as exact matches', () {
      expect(pickBestCover([_img('cover.jpeg')], (f) => f.name)?.name, 'cover.jpeg');
      expect(pickBestCover([_img('cover.png')], (f) => f.name)?.name, 'cover.png');
    });

    test('falls back to name containing "cover"', () {
      final result = pickBestCover([_img('folder.jpg'), _img('mycover2.jpg')], (f) => f.name);
      expect(result?.name, 'mycover2.jpg');
    });

    test('falls back to first image when no cover-like name', () {
      final result = pickBestCover([_img('folder.jpg'), _img('art.jpg')], (f) => f.name);
      expect(result?.name, 'folder.jpg');
    });
  });

  group('escapeQ', () {
    test('plain names are unchanged', () {
      expect(escapeQ('AudioVault'), 'AudioVault');
    });

    test('single quote is escaped', () {
      expect(escapeQ("it's mine"), r"it\'s mine");
    });

    test('backslash is escaped', () {
      expect(escapeQ(r'back\slash'), r'back\\slash');
    });

    test('both special chars escaped correctly', () {
      expect(escapeQ(r"it\'s"), r"it\\\'s");
    });

    test('empty string returns empty string', () {
      expect(escapeQ(''), '');
    });
  });

  group('naturalCompare', () {
    test('numeric segments sort numerically, not lexicographically', () {
      final names = ['track10.mp3', 'track2.mp3', 'track1.mp3'];
      names.sort(naturalCompare);
      expect(names, ['track1.mp3', 'track2.mp3', 'track10.mp3']);
    });

    test('is case-insensitive for alphabetic segments', () {
      expect(naturalCompare('Apple', 'banana'), lessThan(0));
      expect(naturalCompare('Banana', 'apple'), greaterThan(0));
    });

    test('shorter strings sort before longer ones with same prefix', () {
      expect(naturalCompare('chapter', 'chapter1'), lessThan(0));
    });

    test('equal strings return 0', () {
      expect(naturalCompare('Track01.mp3', 'track01.mp3'), 0);
    });
  });
}
