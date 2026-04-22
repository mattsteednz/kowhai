import 'dart:io';
import 'package:flutter/material.dart';
import '../models/audiobook.dart';

/// Renders an audiobook's cover art with a placeholder fallback.
///
/// Checks [Audiobook.coverImageBytes] first, then [Audiobook.coverImagePath],
/// then falls back to a themed placeholder icon.
///
/// When [isEnriching] is true, overlays a small progress indicator on the
/// placeholder so the user knows a cover fetch is in flight. When
/// [enrichmentFailed] is true and no local art exists, renders a distinct
/// "no cover available" icon instead of the default placeholder.
class BookCover extends StatelessWidget {
  final Audiobook book;
  final double iconSize;
  final bool isEnriching;
  final bool enrichmentFailed;

  /// Optional render index (position in the current grid/list). When provided,
  /// the placeholder fallback picks a colour from [placeholderPalette] by
  /// `index % palette.length` so adjacent tiles never collide. When null,
  /// falls back to a hash of the book title (used outside list contexts, e.g.
  /// the mini player).
  final int? placeholderIndex;

  const BookCover({
    super.key,
    required this.book,
    this.iconSize = 52,
    this.isEnriching = false,
    this.enrichmentFailed = false,
    this.placeholderIndex,
  });

  /// Muted mid-tone palette used for placeholder tiles when no cover art exists.
  /// Works in both light and dark modes — light enough not to overpower a light
  /// UI, dark enough to keep the icon legible.
  static const List<Color> placeholderPalette = [
    Color(0xFF5C7A9E), // muted steel blue
    Color(0xFF7A5C8A), // muted mauve
    Color(0xFF5C7A5C), // muted sage
    Color(0xFF8A7A5C), // muted tan
    Color(0xFF6B8A5C), // muted olive
    Color(0xFF8A5C5C), // muted rose
    Color(0xFF5C8A8A), // muted teal
    Color(0xFF6B6B8A), // muted periwinkle
  ];

  Color _placeholderColor() {
    final idx = placeholderIndex;
    if (idx != null) {
      return placeholderPalette[idx.abs() % placeholderPalette.length];
    }
    final hash = book.title.codeUnits.fold(0, (h, c) => h * 31 + c);
    return placeholderPalette[hash.abs() % placeholderPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    if (book.coverImageBytes != null) {
      return Image.memory(
        book.coverImageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (book.coverImagePath != null) {
      return Image.file(
        File(book.coverImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final showFailedIcon = enrichmentFailed && !isEnriching;
    final bg = _placeholderColor();
    return ColoredBox(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showFailedIcon)
            Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: iconSize,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          if (isEnriching)
            Positioned(
              right: 6,
              bottom: 6,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
