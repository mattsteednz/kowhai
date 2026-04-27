/// Filter state for the library availability filter.
///
/// Controls which books are shown in the library based on their
/// download/availability status.
enum AvailabilityFilterState {
  all,
  availableOffline,
  driveOnly;

  /// Human-readable label used in the view bar summary and filter pills.
  String get label => switch (this) {
    AvailabilityFilterState.all => 'All',
    AvailabilityFilterState.availableOffline => 'Available offline',
    AvailabilityFilterState.driveOnly => 'Drive only',
  };
}
