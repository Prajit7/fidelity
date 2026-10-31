import 'package:fidelity/fidelity.dart';
import 'package:flutter_test/flutter_test.dart';

const budget = Duration(microseconds: 16667);
const smooth = Duration(milliseconds: 8);
const janky = Duration(milliseconds: 30);
const frameGap = Duration(microseconds: 16667);

const policy = FidelityPolicy(
  windowSize: 10,
  stableWindowsToUpgrade: 2,
  warmupFrames: 0,
  cooldown: Duration(milliseconds: 500),
  flapWindow: Duration(seconds: 5),
);

/// Drives an engine with a fake clock.
class Harness {
  Harness({
    FidelityLevel initial = FidelityLevel.high,
    FidelityPolicy p = policy,
  }) : engine = FidelityEngine(policy: p, initial: initial);

  final FidelityEngine engine;
  Duration now = Duration.zero;
  final changes = <FidelityLevel>[];

  void frames(int count, {Duration build = smooth}) {
    for (var i = 0; i < count; i++) {
      now += frameGap;
      final c = engine.addFrame(
        build: build,
        raster: smooth,
        budget: budget,
        now: now,
      );
      if (c != null) changes.add(c);
    }
  }

  void wait(Duration d) => now += d;
}

void main() {
  test('stays high while frames are smooth', () {
    final h = Harness()..frames(200);
    expect(h.engine.level, FidelityLevel.high);
    expect(h.changes, isEmpty);
  });

  test('steps down one level when a window is janky', () {
    final h = Harness()..frames(10, build: janky);
    expect(h.changes, [FidelityLevel.medium]);
  });

  test('ignores frames during cooldown after a change', () {
    final h = Harness()..frames(10, build: janky);
    // ~30 frames ≈ 500ms of cooldown; janky frames here must not count.
    h.frames(29, build: janky);
    expect(h.changes, [FidelityLevel.medium]);
    h.frames(11, build: janky);
    expect(h.changes, [FidelityLevel.medium, FidelityLevel.low]);
  });

  test('never goes below min or above max', () {
    final h = Harness();
    for (var i = 0; i < 10; i++) {
      h.frames(10, build: janky);
      h.wait(const Duration(seconds: 1));
    }
    expect(h.engine.level, FidelityLevel.low);

    final capped = FidelityEngine(
      policy: policy,
      initial: FidelityLevel.low,
      max: FidelityLevel.medium,
    );
    var now = Duration.zero;
    for (var i = 0; i < 500; i++) {
      now += frameGap;
      capped.addFrame(build: smooth, raster: smooth, budget: budget, now: now);
    }
    expect(capped.level, FidelityLevel.medium);
  });

  test('steps up only after enough consecutive stable windows', () {
    final h = Harness(initial: FidelityLevel.low)..frames(10);
    expect(h.engine.level, FidelityLevel.low);
    h.frames(10);
    expect(h.changes, [FidelityLevel.medium]);
  });

  test('a middling window resets progress toward stepping up', () {
    final h = Harness(initial: FidelityLevel.low)..frames(10);
    // 1 janky frame in 10 = 10%: between the thresholds.
    h
      ..frames(9)
      ..frames(1, build: janky)
      ..frames(10);
    expect(h.engine.level, FidelityLevel.low);
    h.frames(10);
    expect(h.engine.level, FidelityLevel.medium);
  });

  test('raster jank counts as well as build jank', () {
    final engine = FidelityEngine(policy: policy);
    var now = Duration.zero;
    FidelityLevel? change;
    for (var i = 0; i < 10; i++) {
      now += frameGap;
      change ??= engine.addFrame(
        build: smooth,
        raster: janky,
        budget: budget,
        now: now,
      );
    }
    expect(change, FidelityLevel.medium);
  });

  test('a failed step up doubles the stable windows needed next time', () {
    final h = Harness(initial: FidelityLevel.medium);
    expect(h.engine.stats.stableWindowsNeeded, 2);

    h.frames(20); // two stable windows -> high
    expect(h.engine.level, FidelityLevel.high);
    h
      ..wait(const Duration(seconds: 1))
      ..frames(10, build: janky); // drops back within the flap window
    expect(h.engine.level, FidelityLevel.medium);
    expect(h.engine.stats.stableWindowsNeeded, 4);
  });

  test('backoff relaxes once a step up holds', () {
    final h = Harness(initial: FidelityLevel.medium);
    h
      ..frames(20)
      ..wait(const Duration(seconds: 1))
      ..frames(10, build: janky);
    expect(h.engine.stats.stableWindowsNeeded, 4);

    h
      ..wait(const Duration(seconds: 1))
      ..frames(40); // four stable windows -> high again
    expect(h.engine.level, FidelityLevel.high);
    h
      ..wait(const Duration(seconds: 6))
      ..frames(10);
    expect(h.engine.stats.stableWindowsNeeded, 2);
  });

  test('warmup frames are ignored', () {
    final engine = FidelityEngine(
      policy: const FidelityPolicy(windowSize: 10, warmupFrames: 15),
    );
    var now = Duration.zero;
    for (var i = 0; i < 15; i++) {
      now += frameGap;
      expect(
        engine.addFrame(build: janky, raster: janky, budget: budget, now: now),
        isNull,
      );
    }
    expect(engine.stats.framesObserved, 0);
  });

  test('pick returns per-level values, medium defaults to high', () {
    expect(FidelityLevel.low.pick(high: 3, medium: 2, low: 1), 1);
    expect(FidelityLevel.medium.pick(high: 3, medium: 2, low: 1), 2);
    expect(FidelityLevel.medium.pick(high: 3, low: 1), 3);
    expect(FidelityLevel.low < FidelityLevel.high, isTrue);
    expect(FidelityLevel.high.higher, FidelityLevel.high);
    expect(FidelityLevel.low.lower, FidelityLevel.low);
  });
}
