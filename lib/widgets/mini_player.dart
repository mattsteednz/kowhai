import 'dart:ui' show ImageFilter;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../models/audiobook.dart';
import '../services/audio_handler.dart';
import '../utils/formatters.dart';
import '../widgets/audio_handler_scope.dart';
import '../widgets/book_cover.dart';
import '../screens/player_screen.dart';

// ── Mini player ───────────────────────────────────────────────────────────────

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final ah = AudioHandlerScope.of(context).audioHandler;
    return StreamBuilder<PlaybackState>(
      stream: ah.playbackState,
      builder: (context, snap) {
        final state = snap.data;
        final book = ah.currentBook;
        if (book == null ||
            state == null ||
            state.processingState == AudioProcessingState.idle) {
          return const SizedBox.shrink();
        }

        final playing = state.playing;
        final theme = Theme.of(context);

        return StreamBuilder<Duration>(
          stream: ah.effectivePositionStream,
          builder: (_, posSnap) {
            final position = posSnap.data;
            final totalMs = book.duration?.inMilliseconds.toDouble() ?? 0;

            // Global progress for the thin bar.
            final idx = ah.isCasting ? 0 : (ah.player.currentIndex ?? 0);
            final globalMs = calculateGlobalPosition(
              chapterIndex: idx,
              chapterPosition: position ?? Duration.zero,
              chapterDurations: book.chapterDurations,
            );

            final remaining = _remaining(ah, book, position);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thin progress bar (global book progress)
                LinearProgressIndicator(
                  value: totalMs > 0
                      ? (globalMs / totalMs).clamp(0.0, 1.0)
                      : 0,
                  minHeight: 2,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Material(
                      color: theme.colorScheme.surface.withValues(alpha: 0.85),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PlayerScreen(book: book)),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: BookCover(book: book, iconSize: 28),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        book.title,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (remaining != null)
                                        Text(
                                          '${fmtHourMin(remaining)} left',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.6)),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: theme.colorScheme.primary,
                                  ),
                                  tooltip: playing ? 'Pause' : 'Play',
                                  onPressed: playing ? ah.pause : ah.play,
                                ),
                              ],
                            ),
                          ),
                        ), // InkWell
                      ), // Material
                    ), // BackdropFilter
                  ), // ClipRect
                ),
              ],
            );
          },
        );
      },
    );
  }

  Duration? _remaining(
      KowhaiHandler ah, Audiobook book, Duration? chapterPos) {
    final totalMs = book.duration?.inMilliseconds;
    if (totalMs == null || totalMs == 0) return null;
    final idx = ah.isCasting ? 0 : (ah.player.currentIndex ?? 0);
    final globalMs = calculateGlobalPosition(
      chapterIndex: idx,
      chapterPosition: chapterPos ?? Duration.zero,
      chapterDurations: book.chapterDurations,
    );
    final remainingMs = (totalMs - globalMs).clamp(0, totalMs);
    return Duration(milliseconds: remainingMs);
  }

}
