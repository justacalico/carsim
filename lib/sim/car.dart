import 'dart:math';

import 'aero.dart';
import 'driver_input.dart';
import 'drivetrain.dart';
import 'engine.dart';
import 'environment.dart';
import 'suspension.dart';
import 'telemetry.dart';
import 'vec2.dart';
import 'wheel.dart';

/// The whole car. Chassis is a planar rigid body (x, y, yaw) plus secondary
/// heave/pitch/roll degrees of freedom that carry the suspension. Order of
/// wheels everywhere is [front-left, front-right, rear-left, rear-right].
class Car {
  Car({
    required this.env,
    this.mass = 1420,
    this.yawInertia = 2350,
    this.cgHeight = 0.52,
    this.frontAxle = 1.24,
    this.rearAxle = 1.46,
    this.trackWidth = 1.58,
    this.maxSteer = 0.62,
    this.fuelCapacityKg = 48,
    Engine? engine,
    Drivetrain? drivetrain,
    Suspension? suspension,
    Aero? aero,
  })  : engine = engine ?? Engine(),
        drivetrain = drivetrain ?? Drivetrain(),
        suspension = suspension ?? Suspension(),
        aero = aero ?? Aero() {
    final halfT = trackWidth / 2;
    relPos = [
      Vec2(frontAxle, halfT),
      Vec2(frontAxle, -halfT),
      Vec2(-rearAxle, halfT),
      Vec2(-rearAxle, -halfT),
    ];
    wheels = [
      Wheel(steerable: true, driven: false),
      Wheel(steerable: true, driven: false),
      Wheel(steerable: false, driven: true),
      Wheel(steerable: false, driven: true),
    ];
    reset();
  }

  final Environment env;
  final double mass;
  final double yawInertia;
  final double cgHeight;
  final double frontAxle;
  final double rearAxle;
  final double trackWidth;
  final double maxSteer;
  final double fuelCapacityKg;

  final Engine engine;
  final Drivetrain drivetrain;
  final Suspension suspension;
  final Aero aero;

  late final List<Vec2> relPos; // wheel offsets from CG, body frame
  late final List<Wheel> wheels;

  // Chassis state.
  Vec2 pos = Vec2.zero;
  Vec2 vel = Vec2.zero; // world frame
  double yaw = 0;
  double yawRate = 0;

  // Secondary body DOF.
  double heave = 0; // CG height above static, m
  double heaveVel = 0;
  double pitch = 0; // + = nose up
  double pitchVel = 0;
  double roll = 0; // + = lean left
  double rollVel = 0;

  double wheelbase() => frontAxle + rearAxle;

  double get currentMass =>
      mass + fuelCapacityKg - engine.fuelUsedGrams / 1000;

  double get speed => vel.length;
  double get speedKmh => speed * 3.6;

  /// World-frame acceleration from the last substep, for telemetry.
  Vec2 lastAccel = Vec2.zero;

  /// Net tire + aero force in world frame from the last substep.
  Vec2 lastForce = Vec2.zero;
  double lastMoment = 0;

  void reset() {
    final (p, h) = env.track.spawn();
    pos = p;
    vel = Vec2.zero;
    yaw = h;
    yawRate = 0;
    heave = heaveVel = pitch = pitchVel = roll = rollVel = 0;
    for (final w in wheels) {
      w.omega = 0;
      w.fz = currentMass * 9.81 / 4;
    }
    engine.theta = 0;
    engine.omega = 0;
    engine.running = false;
    drivetrain.outputOmega = 0;
    drivetrain.gear = 0;
    suspension.reset(wheels[0].radius);
  }

  /// Full vehicle step. Internally substeps at <= 0.5 ms so the crank,
  /// clutch and tire transients stay stable.
  void step(double dt, DriverInput input) {
    final n = max(1, (dt / 0.0005).ceil());
    final h = dt / n;
    for (var i = 0; i < n; i++) {
      _substep(h, input);
    }
    input.consumeGears();
  }

  void _substep(double dt, DriverInput input) {
    // Steering: Ackermann geometry, gentler at speed.
    final steerMax = maxSteer / (1 + speed * 0.028);
    final steer = input.steer * steerMax; // + = left
    if (steer.abs() > 0.001) {
      final radius = wheelbase() / tan(steer.abs());
      final innerA = atan(wheelbase() / (radius - trackWidth / 2));
      final outerA = atan(wheelbase() / (radius + trackWidth / 2));
      for (var i = 0; i < 2; i++) {
        final isLeft = relPos[i].y > 0;
        final inner = (steer > 0) == isLeft;
        wheels[i].angle = steer.sign * (inner ? innerA : outerA);
      }
    } else {
      wheels[0].angle = 0;
      wheels[1].angle = 0;
    }

    final wind = env.wind.sample(pos, dt);
    final aeroForce = aero.step(vel, wind, yaw, env.airDensity);

    // Corner attachment heights from heave/pitch/roll.
    final bodyZ = List<double>.generate(4, (i) {
      final r = relPos[i];
      return suspension.attachmentHeight +
          heave +
          r.x * pitch -
          r.y * roll;
    });
    suspension.updateBodyVel(bodyZ, dt);
    final roadZ = List<double>.filled(4, 0.0);
    final loads = suspension.step(
      dt,
      bodyZ,
      roadZ,
      wheels[0].radius,
      mass * env.gravity / 4,
    );

    // Clutch torque couples engine and driveline.
    final clutchTorque = drivetrain.step(
      dt,
      engine.omega,
      input.clutch,
      engine.rpm,
      input.throttle,
      engine.crankInertia,
    );

    if (input.gearUp) drivetrain.requestShift(drivetrain.gear + 1);
    if (input.gearDown) drivetrain.requestShift(drivetrain.gear - 1);

    engine.ignitionOn = input.ignition;
    engine.starterEngaged = input.starter;
    engine.step(dt, input.throttle, clutchTorque);

    // Driven wheels share differential torque.
    final (tL, tR) =
        drivetrain.splitTorque(wheels[2].omega, wheels[3].omega);

    var force = aeroForce;
    var moment = aero.lastYawMoment;
    var pitchMoment = 0.0;
    var rollMoment = 0.0;
    var verticalSum = 0.0;

    for (var i = 0; i < 4; i++) {
      final w = wheels[i];
      w.fz = loads[i];
      final relWorld = relPos[i].rotated(yaw);
      final vContact = w.contactVelocity(vel, yawRate, relWorld);
      final contactWorld = pos + relWorld;
      final mu = env.surfaceMu(contactWorld);

      var drive = 0.0;
      if (w.driven) {
        drive = i == 2 ? tL : tR;
        // Traction control: bleed drive torque when the tire spins up.
        if (input.tcsEnabled && w.slipRatio > 0.15) {
          drive *= (0.15 / w.slipRatio).clamp(0.0, 1.0);
        }
      }
      var brake = input.brake * (i < 2 ? 0.62 : 0.38);
      if (input.handbrake && i >= 2) brake = 1.0;

      final (fx, fy) = w.step(
        dt,
        vContact,
        yaw + w.angle,
        drive,
        brake,
        mu,
        input.absEnabled,
      );

      // Tire force in the wheel frame -> world frame.
      final fWheel = Vec2(fx, fy).rotated(yaw + w.angle);
      force += fWheel;
      moment += relWorld.cross(fWheel);

      // Moments on the sprung body (virtual work signs).
      pitchMoment += relPos[i].x * suspension.forces[i] + cgHeight * fx;
      rollMoment += -relPos[i].y * suspension.forces[i] - cgHeight * fy;
      verticalSum += suspension.forces[i];
    }

    drivetrain.syncOutput(wheels[2].omega, wheels[3].omega);

    // Chassis planar dynamics.
    final m = currentMass;
    lastForce = force;
    lastMoment = moment;
    lastAccel = force / m;
    vel += lastAccel * dt;

    // Static friction: below creep speed with no driver demand, the tire
    // contact patches stick unless something pushes hard enough to break
    // them loose.
    final demand = input.throttle > 0.02 ||
        input.brake > 0.02 ||
        input.handbrake ||
        drivetrain.gear != 0;
    if (!demand &&
        speed < 0.4 &&
        yawRate.abs() < 0.2 &&
        force.length < m * env.gravity * 0.4) {
      vel *= 1 - (dt * 8).clamp(0.0, 1.0);
      yawRate *= 1 - (dt * 8).clamp(0.0, 1.0);
    }

    pos += vel * dt;
    yawRate += moment / yawInertia * dt;
    yawRate *= 1 - (dt * 0.02).clamp(0.0, 0.2); // small yaw damping
    yaw += yawRate * dt;

    // Sprung-body secondary dynamics.
    final gravity = m * env.gravity;
    final heaveAcc =
        (verticalSum - gravity + aero.lastDownforce) / (m * 0.85);
    heaveVel += heaveAcc * dt;
    heave += heaveVel * dt;
    heaveVel *= 1 - (dt * 1.2).clamp(0.0, 0.5);

    final iPitch = m * 1.35 * 1.35;
    final iRoll = m * 0.72 * 0.72;
    pitchVel += (pitchMoment - pitch * 4000) / iPitch * dt;
    pitch += pitchVel * dt;
    pitchVel *= 1 - (dt * 1.5).clamp(0.0, 0.5);
    rollVel += (rollMoment - roll * 3000) / iRoll * dt;
    roll += rollVel * dt;
    rollVel *= 1 - (dt * 1.5).clamp(0.0, 0.5);
  }

  Telemetry snapshot() => Telemetry.capture(this);
}
