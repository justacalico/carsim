import 'dart:math';

import 'tire.dart';
import 'vec2.dart';

/// One wheel: rotating inertia, tire contact, hydraulic brake with fade and
/// a simple ABS modulator.
class Wheel {
  Wheel({
    required this.steerable,
    required this.driven,
    this.radius = 0.32,
    this.inertia = 1.1,
    this.maxBrakeTorque = 2600,
    Tire? tire,
  }) : tire = tire ?? Tire();

  final bool steerable;
  final bool driven;
  final double radius;
  final double inertia;
  final double maxBrakeTorque;
  final Tire tire;

  double omega = 0; // rad/s
  double angle = 0; // steering angle, rad
  double fz = 0; // vertical load from suspension, N
  double brakeTemp = 80; // C
  bool absActive = false;
  double slipRatio = 0;
  double slipAngle = 0;
  double fx = 0, fy = 0; // forces in wheel frame

  double _absPhase = 0;

  /// World-space velocity of the wheel contact point.
  Vec2 contactVelocity(Vec2 chassisVel, double yawRate, Vec2 relPos) {
    return chassisVel + Vec2(-relPos.y, relPos.x) * yawRate;
  }

  /// Integrates the wheel for one step and returns tire force in the wheel
  /// frame (x forward, y left positive). [worldHeading] is the wheel's
  /// heading in world space (car yaw + steering angle).
  (double, double) step(
    double dt,
    Vec2 velContact,
    double worldHeading,
    double driveTorque,
    double brakeInput,
    double surfaceMu,
    bool absEnabled,
  ) {
    // Velocity in the wheel's rolling frame.
    final vRot = velContact.rotated(-worldHeading);
    final vx = vRot.x, vy = vRot.y;

    // At crawling speed the slip denominators explode: attenuate both slip
    // channels so a parked car is quiet instead of self-exciting.
    final vRef = max(vx.abs(), 0.5);
    final lowSpeed = (vx.abs() / 0.8).clamp(0.0, 1.0);
    slipRatio = ((radius * omega - vx) / vRef) * lowSpeed;
    slipAngle = atan2(vy, vRef) * lowSpeed;

    // Brake torque with thermal fade and ABS cycling.
    var brakeTorque = 0.0;
    if (brakeInput > 0) {
      final fade = (1 - (brakeTemp - 350) / 600).clamp(0.3, 1.0);
      var capacity = maxBrakeTorque * brakeInput * fade;
      absActive = false;
      if (absEnabled && slipRatio < -0.18 && vx.abs() > 3) {
        _absPhase += dt * 18;
        capacity *= 0.55 + 0.45 * (0.5 + 0.5 * sin(_absPhase * pi * 2));
        absActive = true;
      }
      brakeTorque = capacity * omega.sign;
    } else {
      absActive = false;
    }

    final (tFx, tFy) = tire.forces(
      slipRatio.clamp(-1.5, 1.5),
      slipAngle,
      fz,
      surfaceMu,
      vx,
      dt,
    );
    fx = tFx;
    fy = tFy;

    // Rolling resistance ~1% of load.
    final rrTorque = 0.012 * fz * radius * omega.sign;

    final net = driveTorque - brakeTorque - fx * radius - rrTorque;
    omega += net / inertia * dt;

    // Static friction clamp: a parked car shouldn't creep from slip noise.
    if (vx.abs() < 0.3 &&
        omega.abs() * radius < 0.3 &&
        driveTorque.abs() < 1 &&
        brakeTorque.abs() < 1) {
      omega *= 1 - (dt * 20).clamp(0.0, 1.0);
      if (omega.abs() < 0.02) omega = 0;
    }

    tire.stepTemperature(dt, (fx * (radius * omega - vx)).abs());
    brakeTemp += (brakeTorque.abs() * omega.abs() * 0.0016 -
            (brakeTemp - 40) * 0.02) *
        dt;
    brakeTemp = brakeTemp.clamp(20, 900);

    return (fx, fy);
  }

  double get speedKmh => radius * omega * 3.6;
}
