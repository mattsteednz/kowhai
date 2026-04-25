import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../locator.dart';
import '../models/audiobook.dart';
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
