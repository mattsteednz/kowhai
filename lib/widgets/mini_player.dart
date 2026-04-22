import 'dart:ui' show ImageFilter;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../models/audiobook.dart';
import '../services/audio_handler.dart';
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

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thin progress bar (global book progress)
            StreamBuilder<Duration>(
              stream: ah.effectivePositionStream,
              builder: (_, posSnap) {
                final totalMs =
                    book.duration?.inMilliseconds.toDouble() ?? 0;
                if (totalMs <= 0) {
                  return LinearProgressIndicator(
                    value: 0,
                    minHeight: 2,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                  );
                }
                final idx = ah.isCasting ? 0 : (ah.player.currentIndex ?? 0);
                int offsetMs = 0;
                for (int i = 0;
                    i < idx && i < book.chapterDurations.length;
                    i++) {
                  offsetMs += book.chapterDurations[i].inMilliseconds;
                }
                final globalMs = offsetMs +
                    (posSnap.data?.inMilliseconds ?? 0);
                return LinearProgressIndicator(
                  value: (globalMs / totalMs).clamp(0.0, 1.0),
                  minHeight: 2,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                );
              },
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            StreamBuilder<Duration>(
                              stream: ah.effectivePositionStream,
                              builder: (_, posSnap) {
                                final remaining =
                                    _remaining(ah, book, posSnap.data);
                                if (remaining == null) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  _fmtRemaining(remaining),
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurface
                                              .withValues(alpha: 0.6)),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                        tooltip: playing ? 'Pause' : 'Play',
                        onPressed: playing
                            ? ah.pause
                            : ah.play,
                      ),
                    ],
                  ),
                    ),
                    ), // SafeArea
                  ), // InkWell
                ), // Material
              ), // BackdropFilter
            ), // ClipRect
          ],
        );
      },
    );
  }

  Duration? _remaining(
      AudioVaultHandler ah, Audiobook book, Duration? chapterPos) {
    final totalMs = book.duration?.inMilliseconds;
    if (totalMs == null || totalMs == 0) return null;
    final idx = ah.isCasting ? 0 : (ah.player.currentIndex ?? 0);
    int offsetMs = 0;
    for (int i = 0; i < idx && i < book.chapterDurations.length; i++) {
      offsetMs += book.chapterDurations[i].inMilliseconds;
    }
    final globalMs = offsetMs + (chapterPos?.inMilliseconds ?? 0);
    final remainingMs = (totalMs - globalMs).clamp(0, totalMs);
    return Duration(milliseconds: remainingMs);
  }

  String _fmtRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m left';
    return '${m}m left';
  }
}
