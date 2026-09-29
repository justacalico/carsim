import 'package:carsim/app_state.dart';
import 'package:carsim/ui/controls.dart';
import 'package:carsim/ui/dashboard.dart';
import 'package:carsim/ui/engine_view.dart';
import 'package:carsim/ui/settings_sheet.dart';
import 'package:carsim/ui/sim_screen.dart';
import 'package:carsim/ui/telemetry_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget wrap(AppState s, Widget child, {Size size = const Size(1200, 800)}) {
  return ChangeNotifierProvider.value(
    value: s,
    child: MaterialApp(
      home: SizedBox(width: size.width, height: size.height, child: child),
    ),
  );
}

AppState started() {
  final s = AppState();
  s.input.ignition = true;
  // Step the sim deterministically so telemetry exists.
  for (var i = 0; i < 4000; i++) {
    s.car.step(0.0005, s.input);
  }
  s.telemetry = s.car.snapshot();
  return s;
}

void main() {
  testWidgets('sim screen builds wide and compact', (tester) async {
    final s = started();

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(s, const SimScreen()));
    await tester.pump();
    expect(find.byType(TelemetryPanel), findsOneWidget);
    expect(find.byType(Dashboard), findsOneWidget);
    expect(find.byType(EngineView), findsOneWidget);

    tester.view.physicalSize = const Size(500, 900);
    await tester.pumpWidget(wrap(s, const SimScreen()));
    await tester.pump();
    expect(find.byType(TouchControls), findsOneWidget);
    s.dispose();
  });

  testWidgets('keyboard controls drive inputs', (tester) async {
    final s = AppState();
    s.running = false;
    await tester.pumpWidget(wrap(s, const SimScreen()));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    expect(s.input.throttle, 1.0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect(s.input.throttle, 0.0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    expect(s.input.brake, 1.0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    expect(s.input.steer, 1.0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    expect(s.input.steer, 0.0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
    expect(s.input.clutch, 1.0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    expect(s.input.handbrake, isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);

    expect(s.input.ignition, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
    expect(s.input.ignition, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyE);
    expect(s.input.gearUp, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
    expect(s.input.gearDown, isTrue);

    expect(s.car.drivetrain.auto, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyM);
    expect(s.car.drivetrain.auto, isFalse);

    expect(s.running, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP);
    expect(s.running, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyR);
    expect(s.car.speed, 0);
    s.dispose();
  });

  testWidgets('touch pedals and steer pad set inputs', (tester) async {
    final s = AppState();
    s.running = false;
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(s, const SimScreen()));
    await tester.pump();

    final knob = find.byIcon(Icons.circle_outlined);
    expect(knob, findsOneWidget);
    // Hold the drag so the end-callback does not reset steer yet.
    final g = await tester.startGesture(tester.getCenter(knob));
    await g.moveBy(const Offset(20, 0));
    await g.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(s.input.steer, isNot(0));
    await g.up();
    await tester.pump();
    expect(s.input.steer, 0);

    final thr = await tester.press(find.text('THR'));
    await tester.pump();
    expect(s.input.throttle, greaterThan(0));
    await thr.up();
    await tester.pump();
    expect(s.input.throttle, 0.0);

    final brk = await tester.press(find.text('BRK'));
    await tester.pump();
    expect(s.input.brake, greaterThan(0));
    await brk.up();
    await tester.pump();
    expect(s.input.brake, 0.0);
    s.dispose();
  });

  testWidgets('settings sheet mutates environment', (tester) async {
    final s = AppState();
    s.running = false;
    await tester.pumpWidget(
      wrap(s, Scaffold(body: SettingsSheet(state: s))),
    );
    await tester.pump();

    expect(find.text('wind speed'), findsOneWidget);
    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(100, 0));
    await tester.pump();
    expect(s.env.wind.baseSpeed, greaterThan(0));

    // Switches in order: auto, ABS, TCS, camera, cutaway.
    final switches = find.byType(Switch);
    await tester.tap(switches.at(0));
    expect(s.car.drivetrain.auto, isFalse);
    await tester.tap(switches.at(1));
    expect(s.input.absEnabled, isFalse);
    await tester.tap(switches.at(2));
    expect(s.input.tcsEnabled, isFalse);
    await tester.tap(switches.at(3));
    expect(s.cameraRotate, isFalse);
    await tester.tap(switches.at(4));
    expect(s.showEngine, isFalse);
    s.dispose();
  });

  testWidgets('toolbar buttons work', (tester) async {
    final s = AppState();
    s.running = false;
    await tester.pumpWidget(wrap(s, const SimScreen()));
    await tester.pump();

    await tester.tap(find.text('IGN'));
    expect(s.input.ignition, isTrue);

    await tester.tap(find.text('RESET'));

    await tester.tap(find.text('RUN'));
    expect(s.running, isTrue);

    await tester.tap(find.text('AUTO'));
    expect(s.car.drivetrain.auto, isFalse);

    await tester.tap(find.text('+'));
    expect(s.input.gearUp, isTrue);
    await tester.tap(find.text('-'));
    expect(s.input.gearDown, isTrue);

    await tester.tap(find.text('SETUP'));
    await tester.pumpAndSettle();
    expect(find.text('wind speed'), findsOneWidget);
    await tester.pumpWidget(Container());
    s.dispose();
  });

  testWidgets('standalone panels render', (tester) async {
    final s = started();
    await tester.pumpWidget(wrap(s, TelemetryPanel(state: s)));
    await tester.pump();
    expect(find.text('ENGINE'), findsOneWidget);

    await tester.pumpWidget(
      wrap(s, SizedBox(height: 140, child: EngineView(engine: s.car.engine))),
    );
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
    s.dispose();
  });

  testWidgets('lap timing counts crossings of the start line',
      (tester) async {
    final s = AppState();
    await tester.pumpWidget(wrap(s, const SimScreen()));
    // Let a few real frames tick.
    await tester.pump(const Duration(milliseconds: 50));
    final track = s.env.track;
    final n = track.centerline.length;

    for (var lap = 0; lap < 2; lap++) {
      s.car.pos = track.centerline[(n * 95 ~/ 100)];
      await tester.pump(const Duration(milliseconds: 30));
      s.car.pos = track.centerline[(n * 5 ~/ 100)];
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(s.currentLapStart, isNotNull);
    expect(s.lastLap, isNotNull);
    expect(s.bestLap, isNotNull);
    await tester.pump(const Duration(milliseconds: 20));
    s.dispose();
  });
}
