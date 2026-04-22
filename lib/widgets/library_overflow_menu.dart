import 'package:flutter/material.dart';

// ── Overflow menu ─────────────────────────────────────────────────────────────

class LibraryOverflowMenu extends StatefulWidget {
  final bool syncing;
  final VoidCallback onHistory;
  final VoidCallback? onRescan;
  final VoidCallback onSettings;

  const LibraryOverflowMenu({
    super.key,
    required this.syncing,
    required this.onHistory,
    required this.onRescan,
    required this.onSettings,
  });

  @override
  State<LibraryOverflowMenu> createState() => _LibraryOverflowMenuState();
}

class _LibraryOverflowMenuState extends State<LibraryOverflowMenu> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(
        Icons.more_vert_rounded,
        color: _open ? cs.primary : null,
      ),
      onOpened: () => setState(() => _open = true),
      onCanceled: () => setState(() => _open = false),
      onSelected: (value) {
        setState(() => _open = false);
        switch (value) {
          case 'history':  widget.onHistory();  break;
          case 'rescan':   widget.onRescan?.call(); break;
          case 'settings': widget.onSettings(); break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'history',
          child: ListTile(
            leading: Icon(Icons.history_rounded),
            title: Text('Listen history'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'rescan',
          enabled: !widget.syncing,
          child: ListTile(
            leading: widget.syncing
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            title: const Text('Rescan library'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_rounded),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
