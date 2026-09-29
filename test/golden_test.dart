import 'dart:math';

import 'package:carsim/app_state.dart';
import 'package:carsim/sim/vec2.dart';
import 'package:carsim/ui/sim_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Deterministic scene for golden screenshots: stepped with fixed dt and a
/// seeded particle layout, then frozen (running=false) so no wall-clock
/// jitter leaks in.
AppState goldenState() {
  final s = AppState();
  s.running = false;
  s.input.ignition = true;
  s.input.throttle = 0.35;
  for (var i = 0; i < 3000; i++) {
    s.input.starter = s.input.ignition && !s.car.engine.running;
    s.car.step(0.001, s.input);
  }
  s.telemetry = s.car.snapshot();
  s.simTime = const Duration(seconds: 42);
  s.currentLapStart = const Duration(seconds: 3);
  s.lastLap = const Duration(minutes: 1, seconds: 12, milliseconds: 830);
  s.bestLap = const Duration(minutes: 1, seconds: 10, milliseconds: 122);
  final rng = Random(7);
  for (var i = 0; i < 220; i++) {
    final a = rng.nextDouble() * 2 * pi;
    final r = 15 + rng.nextDouble() * 55;
    s.particles.add(s.car.pos + Vec2(cos(a) * r, sin(a) * r));
  }
  return s;
}

Widget harness(AppState s) {
  return ChangeNotifierProvider.value(
    value: s,
    child: const MaterialApp(home: SimScreen()),
  );
}

void main() {
  testWidgets('golden: wide desktop layout', (tester) async {
    final s = goldenState();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(s));
    await tester.pump();
    await expectLater(
      find.byType(SimScreen),
      matchesGoldenFile('goldens/wide.png'),
    );
    s.dispose();
  });

  testWidgets('golden: compact touch layout', (tester) async {
    final s = goldenState();
    tester.view.physicalSize = const Size(420, 840);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(s));
    await tester.pump();
    await expectLater(
      find.byType(SimScreen),
      matchesGoldenFile('goldens/compact.png'),
    );
    s.dispose();
  });
}
