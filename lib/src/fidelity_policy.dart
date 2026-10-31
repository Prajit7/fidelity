/// Tuning knobs for when the governor steps quality down or up.
///
/// The defaults favour reacting quickly to jank and recovering cautiously,
/// so users rarely see the UI flicker between levels.
class FidelityPolicy {
  const FidelityPolicy({
    this.windowSize = 60,
    this.downgradeJankRatio = 0.15,
    this.upgradeJankRatio = 0.03,
    this.stableWindowsToUpgrade = 4,
    this.cooldown = const Duration(seconds: 2),
    this.flapWindow = const Duration(seconds: 10),
    this.maxBackoff = 8,
    this.warmupFrames = 20,
  }) : assert(windowSize > 0),
       assert(downgradeJankRatio > upgradeJankRatio),
       assert(stableWindowsToUpgrade > 0),
       assert(maxBackoff >= 1);

  /// Number of rendered frames evaluated together.
  final int windowSize;

  /// Fraction of janky frames in a window that triggers a step down.
  final double downgradeJankRatio;

  /// A window at or below this jank fraction counts as "stable".
  final double upgradeJankRatio;

  /// Consecutive stable windows required before stepping up.
  ///
  /// Multiplied by the current backoff when upgrades keep failing.
  final int stableWindowsToUpgrade;

  /// After any level change, frames are ignored for this long so the
  /// new level gets a fair measurement.
  final Duration cooldown;

  /// If a step down happens within this time of a step up, the step up is
  /// considered a failure and future step ups require more stable windows.
  final Duration flapWindow;

  /// Upper bound for the backoff multiplier on [stableWindowsToUpgrade].
  final int maxBackoff;

  /// Frames ignored after the governor starts or the app resumes, since
  /// the first frames after launch or resume are usually slow regardless.
  final int warmupFrames;
}
