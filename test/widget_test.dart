import 'package:carsim/app_state.dart';
import 'package:carsim/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('app builds and sim ticks', (tester) async {
    final state = AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const CarSimApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(state.telemetry, isNotNull);
    state.dispose();
  });
}
