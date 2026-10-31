import 'package:flutter/widgets.dart';

import 'fidelity_engine.dart';
import 'fidelity_governor.dart';
import 'fidelity_level.dart';
import 'fidelity_scope.dart';

/// A small pill showing the current level and jank, for development.
///
/// Tap it to cycle a lock: auto → low → medium → high → auto.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => FidelityDebugOverlay(child: child!),
/// )
/// ```
class FidelityDebugOverlay extends StatelessWidget {
  const FidelityDebugOverlay({
    super.key,
    this.enabled = true,
    this.alignment = AlignmentDirectional.bottomStart,
    required this.child,
  });

  /// Set to `kDebugMode` to hide it in release builds.
  final bool enabled;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final governor = Fidelity.maybeGovernorOf(context);
    if (governor == null) return child;

    return Stack(
      children: [
        child,
        SafeArea(
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _Pill(governor: governor),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.governor});

  final FidelityGovernor governor;

  static const _colors = {
    FidelityLevel.high: Color(0xFF2E9E5B),
    FidelityLevel.medium: Color(0xFFD08A1A),
    FidelityLevel.low: Color(0xFFC8423B),
  };

  void _cycle() {
    switch (governor.locked) {
      case null:
        governor.lock(FidelityLevel.low);
      case FidelityLevel.high:
        governor.unlock();
      case final level:
        governor.lock(level.higher);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _cycle,
      child: ValueListenableBuilder<FidelityStats>(
        valueListenable: governor.stats,
        builder: (context, stats, _) {
          final level = governor.value;
          final mode = governor.locked != null ? 'locked' : 'auto';
          final jank = (stats.lastJankRatio * 100).toStringAsFixed(0);
          final budget = (stats.frameBudget.inMicroseconds / 1000)
              .toStringAsFixed(1);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xE6151515),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _colors[level],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${level.name.toUpperCase()} · $mode · '
                    'jank $jank% · ${budget}ms',
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 12,
                      fontFamily: 'monospace',
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
