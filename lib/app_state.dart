import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'sim/car.dart';
import 'sim/driver_input.dart';
import 'sim/environment.dart';
import 'sim/telemetry.dart';
import 'sim/vec2.dart';
import 'sim/wind.dart';

/// Single source of truth for the app. Owns the simulation, the driver's
/// inputs and every user-facing setting. Lives above MaterialApp so window
/// resizes never touch it.
class AppState extends ChangeNotifier {
  AppState() {
    env = Environment(wind: WindField());
    car = Car(env: env);
    input = DriverInput();
    _timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  late final Environment env;
  late final Car car;
  late final DriverInput input;

  Timer? _timer;
  final _clock = Stopwatch()..start();

  bool running = true;
  bool cameraRotate = true; // camera follows car heading
  bool showEngine = true;

  /// Wind streak particles drawn around the car.
  final List<Vec2> particles = [];
  final _particleRng = Random(7);

  Telemetry? telemetry;
  Duration simTime = Duration.zero;

  // Lap timing.
  double _lastProgress = 0;
  Duration? currentLapStart;
  Duration? lastLap;
  Duration? bestLap;
  bool _startArmed = false;

  void _tick(Timer _) {
    if (!running) {
      _clock.reset();
      _clock.start();
      return;
    }
    final dt = (_clock.elapsedMicroseconds / 1e6).clamp(0.0, 0.05);
    _clock.reset();
    _clock.start();

    // Auto-crank: with ignition on, the starter runs until the engine holds.
    input.starter = input.ignition && !car.engine.running;

    car.step(dt, input);
    simTime += Duration(microseconds: (dt * 1e6).round());
    telemetry = car.snapshot();
    _advectParticles(dt);
    _checkLap();
    notifyListeners();
  }

  void _advectParticles(double dt) {
    final carPos = car.pos;
    // Spawn in a ring around the car.
    while (particles.length < 220) {
      final a = _particleRng.nextDouble() * 2 * pi;
      final r = 15 + _particleRng.nextDouble() * 55;
      particles.add(carPos + Vec2(cos(a) * r, sin(a) * r));
    }
    particles.removeWhere((p) => (p - carPos).lengthSquared > 90 * 90);
    for (var i = 0; i < particles.length; i++) {
      particles[i] += env.wind.lastWind * dt;
    }
  }

  void _checkLap() {
    final p = env.track.progress(car.pos);
    final l = env.track.totalLength;
    if (!_startArmed && p > l * 0.05) _startArmed = true;
    if (_startArmed && _lastProgress > l * 0.9 && p < l * 0.1) {
      final now = simTime;
      if (currentLapStart != null) {
        lastLap = now - currentLapStart!;
        if (bestLap == null || lastLap! < bestLap!) bestLap = lastLap;
      }
      currentLapStart = now;
    }
    _lastProgress = p;
  }

  void resetCar() {
    car.reset();
    currentLapStart = null;
    _startArmed = false;
    notifyListeners();
  }

  void togglePaused() {
    running = !running;
    notifyListeners();
  }

  void toggleAuto() {
    car.drivetrain.auto = !car.drivetrain.auto;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
