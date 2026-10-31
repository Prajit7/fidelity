import 'dart:ui' show FrameTiming, FramePhase, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'fidelity_engine.dart';
import 'fidelity_level.dart';
import 'fidelity_policy.dart';

/// Watches real frame timings and exposes the [FidelityLevel] the app can
/// currently afford.
///
/// Its [value] is the measured level, limited by [ceiling], unless a
/// [lock] is in place. Listeners are notified only when [value] changes.
///
/// Usually created for you by `FidelityScope`. Create one yourself to share
/// it outside the widget tree or to wire in extra signals:
///
/// ```dart
/// // e.g. from battery_plus: cap quality while battery saver is on.
/// governor.ceiling = saverOn ? FidelityLevel.medium : null;
/// ```
class FidelityGovernor extends ChangeNotifier
    implements ValueListenable<FidelityLevel> {
  FidelityGovernor({
    FidelityPolicy policy = const FidelityPolicy(),
    FidelityLevel initial = FidelityLevel.high,
    FidelityLevel min = FidelityLevel.low,
    FidelityLevel max = FidelityLevel.high,
  }) : _engine = FidelityEngine(
         policy: policy,
         initial: initial,
         min: min,
         max: max,
       ) {
    _value = _engine.level;
    _stats = ValueNotifier(_engine.stats);
  }

  final FidelityEngine _engine;
  late final ValueNotifier<FidelityStats> _stats;
  late FidelityLevel _value;

  FidelityLevel? _locked;
  FidelityLevel? _ceiling;
  AppLifecycleListener? _lifecycle;
  bool _foreground = true;
  bool _running = false;

  @override
  FidelityLevel get value => _value;

  /// Live measurements, updated once per completed window.
  ValueListenable<FidelityStats> get stats => _stats;

  /// The level forced by [lock], or null when measuring automatically.
  FidelityLevel? get locked => _locked;

  /// Whether frame timings are currently being observed.
  bool get isRunning => _running;

  /// An upper limit applied on top of measurement, or null for none.
  ///
  /// Use it for signals the governor can't see itself: battery saver,
  /// thermal state, a user "reduce effects" setting, and so on.
  FidelityLevel? get ceiling => _ceiling;
  set ceiling(FidelityLevel? level) {
    _ceiling = level;
    _update();
  }

  /// Forces [level] regardless of measurement. Measurement keeps running,
  /// so [unlock] returns to an up-to-date level.
  ///
  /// Listeners are notified even if [value] doesn't change, since the lock
  /// state did.
  void lock(FidelityLevel level) {
    final changed = _locked != level;
    _locked = level;
    _update(lockChanged: changed);
  }

  /// Returns to automatic levels after [lock].
  void unlock() {
    final changed = _locked != null;
    _locked = null;
    _update(lockChanged: changed);
  }

  /// Begins observing frames. Safe to call more than once.
  void start() {
    if (_running) return;
    _running = true;
    _engine.restartMeasurement();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  /// Stops observing frames. The current level is kept.
  void stop() {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// Feeds a frame directly, bypassing the binding. For tests and for
  /// replaying recorded timings.
  @visibleForTesting
  void debugAddFrame({
    required Duration build,
    required Duration raster,
    required Duration now,
    Duration budget = const Duration(microseconds: 16667),
  }) {
    _record(build: build, raster: raster, budget: budget, now: now);
  }

  void _onLifecycle(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground && !_foreground) _engine.restartMeasurement();
    _foreground = foreground;
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_foreground) return;
    final budget = _frameBudget();
    for (final t in timings) {
      _record(
        build: t.buildDuration,
        raster: t.rasterDuration,
        budget: budget,
        now: Duration(
          microseconds: t.timestampInMicroseconds(FramePhase.rasterFinish),
        ),
      );
    }
  }

  void _record({
    required Duration build,
    required Duration raster,
    required Duration budget,
    required Duration now,
  }) {
    final changed = _engine.addFrame(
      build: build,
      raster: raster,
      budget: budget,
      now: now,
    );
    if (_engine.windowCompleted || changed != null) {
      _stats.value = _engine.stats;
    }
    if (changed != null) _update();
  }

  void _update({bool lockChanged = false}) {
    var next = _locked ?? _engine.level;
    final ceiling = _ceiling;
    if (_locked == null && ceiling != null && next > ceiling) next = ceiling;
    if (next == _value && !lockChanged) return;
    _value = next;
    notifyListeners();
  }

  static Duration _frameBudget() {
    final view =
        PlatformDispatcher.instance.implicitView ??
        PlatformDispatcher.instance.views.firstOrNull;
    var hz = view?.display.refreshRate ?? 60;
    if (!hz.isFinite || hz < 30) hz = 60;
    return Duration(microseconds: (1e6 / hz).round());
  }

  @override
  void dispose() {
    stop();
    _stats.dispose();
    super.dispose();
  }
}
