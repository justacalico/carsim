import 'dart:math';

/// Simplified Pacejka tire with combined slip, load sensitivity, a first
/// order relaxation on lateral force, and a temperature model.
class Tire {
  Tire({
    this.bLong = 10.0,
    this.cLong = 1.9,
    this.eLong = 0.97,
    this.bLat = 8.5,
    this.cLat = 1.35,
    this.eLat = 0.97,
    this.relaxationLength = 0.55,
    this.peakMu = 1.05,
  });

  final double bLong, cLong, eLong;
  final double bLat, cLat, eLat;
  final double relaxationLength;
  final double peakMu;

  double temperature = 20; // C
  double _fyLag = 0;

  static double _pacejka(double slip, double b, double c, double e, double d) {
    final bx = b * slip;
    return d * sin(c * atan(bx - e * (bx - atan(bx))));
  }

  /// Effective friction coefficient: surface mu scaled by load sensitivity
  /// and temperature (cold tires and overheated tires both lose grip).
  double effectiveMu(double surfaceMu, double fz) {
    final loadSens = (1.12 - 0.000038 * fz).clamp(0.75, 1.12);
    final tempFactor = temperature < 55
        ? 0.75 + 0.25 * (temperature / 55).clamp(0.0, 1.0)
        : (temperature > 120 ? (1 - (temperature - 120) / 300) : 1.0);
    return surfaceMu * peakMu * loadSens * tempFactor.clamp(0.5, 1.0);
  }

  /// Longitudinal and lateral tire force for the given slip state.
  /// [kappa] slip ratio, [alpha] slip angle (rad), [fz] vertical load (N),
  /// [vx] contact-patch forward speed (m/s).
  (double fx, double fy) forces(
    double kappa,
    double alpha,
    double fz,
    double surfaceMu,
    double vx,
    double dt,
  ) {
    if (fz <= 0) {
      _fyLag = 0;
      return (0, 0);
    }
    final d = effectiveMu(surfaceMu, fz) * fz;

    final fx0 = _pacejka(kappa, bLong, cLong, eLong, d);
    final fy0 = -_pacejka(alpha, bLat, cLat, eLat, d);

    // Combined slip: shrink each component inside the friction ellipse.
    final sK = kappa.abs(), sA = tan(alpha).abs();
    final sigma = sqrt(sK * sK + sA * sA);
    double fx = fx0, fy = fy0;
    if (sigma > 1e-6) {
      fx = fx0 * sK / sigma * _ellipseGain(sigma);
      fy = fy0 * sA / sigma * _ellipseGain(sigma);
    }

    // Relaxation: lateral force builds over the relaxation length.
    final speed = vx.abs().clamp(0.5, double.infinity);
    _fyLag += (fy - _fyLag) * (speed * dt / relaxationLength).clamp(0.0, 1.0);

    // Hard cap on the friction ellipse: the contact patch can never deliver
    // more than mu*Fz, no matter what the model terms add up to.
    final cap = effectiveMu(surfaceMu, fz) * fz * 1.05;
    final mag = sqrt(fx * fx + _fyLag * _fyLag);
    if (mag > cap && mag > 0) {
      final s = cap / mag;
      return (fx * s, _fyLag * s);
    }
    return (fx, _fyLag);
  }

  double _ellipseGain(double sigma) {
    // Slightly inside the ideal ellipse so combined slip loses a bit of grip.
    return (1.12 - 0.12 * sigma).clamp(0.85, 1.05);
  }

  /// Heating from slip power, cooling toward ambient.
  void stepTemperature(double dt, double slipPowerWatts) {
    temperature += (slipPowerWatts * 0.004 - (temperature - 20) * 0.01) * dt;
    temperature = temperature.clamp(-20, 250);
  }
}
