import 'package:fidelity/fidelity.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(FidelityGovernor governor, Widget child) => FidelityScope.value(
  governor: governor,
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

void main() {
  test('governor: lock overrides, ceiling caps, unlock restores', () {
    final g = FidelityGovernor();
    addTearDown(g.dispose);
    var notified = 0;
    g.addListener(() => notified++);

    g.ceiling = FidelityLevel.medium;
    expect(g.value, FidelityLevel.medium);

    g.lock(FidelityLevel.high);
    expect(g.value, FidelityLevel.high, reason: 'lock ignores ceiling');

    g.unlock();
    expect(g.value, FidelityLevel.medium);

    g.lock(FidelityLevel.medium);
    expect(notified, 4, reason: 'same-value lock still notifies');
  });

  testWidgets('Fidelity.of defaults to high without a scope', (tester) async {
    late FidelityLevel seen;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          seen = Fidelity.of(context);
          return const SizedBox();
        },
      ),
    );
    expect(seen, FidelityLevel.high);
  });

  testWidgets('FidelitySwitch rebuilds when the level changes', (tester) async {
    final g = FidelityGovernor();
    addTearDown(g.dispose);
    await tester.pumpWidget(
      _app(g, const FidelitySwitch(high: Text('high'), low: Text('low'))),
    );
    expect(find.text('high'), findsOneWidget);

    g.lock(FidelityLevel.low);
    await tester.pump();
    expect(find.text('low'), findsOneWidget);

    g.lock(FidelityLevel.medium);
    await tester.pump();
    expect(find.text('high'), findsOneWidget, reason: 'medium falls back');
  });

  testWidgets('AdaptiveBlur drops BackdropFilter at low', (tester) async {
    final g = FidelityGovernor();
    addTearDown(g.dispose);
    await tester.pumpWidget(_app(g, const AdaptiveBlur(child: Text('x'))));
    expect(find.byType(BackdropFilter), findsOneWidget);

    g.lock(FidelityLevel.low);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('x'), findsOneWidget);
  });

  test('adaptShadows softens then removes shadows', () {
    const shadows = [BoxShadow(blurRadius: 20), BoxShadow(blurRadius: 4)];
    expect(adaptShadows(shadows, FidelityLevel.high), shadows);
    final medium = adaptShadows(shadows, FidelityLevel.medium)!;
    expect(medium, hasLength(1));
    expect(medium.single.blurRadius, 10);
    expect(adaptShadows(shadows, FidelityLevel.low), isEmpty);
  });

  testWidgets('debug overlay cycles the lock on tap', (tester) async {
    final g = FidelityGovernor();
    addTearDown(g.dispose);
    await tester.pumpWidget(
      _app(g, const FidelityDebugOverlay(child: SizedBox.expand())),
    );
    expect(find.textContaining('HIGH · auto'), findsOneWidget);

    await tester.tap(find.textContaining('HIGH'));
    await tester.pump();
    expect(g.locked, FidelityLevel.low);
    expect(find.textContaining('LOW · locked'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.textContaining('·'));
      await tester.pump();
    }
    expect(g.locked, isNull);
  });
}
