import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../locator.dart';
import '../models/audiobook.dart';
import '../services/drive_book_repository.dart';
import '../services/drive_download_manager.dart';
import '../services/drive_library_service.dart';
import 'formatters.dart';

/// Shows a bottom sheet prompting the user to download a Drive book.
///
/// Always fetches [DriveLibraryService.totalSizeBytes] regardless of
/// connectivity, so the formatted size is shown in both the prompt message
/// and the Download button label on WiFi and mobile data alike.
///
/// When the device is on mobile data the sheet shows:
///   "You're on mobile data. This book is X. Download anyway?"
///
/// When the device is on WiFi (or ethernet) the sheet shows:
///   "This book is X. Download it to start listening."
///
/// The optional [connectivityOverride] parameter is used by tests to inject
/// a known connectivity state without hitting the real network stack.
Future<void> showDriveDownloadSheet(
  BuildContext context,
  Audiobook book, {
  List<ConnectivityResult>? connectivityOverride,
}) async {
  final folderId = book.driveMetadata!.folderId;

  final connectivity =
      connectivityOverride ?? await Connectivity().checkConnectivity();
  final isWifi = connectivity.contains(ConnectivityResult.wifi) ||
      connectivity.contains(ConnectivityResult.ethernet);

  // Always fetch the size — remove the former `if (!isWifi)` guard so the
  // formatted size is available for both WiFi and mobile-data prompts.
  final sizeBytes =
      await locator<DriveLibraryService>().totalSizeBytes(folderId);

  if (!context.mounted) return;

  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            style: Theme.of(ctx).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            isWifi
                ? 'This book is ${formatBytes(sizeBytes)}. Download it to start listening.'
                : 'You\'re on mobile data. This book is ${formatBytes(sizeBytes)}. Download anyway?',
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.download_rounded),
                label: Text('Download (${formatBytes(sizeBytes)})'),
                onPressed: () {
                  Navigator.pop(ctx);
                  locator<DriveLibraryService>().startDownload(folderId);
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}


/// Shows a bottom sheet for a Drive book that is currently downloading.
/// Displays live progress and offers a "Cancel download" action.
///
/// Returns `true` if the user cancelled the download, `false` / `null`
/// otherwise (sheet dismissed without action).
Future<bool?> showDriveDownloadProgressSheet(
  BuildContext context,
  Audiobook book,
) async {
  final folderId = book.driveMetadata!.folderId;
  final repo = locator<DriveBookRepository>();
  final dlManager = locator<DriveDownloadManager>();

  // Read initial state from DB.
  final files = await repo.getFilesForBook(folderId);
  final totalBytes = files.fold<int>(0, (s, f) => s + f.sizeBytes);
  final doneBytes = files
      .where((f) => f.downloadState == DriveDownloadState.done)
      .fold<int>(0, (s, f) => s + f.sizeBytes);

  if (!context.mounted) return null;

  return showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => _DownloadProgressSheet(
      book: book,
      folderId: folderId,
      totalBytes: totalBytes,
      initialDoneBytes: doneBytes,
      dlManager: dlManager,
    ),
  );
}

class _DownloadProgressSheet extends StatefulWidget {
  final Audiobook book;
  final String folderId;
  final int totalBytes;
  final int initialDoneBytes;
  final DriveDownloadManager dlManager;

  const _DownloadProgressSheet({
    required this.book,
    required this.folderId,
    required this.totalBytes,
    required this.initialDoneBytes,
    required this.dlManager,
  });

  @override
  State<_DownloadProgressSheet> createState() => _DownloadProgressSheetState();
}

class _DownloadProgressSheetState extends State<_DownloadProgressSheet> {
  late int _completedBytes;
  int _currentFileBytes = 0;
  StreamSubscription<DriveDownloadEvent>? _sub;

  double get _progress {
    if (widget.totalBytes <= 0) return 0;
    return ((_completedBytes + _currentFileBytes) / widget.totalBytes)
        .clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _completedBytes = widget.initialDoneBytes;
    _sub = widget.dlManager.downloadEvents
        .where((e) => e.folderId == widget.folderId && e.fileIndex != null)
        .listen(_onEvent);
  }

  void _onEvent(DriveDownloadEvent event) {
    if (!mounted) return;
    setState(() {
      if (event.state == DriveDownloadState.downloading) {
        _currentFileBytes = event.bytesDownloaded ?? 0;
      } else if (event.state == DriveDownloadState.done) {
        _completedBytes += event.fileSizeBytes ?? 0;
        _currentFileBytes = 0;
        // If all done, dismiss the sheet.
        if (_progress >= 1.0 && mounted) {
          Navigator.pop(context, false);
        }
      } else if (event.state == DriveDownloadState.error) {
        _currentFileBytes = 0;
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _cancelDownload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel download?'),
        content: Text(
          'The download will be stopped and any partially downloaded '
          'files for "${widget.book.title}" will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep downloading'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancel download',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await locator<DriveDownloadManager>().cancelDownload(widget.folderId);
    await locator<DriveLibraryService>().undownloadBook(widget.folderId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (_progress * 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.book.title,
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$pct%',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Downloading — ${formatBytes((_completedBytes + _currentFileBytes).clamp(0, widget.totalBytes))} '
            'of ${formatBytes(widget.totalBytes)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel download'),
                onPressed: _cancelDownload,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
