import 'dart:math';

import 'vec2.dart';

/// Aerodynamic forces from the apparent wind (car velocity minus ambient
/// wind): drag along the flow, downforce, and a side force + yaw moment from
/// crosswind angle so gusts actually shove the car sideways.
class Aero {
  Aero({
    this.cdA = 0.68, // drag area, m^2
    this.clA = 1.9, // downforce area, m^2
    this.sideArea = 3.4, // m^2
    this.sideForceGain = 2.2, // Cy per radian of wind beta
    this.cpOffset = -0.25, // aero center behind CG, m (weathervane stable)
  });

  final double cdA;
  final double clA;
  final double sideArea;
  final double sideForceGain;
  final double cpOffset;

  Vec2 lastDrag = Vec2.zero;
  double lastDownforce = 0;
  double lastSideForce = 0;
  double lastYawMoment = 0;
  double apparentWindSpeed = 0;
  double windBeta = 0; // wind angle relative to car heading

  /// Returns world-frame aero force; downforce/yaw stored on the instance.
  Vec2 step(Vec2 carVel, Vec2 windVel, double heading, double airDensity) {
    final vApp = carVel - windVel;
    final speed = vApp.length;
    apparentWindSpeed = speed;
    if (speed < 0.1) {
      lastDrag = Vec2.zero;
      lastDownforce = lastSideForce = lastYawMoment = 0;
      windBeta = 0;
      return Vec2.zero;
    }

    final q = 0.5 * airDensity * speed * speed;

    // Drag opposes apparent wind.
    lastDrag = vApp.normalized() * (-q * cdA);

    // Downforce (always vertical in this model).
    lastDownforce = q * clA;

    // Wind angle relative to car forward axis.
    final flowAngle = (-vApp).angle - heading;
    windBeta = _wrap(flowAngle);

    // Crosswind side force in world frame, perpendicular to the car.
    final sf = q * sideArea * sideForceGain * sin(windBeta) * cos(windBeta);
    final sideDir = Vec2(-sin(heading), cos(heading)); // car-left
    lastSideForce = sf;
    lastYawMoment = sf * cpOffset + q * cdA * 0.02 * sin(2 * windBeta);

    return lastDrag + sideDir * sf;
  }

  double _wrap(double a) {
    while (a > pi) {
      a -= 2 * pi;
    }
    while (a < -pi) {
      a += 2 * pi;
    }
    return a;
  }
}
