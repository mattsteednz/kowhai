/// Selects the best cover image from a collection based on filename priority.
///
/// Priority order:
/// 1. Exact match: `cover.jpg`, `cover.jpeg`, or `cover.png` (case-insensitive)
/// 2. Filename contains "cover" (case-insensitive)
/// 3. First item in the collection
///
/// Returns null if the collection is empty.
///
/// Example:
/// ```dart
/// final images = [File('image1.jpg'), File('cover.png'), File('image2.jpg')];
/// final best = pickBestCover(images, (f) => f.path.split('/').last);
/// // Result: File('cover.png')
/// ```
T? pickBestCover<T>(Iterable<T> items, String Function(T) getName) {
  if (items.isEmpty) return null;

  // Priority 1: exact match for cover.jpg/jpeg/png
  for (final item in items) {
    final name = getName(item).toLowerCase();
    if (name == 'cover.jpg' || name == 'cover.jpeg' || name == 'cover.png') {
      return item;
    }
  }

  // Priority 2: filename contains "cover"
  for (final item in items) {
    if (getName(item).toLowerCase().contains('cover')) {
      return item;
    }
  }

  // Priority 3: first item
  return items.first;
}
