class Bookmark {
  final int? id;
  final String bookPath;
  final int chapterIndex;
  final int positionMs;
  final String label;
  final String? notes;
  final int createdAt;

  const Bookmark({
    this.id,
    required this.bookPath,
    required this.chapterIndex,
    required this.positionMs,
    required this.label,
    this.notes,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'book_path': bookPath,
        'chapter_index': chapterIndex,
        'position_ms': positionMs,
        'label': label,
        'notes': notes,
        'created_at': createdAt,
      };

  static Bookmark fromMap(Map<String, Object?> m) => Bookmark(
        id: m['id'] as int?,
        bookPath: m['book_path'] as String,
        chapterIndex: m['chapter_index'] as int,
        positionMs: m['position_ms'] as int,
        label: m['label'] as String,
        notes: m['notes'] as String?,
        createdAt: m['created_at'] as int,
      );

  Bookmark copyWith({String? label, String? notes}) => Bookmark(
        id: id,
        bookPath: bookPath,
        chapterIndex: chapterIndex,
        positionMs: positionMs,
        label: label ?? this.label,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
