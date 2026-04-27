import 'package:flutter/material.dart';
import '../services/audio_handler.dart';
import '../utils/formatters.dart';

const _commonSpeeds = [0.75, 1.0, 1.25, 1.5, 2.0, 2.5];

/// Shows a playback speed picker as a bottom sheet.
///
/// Speed changes apply live. Dismissing (backdrop tap, drag-down, back gesture)
/// keeps whatever speed was last set. Returns the final speed.
Future<double> showSpeedDialog({
  required BuildContext context,
  required double currentSpeed,
  required KowhaiHandler audioHandler,
}) async {
  double tempSpeed = currentSpeed;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Playback speed',
                      style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: 16),
                Text(
                  fmtSpeed(tempSpeed),
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: tempSpeed,
                  min: 0.5,
                  max: 3.0,
                  divisions: 50, // 0.05× steps
                  onChanged: (v) {
                    setSheetState(() => tempSpeed = v);
                    audioHandler.setSpeed(v);
                  },
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: _commonSpeeds.map((s) {
                    final active = (tempSpeed - s).abs() < 0.01;
                    return ChoiceChip(
                      label: Text(fmtSpeed(s)),
                      selected: active,
                      onSelected: (_) {
                        setSheetState(() => tempSpeed = s);
                        audioHandler.setSpeed(s);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  return tempSpeed;
}

/// Shows a custom sleep timer dialog. Returns the chosen minutes, or `null`
/// if cancelled.
Future<int?> showCustomTimerDialog(BuildContext context) async {
  int minutes = 20;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Custom sleep timer'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded),
                tooltip: 'Decrease',
                onPressed: minutes > 1
                    ? () => setDialogState(() => minutes--)
                    : null,
              ),
              SizedBox(
                width: 88,
                child: Text(
                  '$minutes min',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Increase',
                onPressed: minutes < 180
                    ? () => setDialogState(() => minutes++)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, minutes),
              child: const Text('Set'),
            ),
          ],
        );
      },
    ),
  );
}
