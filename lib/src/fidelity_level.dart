/// How much visual richness the app can currently afford.
///
/// Levels are ordered: [low] < [medium] < [high].
enum FidelityLevel implements Comparable<FidelityLevel> {
  low,
  medium,
  high;

  /// The next level down, or this level if already [low].
  FidelityLevel get lower =>
      index == 0 ? this : FidelityLevel.values[index - 1];

  /// The next level up, or this level if already [high].
  FidelityLevel get higher => index == FidelityLevel.values.length - 1
      ? this
      : FidelityLevel.values[index + 1];

  bool operator <(FidelityLevel other) => index < other.index;
  bool operator <=(FidelityLevel other) => index <= other.index;
  bool operator >(FidelityLevel other) => index > other.index;
  bool operator >=(FidelityLevel other) => index >= other.index;

  @override
  int compareTo(FidelityLevel other) => index - other.index;

  /// Clamps this level into the inclusive range [min]..[max].
  FidelityLevel clamp(FidelityLevel min, FidelityLevel max) {
    assert(min <= max, 'min ($min) must not be above max ($max)');
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }

  /// Picks a value for this level.
  ///
  /// [medium] defaults to [high] when omitted.
  ///
  /// ```dart
  /// final sigma = level.pick(high: 24.0, medium: 10.0, low: 0.0);
  /// ```
  T pick<T>({required T high, T? medium, required T low}) => switch (this) {
    FidelityLevel.high => high,
    FidelityLevel.medium => medium ?? high,
    FidelityLevel.low => low,
  };
}
