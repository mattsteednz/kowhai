import 'package:flutter/material.dart';
import '../models/audiobook.dart';
import '../utils/formatters.dart';
import 'book_cover.dart';
import 'drive_download_overlay.dart';
import 'enrichment_aware_cover.dart';

class AudiobookListTile extends StatelessWidget {
  final Audiobook book;
  final VoidCallback? onTap;
  final VoidCallback? onDetailsPressed;
  final bool isActive;
  final BookStatus status;

  const AudiobookListTile({
    super.key,
    required this.book,
    this.onTap,
    this.onDetailsPressed,
    this.isActive = false,
    this.status = BookStatus.notStarted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget cover = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 56,
        height: 56,
        child: book.source == AudiobookSource.drive
            ? DriveDownloadOverlay(
                book: book,
                iconSize: 24,
                indicatorSize: 24,
                child: EnrichmentAwareCover(
                  book: book,
                  iconSize: 28,
                  placeholderStyle: CoverPlaceholderStyle.initial,
                ),
              )
            : EnrichmentAwareCover(
                book: book,
                iconSize: 28,
                placeholderStyle: CoverPlaceholderStyle.initial,
              ),
      ),
    );

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          cover,
          if (isActive)
            Positioned(
              right: 0,
              bottom: 0,
              child: Semantics(
                label: 'Now playing',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.volume_up_rounded,
                    size: 12,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        book.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (book.author != null)
            Text(
              book.author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          if (book.duration != null)
            Text(
              fmtHourMin(book.duration!),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (book.isDrmLocked)
            Semantics(
              label: 'DRM protected',
              excludeSemantics: true,
              child: Icon(Icons.lock_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'details',
                child: ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Book details'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'details') onDetailsPressed?.call();
            },
          ),
        ],
      ),
      isThreeLine: book.author != null,
    );
  }

}

