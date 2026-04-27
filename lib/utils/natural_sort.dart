/// Natural sort comparator for strings containing numbers.
///
/// Splits strings into numeric and non-numeric segments, comparing numbers
/// numerically and text lexicographically. This ensures "2.mp3" < "10.mp3"
/// instead of the default string sort where "10.mp3" < "2.mp3".
///
/// Example:
/// ```dart
/// final files = ['track2.mp3', 'track10.mp3', 'track1.mp3'];
/// files.sort((a, b) => naturalCompare(a, b));
/// // Result: ['track1.mp3', 'track2.mp3', 'track10.mp3']
/// ```
int naturalCompare(String a, String b) {
  final aLow = a.toLowerCase();
  final bLow = b.toLowerCase();
  final aSegments = _splitNatural(aLow);
  final bSegments = _splitNatural(bLow);
  final len = aSegments.length < bSegments.length ? aSegments.length : bSegments.length;

  for (int i = 0; i < len; i++) {
    final aS = aSegments[i];
    final bS = bSegments[i];
    final aNum = int.tryParse(aS);
    final bNum = int.tryParse(bS);

    int cmp;
    if (aNum != null && bNum != null) {
      cmp = aNum.compareTo(bNum);
    } else {
      cmp = aS.compareTo(bS);
    }

    if (cmp != 0) return cmp;
  }

  return aSegments.length.compareTo(bSegments.length);
}

/// Splits a string into numeric and non-numeric segments.
///
/// Example: "track2a10" → ["track", "2", "a", "10"]
List<String> _splitNatural(String s) {
  final segments = <String>[];
  final re = RegExp(r'(\d+|\D+)');
  for (final m in re.allMatches(s)) {
    segments.add(m.group(0)!);
  }
  return segments;
}
