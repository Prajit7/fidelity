/// Runtime quality governor for Flutter: watches frame timings and steps
/// expensive effects (blur, shadows, particles) down when the device
/// struggles, then back up when it recovers.
library;

export 'src/debug_overlay.dart';
export 'src/fidelity_engine.dart';
export 'src/fidelity_governor.dart';
export 'src/fidelity_level.dart';
export 'src/fidelity_policy.dart';
export 'src/fidelity_scope.dart';
export 'src/widgets.dart';
