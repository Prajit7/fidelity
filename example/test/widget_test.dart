import 'package:fidelity/fidelity.dart';
import 'package:fidelity_example/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo renders and reacts to a locked level', (tester) async {
    final governor = FidelityGovernor();
    addTearDown(governor.dispose);
    await tester.pumpWidget(
      FidelityScope.value(governor: governor, child: const DemoApp()),
    );
    expect(find.text('fidelity'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);

    governor.lock(FidelityLevel.low);
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
