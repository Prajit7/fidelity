import 'package:flutter/widgets.dart';

import 'fidelity_governor.dart';
import 'fidelity_level.dart';
import 'fidelity_policy.dart';

/// Provides a [FidelityGovernor] to the widget tree below it.
///
/// Place it once, above your `MaterialApp`:
///
/// ```dart
/// runApp(const FidelityScope(child: MyApp()));
/// ```
///
/// Then read the level anywhere with [Fidelity.of].
class FidelityScope extends StatefulWidget {
  /// Creates and owns a governor configured with these options.
  const FidelityScope({
    super.key,
    this.policy = const FidelityPolicy(),
    this.initial = FidelityLevel.high,
    this.min = FidelityLevel.low,
    this.max = FidelityLevel.high,
    required this.child,
  }) : governor = null;

  /// Uses an existing [governor]. The caller is responsible for disposing it.
  const FidelityScope.value({
    super.key,
    required FidelityGovernor this.governor,
    required this.child,
  }) : policy = const FidelityPolicy(),
       initial = FidelityLevel.high,
       min = FidelityLevel.low,
       max = FidelityLevel.high;

  final FidelityGovernor? governor;
  final FidelityPolicy policy;
  final FidelityLevel initial;
  final FidelityLevel min;
  final FidelityLevel max;
  final Widget child;

  @override
  State<FidelityScope> createState() => _FidelityScopeState();
}

class _FidelityScopeState extends State<FidelityScope> {
  FidelityGovernor? _owned;

  FidelityGovernor get _governor => widget.governor ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.governor == null) {
      _owned = FidelityGovernor(
        policy: widget.policy,
        initial: widget.initial,
        min: widget.min,
        max: widget.max,
      );
    }
    _governor.start();
  }

  @override
  void didUpdateWidget(FidelityScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.governor != oldWidget.governor) {
      if (widget.governor != null) {
        _owned?.dispose();
        _owned = null;
      } else {
        _owned = FidelityGovernor(
          policy: widget.policy,
          initial: widget.initial,
          min: widget.min,
          max: widget.max,
        );
      }
      _governor.start();
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FidelityInherited(notifier: _governor, child: widget.child);
  }
}

class _FidelityInherited extends InheritedNotifier<FidelityGovernor> {
  const _FidelityInherited({
    required FidelityGovernor super.notifier,
    required super.child,
  });
}

/// Static accessors for the nearest [FidelityScope].
abstract final class Fidelity {
  /// The current level. Rebuilds [context] when it changes.
  ///
  /// Returns [FidelityLevel.high] when there is no [FidelityScope], so
  /// adaptive widgets still render normally in isolation (e.g. in tests).
  static FidelityLevel of(BuildContext context) =>
      maybeGovernorOf(context)?.value ?? FidelityLevel.high;

  /// The nearest governor, or null if there is no [FidelityScope].
  /// Rebuilds [context] when the level changes.
  static FidelityGovernor? maybeGovernorOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_FidelityInherited>()
      ?.notifier;

  /// The nearest governor without subscribing to changes. Use it for
  /// actions like [FidelityGovernor.lock] from callbacks.
  static FidelityGovernor governorOf(BuildContext context) {
    final governor = context
        .getInheritedWidgetOfExactType<_FidelityInherited>()
        ?.notifier;
    assert(governor != null, 'No FidelityScope found in context');
    return governor!;
  }
}
