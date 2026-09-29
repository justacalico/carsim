import 'dart:math';

import 'package:carsim/sim/car.dart';
import 'package:carsim/sim/driver_input.dart';
import 'package:carsim/sim/engine.dart';
import 'package:carsim/sim/environment.dart';
import 'package:flutter_test/flutter_test.dart';

double _wrapAngle(double a) {
  while (a > pi) a -= 2 * pi;
  while (a < -pi) a += 2 * pi;
  return a;
}

void main() {
  test('engine cranks, idles, and drives the car through gears', () {
    final car = Car(env: Environment());
    final input = DriverInput()..ignition = true;

    input.starter = true;
    for (var i = 0; i < 3000 && car.engine.rpm < 850; i++) {
      car.step(0.001, input);
    }
    input.starter = false;
    for (var i = 0; i < 4000; i++) {
      car.step(0.001, input);
    }

    expect(car.engine.running, isTrue);
    expect(car.engine.rpm, inInclusiveRange(500, 1600));

    input.throttle = 1.0;
    car.drivetrain.requestShift(1);
    var maxSpeed = 0.0;
    for (var i = 0; i < 20000; i++) {
      // Crude autopilot: hold the centerline so the run stays on track.
      final track = car.env.track;
      final idx = track.nearestIndex(car.pos);
      final headErr =
          _wrapAngle(track.tangentAt(idx).angle - car.yaw);
      final latErr = track.lateralOffset(car.pos);
      input.steer = (headErr * 0.9 - latErr * 0.04).clamp(-1.0, 1.0);
      if (car.speedKmh > 90) input.throttle = 0.4;
      car.step(0.001, input);
      if (car.speedKmh > maxSpeed) maxSpeed = car.speedKmh;
    }

    expect(maxSpeed, greaterThan(60));
    expect(car.drivetrain.gear, greaterThanOrEqualTo(2));
    expect(car.engine.fuelUsedGrams, greaterThan(0));
  });

  test('engine alone holds a stable idle', () {
    final e = Engine();
    e.ignitionOn = true;
    for (var i = 0; i < 8000; i++) {
      e.starterEngaged = i < 800;
      e.step(0.001, 0, 0);
    }
    expect(e.running, isTrue);
    expect(e.rpm, inInclusiveRange(600, 1400));
  });
}
