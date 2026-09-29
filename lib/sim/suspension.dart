import 'dart:math';

/// Four-corner suspension over a chassis with heave, pitch and roll degrees
/// of freedom. Heights are absolute above the road: each corner has a hub
/// (unsprung mass) whose tire compresses against the road, and a spring +
/// damper between the hub and the chassis attachment point.
class Suspension {
  Suspension({
    this.springRate = 38000,
    this.damperBump = 2400,
    this.damperRebound = 3400,
    this.antiRollFront = 12000,
    this.antiRollRear = 9000,
    this.tireVerticalRate = 210000,
    this.unsprungMass = 42,
    this.attachmentHeight = 0.45,
  });

  final double springRate;
  final double damperBump;
  final double damperRebound;
  final double antiRollFront;
  final double antiRollRear;
  final double tireVerticalRate;
  final double unsprungMass;

  /// Chassis attachment height above road at rest, m.
  final double attachmentHeight;

  /// Hub heights above the road, [fl, fr, rl, rr]. Initialized by [reset].
  final List<double> unsprungZ = [0.32, 0.32, 0.32, 0.32];
  final List<double> unsprungV = [0, 0, 0, 0];

  /// Spring compression and force per corner.
  final List<double> compression = [0, 0, 0, 0];
  final List<double> forces = [0, 0, 0, 0];

  final List<double> _prevBodyZ = [0, 0, 0, 0];
  final List<double> _bodyVel = [0, 0, 0, 0];

  void reset(double hubHeight) {
    for (var i = 0; i < 4; i++) {
      unsprungZ[i] = hubHeight;
      unsprungV[i] = 0;
      _prevBodyZ[i] = attachmentHeight;
    }
  }

  /// Damper relative velocity needs the attachment point speed; call once per
  /// step before [step].
  void updateBodyVel(List<double> bodyZ, double dt) {
    for (var i = 0; i < 4; i++) {
      _bodyVel[i] = (bodyZ[i] - _prevBodyZ[i]) / max(dt, 1e-6);
    }
  }

  /// [bodyZ] = absolute attachment heights per corner, [roadZ] = road height
  /// under each wheel, [hubRest] = unloaded hub height, [staticLoad] =
  /// quarter of the car weight. Returns tire load (N) per corner.
  List<double> step(
    double dt,
    List<double> bodyZ,
    List<double> roadZ,
    double hubRest,
    double staticLoad,
  ) {
    final springFree =
        (attachmentHeight - hubRest) + staticLoad / springRate;
    final tireRest = hubRest + staticLoad / tireVerticalRate;
    final loads = List<double>.filled(4, 0);

    // First pass: compressions, so the anti-roll couple reads both corners
    // of an axle at the same instant.
    for (var i = 0; i < 4; i++) {
      compression[i] =
          (springFree - (bodyZ[i] - unsprungZ[i])).clamp(-0.1, 0.35);
    }

    for (var i = 0; i < 4; i++) {
      final comp = compression[i];
      final compRate = unsprungV[i] - _bodyVel[i];
      final damper = compRate > 0 ? damperBump : damperRebound;
      var f = springRate * comp + damper * compRate;

      // Anti-roll couples left/right on the same axle.
      final arb = i < 2 ? antiRollFront : antiRollRear;
      final other = i % 2 == 0 ? i + 1 : i - 1;
      f += arb * (comp - compression[other]) * 0.5;
      if (f < 0) f = 0;
      forces[i] = f;

      // Tire vertical spring gives the wheel load.
      final deflect = tireRest - (unsprungZ[i] - roadZ[i]);
      final load = deflect > 0 ? tireVerticalRate * deflect : 0.0;
      loads[i] = load;

      // Unsprung mass: tire pushes up, spring and gravity push down.
      final acc = (load - f - unsprungMass * 9.81) / unsprungMass;
      unsprungV[i] += acc * dt;
      unsprungZ[i] += unsprungV[i] * dt;
    }
    _prevBodyZ.setAll(0, bodyZ);
    return loads;
  }
}
