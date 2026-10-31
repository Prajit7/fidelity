import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import 'fidelity_level.dart';
import 'fidelity_scope.dart';

/// Builds with the current [FidelityLevel] and rebuilds when it changes.
class FidelityBuilder extends StatelessWidget {
  const FidelityBuilder({super.key, required this.builder, this.child});

  final Widget Function(
    BuildContext context,
    FidelityLevel level,
    Widget? child,
  )
  builder;

  /// Passed through to [builder] untouched, for subtrees that don't depend
  /// on the level.
  final Widget? child;

  @override
  Widget build(BuildContext context) =>
      builder(context, Fidelity.of(context), child);
}

/// Shows one of up to three widgets depending on the current level.
///
/// [medium] defaults to [high] when omitted.
class FidelitySwitch extends StatelessWidget {
  const FidelitySwitch({
    super.key,
    required this.high,
    this.medium,
    required this.low,
  });

  final Widget high;
  final Widget? medium;
  final Widget low;

  @override
  Widget build(BuildContext context) =>
      Fidelity.of(context).pick(high: high, medium: medium, low: low);
}

/// A frosted-glass panel that gets cheaper as the level drops.
///
/// * high: full backdrop blur at [sigma]
/// * medium: lighter blur ([sigma] × [mediumScale])
/// * low: no blur; a more opaque [fallbackColor] keeps text readable
class AdaptiveBlur extends StatelessWidget {
  const AdaptiveBlur({
    super.key,
    this.sigma = 20,
    this.mediumScale = 0.4,
    this.tint = const Color(0x40FFFFFF),
    this.fallbackColor,
    this.borderRadius = BorderRadius.zero,
    this.child,
  });

  final double sigma;
  final double mediumScale;

  /// Drawn over the blur at high and medium.
  final Color tint;

  /// Drawn instead of the blur at low. Defaults to [tint] at 85% opacity.
  final Color? fallbackColor;

  final BorderRadius borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final level = Fidelity.of(context);
    final content = child ?? const SizedBox.shrink();

    if (level == FidelityLevel.low) {
      final fallback =
          fallbackColor ?? tint.withValues(alpha: math.max(tint.a, 0.85));
      return DecoratedBox(
        decoration: BoxDecoration(color: fallback, borderRadius: borderRadius),
        child: content,
      );
    }

    final s = level == FidelityLevel.high ? sigma : sigma * mediumScale;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: s, sigmaY: s),
        child: DecoratedBox(
          decoration: BoxDecoration(color: tint),
          child: content,
        ),
      ),
    );
  }
}

/// A [DecoratedBox] whose shadows soften at medium and disappear at low.
class AdaptiveDecoratedBox extends StatelessWidget {
  const AdaptiveDecoratedBox({super.key, required this.decoration, this.child});

  final BoxDecoration decoration;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final level = Fidelity.of(context);
    return DecoratedBox(
      decoration: decoration.copyWith(
        boxShadow: adaptShadows(decoration.boxShadow, level),
      ),
      child: child,
    );
  }
}

/// Scales [shadows] for [level]: unchanged at high, a single shadow with half
/// the blur at medium, none at low.
List<BoxShadow>? adaptShadows(List<BoxShadow>? shadows, FidelityLevel level) {
  if (shadows == null || shadows.isEmpty) return shadows;
  return switch (level) {
    FidelityLevel.high => shadows,
    FidelityLevel.medium => [
      shadows.first.copyWith(blurRadius: shadows.first.blurRadius / 2),
    ],
    FidelityLevel.low => const [],
  };
}
