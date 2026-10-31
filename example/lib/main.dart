import 'dart:math' as math;

import 'package:fidelity/fidelity.dart';
import 'package:flutter/material.dart';

void main() => runApp(const FidelityScope(child: DemoApp()));

/// Starts from `?theme=light|dark` on web, otherwise follows the system.
final themeMode = ValueNotifier(switch (Uri.base.queryParameters['theme']) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
});

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'fidelity demo',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
        ),
        builder: (context, child) => FidelityDebugOverlay(child: child!),
        home: const DemoPage(),
      ),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage>
    with SingleTickerProviderStateMixin {
  late final _ticker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  /// Extra milliseconds of busy work per frame, to simulate a slow device.
  double _stressMs = 0;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = Fidelity.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glassTint = dark ? const Color(0x33FFFFFF) : const Color(0x59FFFFFF);
    final glassFallback = dark
        ? scheme.surfaceContainerHigh.withValues(alpha: 0.92)
        : scheme.surface.withValues(alpha: 0.9);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ticker,
              builder: (context, _) => CustomPaint(
                painter: _BackgroundPainter(
                  t: _ticker.value,
                  particles: level.pick(high: 260, medium: 90, low: 0),
                  stressMs: _stressMs,
                  dark: dark,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'fidelity',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Toggle theme',
                          icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
                          onPressed: () => themeMode.value = dark
                              ? ThemeMode.light
                              : ThemeMode.dark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drag the stress slider to slow down every frame. '
                      'Effects step down when frames get janky, and step '
                      'back up once things are smooth again.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    _Glass(
                      tint: glassTint,
                      fallback: glassFallback,
                      child: _StressControl(
                        value: _stressMs,
                        onChanged: (v) => setState(() => _stressMs = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Glass(
                      tint: glassTint,
                      fallback: glassFallback,
                      child: _LevelTable(level: level),
                    ),
                    const SizedBox(height: 16),
                    for (final (icon, title, body) in _cards) ...[
                      _Glass(
                        tint: glassTint,
                        fallback: glassFallback,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon, color: scheme.primary),
                          title: Text(title),
                          subtitle: Text(body),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _cards = [
    (
      Icons.blur_on,
      'AdaptiveBlur',
      'Full blur at high, lighter at medium, a solid panel at low.',
    ),
    (
      Icons.layers_outlined,
      'AdaptiveDecoratedBox',
      'Shadows soften at medium and disappear at low.',
    ),
    (
      Icons.auto_awesome,
      'level.pick(...)',
      'The background particle count comes from pick(): 260 / 90 / 0.',
    ),
    (
      Icons.touch_app_outlined,
      'Debug pill',
      'Tap the pill in the corner to lock a level. Each tap moves to the '
          'next one: low, medium, high, then back to auto.',
    ),
  ];
}

class _Glass extends StatelessWidget {
  const _Glass({
    required this.tint,
    required this.fallback,
    required this.child,
  });

  final Color tint;
  final Color fallback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return AdaptiveDecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: AdaptiveBlur(
        sigma: 24,
        tint: tint,
        fallbackColor: fallback,
        borderRadius: radius,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class _StressControl extends StatelessWidget {
  const _StressControl({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stress: ${value.toStringAsFixed(0)} ms of extra work per frame',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(value: value, max: 40, divisions: 40, onChanged: onChanged),
      ],
    );
  }
}

class _LevelTable extends StatelessWidget {
  const _LevelTable({required this.level});

  final FidelityLevel level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final l in FidelityLevel.values.reversed)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: l == level ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary),
              ),
              child: Text(
                l.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: l == level ? scheme.onPrimary : scheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({
    required this.t,
    required this.particles,
    required this.stressMs,
    required this.dark,
  });

  final double t;
  final int particles;
  final double stressMs;
  final bool dark;

  static const _blobColors = [
    Color(0xFF6C63FF),
    Color(0xFFFF6584),
    Color(0xFF00C2A8),
    Color(0xFFFFB547),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _burn(stressMs);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFF0E0F1A) : const Color(0xFFF2F1FA),
    );

    final a = t * 2 * math.pi;
    for (var i = 0; i < _blobColors.length; i++) {
      final phase = a + i * math.pi / 2;
      final center = Offset(
        size.width * (0.5 + 0.35 * math.cos(phase * (i.isEven ? 1 : -1))),
        size.height * (0.5 + 0.3 * math.sin(phase * 1.3)),
      );
      final r = size.shortestSide * 0.45;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _blobColors[i].withValues(alpha: dark ? 0.55 : 0.6),
              _blobColors[i].withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    final dot = Paint()
      ..color = (dark ? Colors.white : Colors.indigo).withValues(alpha: 0.35);
    final rng = math.Random(7);
    for (var i = 0; i < particles; i++) {
      final speed = 0.3 + rng.nextDouble();
      final x = (rng.nextDouble() + t * speed * 0.2) % 1.0;
      final y = (rng.nextDouble() + math.sin(a + i) * 0.02) % 1.0;
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        1 + rng.nextDouble() * 2,
        dot,
      );
    }
  }

  /// Spins the UI thread to simulate a slow device.
  static void _burn(double ms) {
    if (ms <= 0) return;
    final sw = Stopwatch()..start();
    while (sw.elapsedMicroseconds < ms * 1000) {}
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => true;
}
