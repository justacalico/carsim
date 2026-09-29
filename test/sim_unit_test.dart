import 'dart:math';

import 'package:carsim/sim/aero.dart';
import 'package:carsim/sim/car.dart';
import 'package:carsim/sim/driver_input.dart';
import 'package:carsim/sim/drivetrain.dart';
import 'package:carsim/sim/engine.dart';
import 'package:carsim/sim/environment.dart';
import 'package:carsim/sim/suspension.dart';
import 'package:carsim/sim/tire.dart';
import 'package:carsim/sim/track.dart';
import 'package:carsim/sim/vec2.dart';
import 'package:carsim/sim/wheel.dart';
import 'package:carsim/sim/wind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vec2', () {
    test('operators and geometry', () {
      const a = Vec2(3, 4);
      const b = Vec2(1, 2);
      expect((a + b).x, 4);
      expect((a - b).y, 2);
      expect((a * 2).x, 6);
      expect((a / 2).y, 2);
      expect((-a).x, -3);
      expect(a.dot(b), 11);
      expect(a.cross(b), closeTo(2, 1e-9));
      expect(a.length, 5);
      expect(a.lengthSquared, 25);
      expect(a.angle, closeTo(atan2(4, 3), 1e-9));
      expect(Vec2.zero.normalized(), Vec2.zero);
      expect(a.normalized().length, closeTo(1, 1e-9));
      expect(a.perp().dot(a), closeTo(0, 1e-9));
      expect(a.clamped(2).length, closeTo(2, 1e-9));
      expect(a.clamped(10), a);
      final r = const Vec2(1, 0).rotated(pi / 2);
      expect(r.y, closeTo(1, 1e-9));
    });
  });

  group('Engine', () {
    test('default firing order matches cylinder count', () {
      final e = Engine(cylinders: 6);
      expect(e.firingOrder, [0, 1, 2, 3, 4, 5]);
      expect(e.displacement, greaterThan(0));
    });

    test('cylinder pressure follows the four strokes', () {
      final e = Engine();
      e.ignitionOn = true;
      e.running = true;
      e.manifoldPressure = 190000;
      final charge = 1.5;
      final pIntake = e.cylinderPressure(0, 90, charge);
      final pCompression = e.cylinderPressure(0, 350, charge);
      final pPower = e.cylinderPressure(0, 390, charge);
      final pExhaust = e.cylinderPressure(0, 600, charge);
      expect(pIntake, closeTo(190000, 1));
      expect(pCompression, greaterThan(pIntake * 5));
      expect(pPower, greaterThan(0));
      expect(pExhaust, Engine.exhaustPressure);
      // Motored (not running) drops the combustion term.
      e.running = false;
      expect(e.cylinderPressure(0, 390, charge),
          lessThan(e.cylinderPressure(0, 390, 0.001) + 200000));
    });

    test('piston position and phase stay in range', () {
      final e = Engine();
      e.omega = 100;
      for (var i = 0; i < 500; i++) {
        e.step(0.001, 0, 0);
      }
      for (var c = 0; c < e.cylinders; c++) {
        expect(e.pistonPosition(c), inInclusiveRange(0, 1));
        expect(e.cyclePhase(c), inInclusiveRange(0, 720));
      }
    });

    test('rev limiter cuts fuel', () {
      final e = Engine();
      e.ignitionOn = true;
      e.running = true;
      e.omega = (e.redlineRpm + 500) * 2 * pi / 60;
      e.step(0.001, 1.0, 0);
      expect(e.running, isFalse);
    });

    test('throttle raises manifold pressure and builds boost', () {
      final e = Engine();
      e.ignitionOn = true;
      e.running = true;
      e.omega = 400; // ~3800 rpm
      for (var i = 0; i < 3000; i++) {
        e.step(0.001, 1.0, 0);
      }
      expect(e.manifoldPressure, greaterThan(Engine.ambientPressure));
      expect(e.boostPressure, greaterThan(0));
    });

    test('non-turbo engine never boosts', () {
      final e = Engine(turbo: false);
      e.ignitionOn = true;
      e.running = true;
      e.omega = 500;
      for (var i = 0; i < 500; i++) {
        e.step(0.001, 1.0, 0);
      }
      expect(e.boostPressure, 0);
    });

    test('ignition off kills the engine', () {
      final e = Engine();
      e.ignitionOn = true;
      e.omega = 200;
      e.step(0.001, 0, 0);
      expect(e.running, isTrue);
      e.ignitionOn = false;
      e.step(0.001, 0, 0);
      expect(e.running, isFalse);
    });

    test('temperature warms and cold friction applies', () {
      final e = Engine();
      e.ignitionOn = true;
      e.running = true;
      e.omega = 300;
      final before = e.temperature;
      for (var i = 0; i < 2000; i++) {
        e.step(0.001, 0.8, 0);
      }
      expect(e.temperature, greaterThan(before));
      expect(e.meanPistonSpeed, greaterThan(0));
    });
  });

  group('Drivetrain', () {
    test('shift request rules', () {
      final d = Drivetrain();
      expect(d.requestShift(1), isTrue);
      for (var i = 0; i < 200; i++) {
        d.step(0.001, 100, 0, 1000, 0, 0.16);
      }
      expect(d.gear, 1);
      expect(d.requestShift(1), isFalse); // same gear
      expect(d.requestShift(99), isFalse); // out of range
    });

    test('neutral transmits nothing', () {
      final d = Drivetrain(auto: false);
      d.gear = 0;
      expect(d.step(0.001, 300, 0, 3000, 0, 0.16), 0);
    });

    test('reverse gear ratio is negative', () {
      final d = Drivetrain(auto: false);
      d.gear = -1;
      expect(d.currentRatio, lessThan(0));
    });

    test('clutch pedal fully pressed decouples', () {
      final d = Drivetrain(auto: false);
      d.gear = 1;
      expect(d.step(0.001, 300, 1.0, 3000, 0, 0.16), 0);
    });

    test('manual clutch transmits torque when slipping', () {
      final d = Drivetrain(auto: false);
      d.gear = 1;
      d.outputOmega = 0;
      final t = d.step(0.001, 200, 0, 2000, 0.5, 0.16);
      expect(t, greaterThan(0));
      expect(d.wheelTorqueDemand, greaterThan(0));
    });

    test('torque converter at stall transmits torque without locking', () {
      final d = Drivetrain(auto: true);
      d.gear = 1;
      d.outputOmega = 0;
      final t = d.step(0.001, 200, 0, 2000, 0.5, 0.16);
      expect(t, greaterThan(0));
      // Converter creeps even at idle speeds.
      final tIdle = d.step(0.001, 95, 0, 900, 0, 0.16);
      expect(tIdle, greaterThan(0));
    });

    test('differential biases torque toward the slower wheel', () {
      final d = Drivetrain();
      d.gear = 1;
      d.wheelTorqueDemand = 1000;
      final (l, r) = d.splitTorque(50, 10);
      expect(l + r, closeTo(1000, 0.01));
      expect(r, greaterThan(l)); // right is slower, gets more
      final (l2, r2) = d.splitTorque(10, 50);
      expect(l2, greaterThan(r2));
      d.gear = 0;
      expect(d.splitTorque(1, 1), (0.0, 0.0));
    });

    test('syncOutput refers wheel speed through final drive', () {
      final d = Drivetrain();
      d.syncOutput(100, 100);
      expect(d.outputOmega, closeTo(100 * d.finalDrive, 0.001));
    });

    test('auto upshifts when locked at high rpm, downshifts low', () {
      final d = Drivetrain();
      d.gear = 1;
      // Lock the clutch then spin at upshift rpm.
      d.outputOmega = 8000 * 2 * pi / 60 / d.gearRatios[0];
      for (var i = 0; i < 600; i++) {
        d.step(0.001, 8000 * 2 * pi / 60, 0, 8000, 0.2, 0.16);
      }
      expect(d.gear, greaterThanOrEqualTo(2));
      // Lug it down.
      for (var i = 0; i < 4000; i++) {
        d.step(0.001, 1200 * 2 * pi / 60, 0, 1200, 0.1, 0.16);
      }
      expect(d.gear, lessThan(3));
    });
  });

  group('Tire', () {
    test('forces have physical signs', () {
      final t = Tire();
      final (fx, _) = t.forces(0.1, 0, 4000, 1.0, 10, 0.001);
      expect(fx, greaterThan(0)); // positive slip pushes forward
      final (fx2, _) = t.forces(-0.1, 0, 4000, 1.0, 10, 0.001);
      expect(fx2, lessThan(0));
      var fy = 0.0;
      for (var i = 0; i < 200; i++) {
        final r = t.forces(0, 0.1, 4000, 1.0, 10, 0.005);
        fy = r.$2;
      }
      expect(fy, lessThan(0)); // positive slip angle -> lateral resistance
    });

    test('unloaded tire returns zero', () {
      final t = Tire();
      expect(t.forces(0.5, 0.5, 0, 1.0, 10, 0.001), (0.0, 0.0));
    });

    test('combined slip stays inside the ellipse', () {
      final t = Tire();
      final (fx, fy) = t.forces(1.4, 0.6, 4000, 1.0, 20, 0.001);
      final cap = t.effectiveMu(1.0, 4000) * 4000 * 1.05;
      expect(sqrt(fx * fx + fy * fy), lessThanOrEqualTo(cap + 1));
    });

    test('temperature rises with slip work, mu changes with temp', () {
      final t = Tire();
      final coldMu = t.effectiveMu(1.0, 4000);
      for (var i = 0; i < 500; i++) {
        t.stepTemperature(0.001, 8000);
      }
      expect(t.temperature, greaterThan(20));
      final warmMu = t.effectiveMu(1.0, 4000);
      expect(warmMu, greaterThan(coldMu));
      for (var i = 0; i < 400000; i++) {
        t.stepTemperature(0.001, 50000);
      }
      expect(t.temperature, lessThanOrEqualTo(250));
      expect(t.effectiveMu(1.0, 4000),
          lessThan(warmMu)); // overheated loses grip
    });
  });

  group('Wheel', () {
    Wheel make() => Wheel(steerable: true, driven: true);

    test('accelerates under drive torque', () {
      final w = make();
      w.fz = 3500;
      for (var i = 0; i < 500; i++) {
        w.step(0.001, const Vec2(10, 0), 0.0, 400, 0.0, 1.0, false);
      }
      expect(w.omega, greaterThan(0));
    });

    test('brakes slow the wheel and heat the disc', () {
      final w = make();
      w.omega = 200;
      w.fz = 3500;
      for (var i = 0; i < 2000; i++) {
        w.step(0.001, const Vec2(60, 0), 0.0, 0.0, 1.0, 1.0, false);
      }
      expect(w.omega, lessThan(200));
      expect(w.brakeTemp, greaterThan(80));
    });

    test('ABS cycles when locked at speed', () {
      final w = make();
      w.fz = 3500;
      var sawAbs = false;
      for (var i = 0; i < 2000; i++) {
        w.step(0.001, const Vec2(30, 0), 0.0, 0.0, 1.0, 1.0, true);
        if (w.absActive) sawAbs = true;
      }
      expect(sawAbs, isTrue);
    });

    test('contact velocity adds yaw rate', () {
      final w = make();
      final v = w.contactVelocity(
          const Vec2(10, 0), 1.0, const Vec2(1, 0));
      expect(v.y, closeTo(1.0, 1e-9));
    });
  });

  group('Suspension', () {
    test('loads settle near static weight', () {
      final s = Suspension();
      s.reset(0.32);
      final bodyZ = [0.45, 0.45, 0.45, 0.45];
      final roadZ = [0.0, 0.0, 0.0, 0.0];
      List<double> loads = [];
      for (var i = 0; i < 4000; i++) {
        s.updateBodyVel(bodyZ, 0.001);
        loads = s.step(0.001, bodyZ, roadZ, 0.32, 3483);
      }
      for (final l in loads) {
        expect(l, inInclusiveRange(3000, 5500));
      }
    });
  });

  group('Aero', () {
    test('drag opposes motion and downforce grows with speed', () {
      final a = Aero();
      final f0 = a.step(const Vec2(0, 0), Vec2.zero, 0, 1.225);
      expect(f0.length, 0);
      final f = a.step(const Vec2(40, 0), Vec2.zero, 0, 1.225);
      expect(f.x, lessThan(0));
      expect(a.lastDownforce, greaterThan(0));
      expect(a.apparentWindSpeed, 40);
    });

    test('crosswind produces side force and yaw moment', () {
      final a = Aero();
      a.step(Vec2.zero, const Vec2(0, 8), 0, 1.225);
      expect(a.lastSideForce.abs(), greaterThan(0));
      expect(a.lastYawMoment.abs(), greaterThan(0));
    });
  });

  group('WindField', () {
    test('produces base wind plus turbulence and gusts', () {
      final w = WindField(turbulence: 1.0, gustRate: 50, gustStrength: 10);
      var gustSeen = 0.0;
      var base = 0.0;
      for (var i = 0; i < 20000; i++) {
        final v = w.sample(Vec2.zero, 0.001);
        base = v.length;
        if (v.length > 12) gustSeen = v.length;
      }
      expect(base, greaterThan(0));
      expect(gustSeen, greaterThan(12));
    });

    test('calm field matches base wind', () {
      final w = WindField(
          baseSpeed: 5, turbulence: 0, gustRate: 0, gustStrength: 0);
      final v = w.sample(Vec2.zero, 0.01);
      expect(v.length, closeTo(5, 0.01));
    });
  });

  group('Track', () {
    test('surface bands and progress', () {
      final t = Track();
      final (pos, heading) = t.spawn();
      expect(t.surfaceMu(pos), 1.0);
      expect(t.lateralOffset(pos), closeTo(0, 0.5));
      final off = pos + t.tangentAt(0).perp() * (t.halfWidth + 5);
      expect(t.surfaceMu(off), 0.45);
      final kerb = pos + t.tangentAt(0).perp() * (t.halfWidth + 0.5);
      expect(t.surfaceMu(kerb), 0.75);
      expect(t.progress(pos), closeTo(0, 2));
      // Far jump triggers the full-scan fallback.
      expect(t.nearestIndex(const Vec2(5000, 5000)), isA<int>());
      expect(t.totalLength, greaterThan(500));
      expect(heading.isFinite, isTrue);
    });
  });

  group('Environment', () {
    test('grip scale clamps surface mu', () {
      final e = Environment();
      e.gripScale = 5;
      expect(e.surfaceMu(Vec2.zero), 1.4);
      e.gripScale = 0.01;
      expect(e.surfaceMu(Vec2.zero), 0.15);
    });
  });

  group('Car', () {
    test('reverse gear drives backward', () {
      final car = Car(env: Environment());
      car.drivetrain.auto = false;
      final input = DriverInput()
        ..ignition = true
        ..starter = true;
      for (var i = 0; i < 2500 && car.engine.rpm < 850; i++) {
        car.step(0.001, input);
      }
      input.starter = false;
      input.throttle = 0.4;
      input.clutch = 1.0;
      car.drivetrain.requestShift(-1);
      for (var i = 0; i < 500; i++) {
        car.step(0.001, input);
      }
      for (var i = 0; i < 3000; i++) {
        input.clutch = max(0.0, 1.0 - i / 1500.0);
        car.step(0.001, input);
      }
      // Rolled backward relative to spawn heading.
      final fwd = Vec2(cos(car.yaw), sin(car.yaw));
      expect(car.vel.dot(fwd), lessThan(0));
    });

    test('steering input turns the car', () {
      final car = Car(env: Environment());
      final input = DriverInput()..ignition = true;
      // Get it rolling first.
      car.vel = const Vec2(15, 0);
      car.yaw = 0;
      input.steer = 1.0; // left
      for (var i = 0; i < 2000; i++) {
        car.step(0.001, input);
      }
      expect(car.yaw, greaterThan(0.1));
    });

    test('handbrake locks rear wheels', () {
      final car = Car(env: Environment());
      car.vel = const Vec2(20, 0);
      final input = DriverInput()
        ..ignition = true
        ..handbrake = true;
      for (var i = 0; i < 3000; i++) {
        car.step(0.001, input);
      }
      expect(car.wheels[2].omega.abs(), lessThan(5));
    });

    test('braking stops the car', () {
      final car = Car(env: Environment());
      car.vel = const Vec2(25, 0);
      for (final w in car.wheels) {
        w.omega = 25 / w.radius;
      }
      final input = DriverInput()
        ..ignition = true
        ..brake = 1.0;
      for (var i = 0; i < 8000; i++) {
        car.step(0.001, input);
      }
      expect(car.speed, lessThan(1.0));
    });

    test('manual gearbox honours clutch and gear requests', () {
      final car = Car(env: Environment());
      car.drivetrain.auto = false;
      final input = DriverInput()
        ..ignition = true
        ..gearUp = true;
      car.step(0.001, input);
      // Shift takes effect after shiftTime.
      for (var i = 0; i < 900; i++) {
        car.step(0.001, input);
      }
      expect(car.drivetrain.gear, 1);
      input.gearDown = true;
      car.step(0.001, input);
      for (var i = 0; i < 400; i++) {
        car.step(0.001, input);
      }
      expect(car.drivetrain.gear, 0);
    });

    test('reset returns to spawn', () {
      final car = Car(env: Environment());
      car.vel = const Vec2(30, 5);
      car.reset();
      expect(car.speed, 0);
      final (p, _) = car.env.track.spawn();
      expect(car.pos.x, closeTo(p.x, 0.01));
    });

    test('telemetry snapshot is populated', () {
      final car = Car(env: Environment());
      final t = car.snapshot();
      expect(t.pistonPos.length, car.engine.cylinders);
      expect(t.wheelLoad.length, 4);
      expect(t.gear, 0);
      expect(t.speedKmh, 0);
    });
  });
}
