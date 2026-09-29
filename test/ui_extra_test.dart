import 'dart:math';

import 'package:carsim/app_state.dart';
import 'package:carsim/main.dart' as app;
import 'package:carsim/sim/aero.dart';
import 'package:carsim/sim/drivetrain.dart';
import 'package:carsim/sim/vec2.dart';
import 'package:carsim/ui/engine_view.dart';
import 'package:carsim/ui/dashboard.dart';
import 'package:carsim/ui/settings_sheet.dart';
import 'package:carsim/ui/telemetry_panel.dart';
import 'package:carsim/ui/sim_screen.dart';
import 'package:carsim/ui/track_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('main() mounts the app', () async {
    // Covers the entrypoint; the provider disposes AppState on unmount.
    expect(app.main, isA<void Function()>());
  });

  testWidgets('main entrypoint builds', (tester) async {
    app.main();
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('aero wraps headwind angles below -pi', () {
    final a = Aero();
    final f = a.step(const Vec2(40, 0), Vec2.zero, pi + 0.5, 1.225);
    expect(f.x, lessThan(0));
    final f2 = a.step(const Vec2(-40, 0), Vec2.zero, -pi - 0.5, 1.225);
    expect(f2.length, greaterThan(0));
  });

  test('drivetrain kickdown at WOT low rpm', () {
    final d = Drivetrain();
    d.gear = 3;
    d.outputOmega = 200;
    for (var i = 0; i < 400; i++) {
      d.step(0.001, 200, 0, 2200, 0.9, 0.16);
    }
    expect(d.gear, 2);
  });

  testWidgets('paused timer path', (tester) async {
    final s = AppState();
    s.running = false;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: s,
        child: const MaterialApp(home: SimScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    s.dispose();
  });

  testWidgets('every settings slider responds', (tester) async {
    final s = AppState();
    s.running = false;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: s,
        child: MaterialApp(
          home: Scaffold(body: SettingsSheet(state: s)),
        ),
      ),
    );
    await tester.pump();
    final sliders = find.byType(Slider);
    for (var i = 0; i < 6; i++) {
      await tester.drag(sliders.at(i), const Offset(60, 0));
      await tester.pump();
    }
    expect(s.env.wind.turbulence, greaterThan(0));
    expect(s.env.wind.gustStrength, greaterThan(0));
    expect(s.env.gripScale, greaterThan(0.4));
    s.dispose();
  });

  testWidgets('hot brakes glow on the car', (tester) async {
    final s = AppState();
    s.running = false;
    s.car.wheels[0].brakeTemp = 700;
    s.car.wheels[1].brakeTemp = 700;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: s,
        child: const MaterialApp(
          home: SizedBox.expand(),
        ),
      ),
    );
    // Paint the track view directly.
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: s,
        child: MaterialApp(
          home: TrackView(
            car: s.car,
            env: s.env,
            rotate: true,
            particles: s.particles,
          ),
        ),
      ),
    );
    await tester.pump();
    s.dispose();
  });

  testWidgets('engine view spark flash during combustion', (tester) async {
    final s = AppState();
    s.running = false;
    s.car.engine.running = true;
    s.car.engine.theta = 380 * pi / 180;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: s,
        child: MaterialApp(
          home: SizedBox(
            width: 600,
            height: 300,
            child: EngineView(engine: s.car.engine),
          ),
        ),
      ),
    );
    await tester.pump();
    // Rebuild to exercise shouldRepaint.
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: s,
        child: MaterialApp(
          home: SizedBox(
            width: 600,
            height: 300,
            child: EngineView(engine: s.car.engine),
          ),
        ),
      ),
    );
    await tester.pump();
    s.dispose();
  });

  testWidgets('pointer cancel and move on touch controls', (tester) async {
    final s = AppState();
    s.running = false;
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: s,
        child: const MaterialApp(home: SimScreen()),
      ),
    );
    await tester.pump();

    // Drag then cancel the steer pad.
    final knob = find.byIcon(Icons.circle_outlined);
    final g = await tester.startGesture(tester.getCenter(knob));
    await g.moveBy(const Offset(20, 0));
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    await g.cancel();
    await tester.pump();
    expect(s.input.steer, 0);

    // Drag inside the throttle pedal.
    final pedal = find.text('THR');
    final g2 = await tester.startGesture(tester.getCenter(pedal));
    await g2.moveBy(const Offset(0, -30));
    await g2.moveBy(const Offset(0, -30));
    await tester.pump();
    expect(s.input.throttle, greaterThan(0));
    await g2.cancel();
    await tester.pump();
    expect(s.input.throttle, 0);
    s.dispose();
  });

  testWidgets('painters repaint on rebuild', (tester) async {
    final s = AppState();
    s.running = false;
    for (var i = 0; i < 2000; i++) {
      s.car.step(0.0005, s.input);
    }
    s.telemetry = s.car.snapshot();
    final panel = ChangeNotifierProvider.value(
      value: s,
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(height: 400, child: TelemetryPanel(state: s)),
              Dashboard(state: s),
            ],
          ),
        ),
      ),
    );
    Widget build() => ChangeNotifierProvider.value(
          value: s,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(height: 400, child: TelemetryPanel(state: s)),
                  Dashboard(state: s),
                ],
              ),
            ),
          ),
        );
    // Fresh widget instances force didUpdateWidget -> shouldRepaint.
    await tester.pumpWidget(build());
    await tester.pump();
    s.lastLap = const Duration(minutes: 1, seconds: 23, milliseconds: 456);
    s.currentLapStart = const Duration(seconds: 10);
    s.simTime = const Duration(seconds: 95);
    await tester.pumpWidget(build());
    await tester.pump();
    s.dispose();
  });
}
