import 'package:flutter/foundation.dart';

import 'fidelity_level.dart';
import 'fidelity_policy.dart';

/// A snapshot of what the governor has measured, for debugging and overlays.
@immutable
class FidelityStats {
  const FidelityStats({
    required this.level,
    required this.lastJankRatio,
    required this.frameBudget,
    required this.framesObserved,
    required this.stableWindows,
    required this.stableWindowsNeeded,
  });

  static const initial = FidelityStats(
    level: FidelityLevel.high,
    lastJankRatio: 0,
    frameBudget: Duration(microseconds: 16667),
    framesObserved: 0,
    stableWindows: 0,
    stableWindowsNeeded: 0,
  );

  /// The level chosen by measurement (ignores any lock).
  final FidelityLevel level;

  /// Jank fraction of the most recently completed window, 0..1.
  final double lastJankRatio;

  /// Per-frame time budget derived from the display refresh rate.
  final Duration frameBudget;

  /// Total frames that have been counted (excludes warmup and cooldown).
  final int framesObserved;

  /// Consecutive stable windows so far toward the next step up.
  final int stableWindows;

  /// Stable windows currently required to step up (includes backoff).
  final int stableWindowsNeeded;
}

/// Pure decision logic: feed it frame timings, it tells you when the level
/// should change. Has no dependency on the Flutter binding, so it can be
/// driven directly in tests.
class FidelityEngine {
  FidelityEngine({
    this.policy = const FidelityPolicy(),
    FidelityLevel initial = FidelityLevel.high,
    this.min = FidelityLevel.low,
    this.max = FidelityLevel.high,
  }) : assert(min <= max),
       _level = initial.clamp(min, max),
       _warmupRemaining = policy.warmupFrames;

  final FidelityPolicy policy;
  final FidelityLevel min;
  final FidelityLevel max;

  FidelityLevel _level;
  FidelityLevel get level => _level;

  int _windowFrames = 0;
  int _windowJanky = 0;
  int _stableWindows = 0;
  int _backoff = 1;
  int _framesObserved = 0;
  int _warmupRemaining;
  double _lastJankRatio = 0;
  Duration _lastBudget = FidelityStats.initial.frameBudget;
  Duration? _cooldownUntil;
  Duration? _lastUpgradeAt;

  /// Whether the most recent [addFrame] call completed a window.
  bool windowCompleted = false;

  int get _stableNeeded => policy.stableWindowsToUpgrade * _backoff;

  FidelityStats get stats => FidelityStats(
    level: _level,
    lastJankRatio: _lastJankRatio,
    frameBudget: _lastBudget,
    framesObserved: _framesObserved,
    stableWindows: _stableWindows,
    stableWindowsNeeded: _stableNeeded,
  );

  /// Discards the partial window and skips the next warmup frames.
  /// Call when frames stop being representative, e.g. after app resume.
  void restartMeasurement() {
    _windowFrames = 0;
    _windowJanky = 0;
    _warmupRemaining = policy.warmupFrames;
  }

  /// Records one rendered frame.
  ///
  /// A frame is janky when either its UI (build) or raster phase exceeds
  /// [budget]. [now] is a monotonic timestamp used for cooldowns.
  ///
  /// Returns the new level if this frame caused a change, otherwise null.
  /// Also returns null when only [stats] changed; check [windowCompleted].
  FidelityLevel? addFrame({
    required Duration build,
    required Duration raster,
    required Duration budget,
    required Duration now,
  }) {
    windowCompleted = false;
    _lastBudget = budget;

    if (_warmupRemaining > 0) {
      _warmupRemaining--;
      return null;
    }
    final cooldownUntil = _cooldownUntil;
    if (cooldownUntil != null && now < cooldownUntil) return null;

    _framesObserved++;
    _windowFrames++;
    if (build > budget || raster > budget) _windowJanky++;
    if (_windowFrames < policy.windowSize) return null;

    final ratio = _windowJanky / _windowFrames;
    _windowFrames = 0;
    _windowJanky = 0;
    _lastJankRatio = ratio;
    windowCompleted = true;

    final upgradedAt = _lastUpgradeAt;
    if (upgradedAt != null && now - upgradedAt > policy.flapWindow) {
      // The last step up held, so earn back some trust.
      _backoff = (_backoff ~/ 2).clamp(1, policy.maxBackoff);
      _lastUpgradeAt = null;
    }

    if (ratio >= policy.downgradeJankRatio) {
      _stableWindows = 0;
      if (_level == min) return null;
      final lastUp = _lastUpgradeAt;
      if (lastUp != null && now - lastUp <= policy.flapWindow) {
        // The last step up didn't hold; be slower to try again.
        _backoff = (_backoff * 2).clamp(1, policy.maxBackoff);
      }
      return _changeTo(_level.lower, now);
    }

    if (ratio <= policy.upgradeJankRatio) {
      if (_level == max) return null;
      _stableWindows++;
      if (_stableWindows >= _stableNeeded) {
        _lastUpgradeAt = now;
        return _changeTo(_level.higher, now);
      }
      return null;
    }

    // In between thresholds: neither healthy nor bad enough to act on.
    _stableWindows = 0;
    return null;
  }

  FidelityLevel _changeTo(FidelityLevel next, Duration now) {
    _level = next;
    _stableWindows = 0;
    _cooldownUntil = now + policy.cooldown;
    return next;
  }
}
