// ── Pure helpers (testable) ───────────────────────────────────────────────────

/// Formats a speed value as e.g. "1.0×", "1.25×", "0.75×".
/// Values divisible by 0.1 get one decimal; others get two.
String fmtSpeed(double s) {
  final str = s.toStringAsFixed(2);
  return '${str.endsWith('0') ? s.toStringAsFixed(1) : str}×';
}

/// Formats a duration as `H:MM:SS` (if ≥ 1 hour) or `MM:SS`.
/// Negative durations are clamped to zero.
String fmtHM(Duration d) {
  if (d < Duration.zero) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Formats a duration always including hours: `H:MM:SS`.
/// Used for bookmark timestamps so the format is consistent.
String fmtHMSec(Duration d) {
  if (d < Duration.zero) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}
