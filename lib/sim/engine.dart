import 'dart:math';

/// Per-cylinder four-stroke engine. Each piston is a slider-crank driven by a
/// shared crank angle; cylinder pressure follows the intake / compression /
/// combustion / expansion / exhaust cycle and the resulting gas force on each
/// piston crown is turned into crank torque through the crank geometry.
class Engine {
  Engine({
    this.cylinders = 4,
    this.bore = 0.086,
    this.stroke = 0.086,
    this.rodLength = 0.143,
    this.compressionRatio = 10.5,
    this.crankInertia = 0.16,
    this.idleRpm = 900,
    this.redlineRpm = 6800,
    this.turbo = true,
    this.maxBoostBar = 0.9,
    this.startTorque = 200,
    this.idleLeak = 0.33,
    this.thermalShare = 0.3,
    List<int>? firingOrder,
  }) : firingOrder = firingOrder ?? _defaultOrder(cylinders) {
    crankRadius = stroke / 2;
    pistonArea = pi / 4 * bore * bore;
    displacedPerCylinder = pistonArea * stroke;
    displacement = displacedPerCylinder * cylinders;
    clearanceVolume = displacedPerCylinder / (compressionRatio - 1);
    cyl = List.generate(
      cylinders,
      (i) => CylinderState(
        phaseOffsetDeg: 720.0 * this.firingOrder[i] / cylinders,
      ),
    );
  }

  static List<int> _defaultOrder(int n) => List.generate(n, (i) => i);

  final int cylinders;
  final double bore;
  final double stroke;
  final double rodLength;
  final double compressionRatio;
  final double crankInertia;
  final double idleRpm;
  final double redlineRpm;
  final bool turbo;
  final double maxBoostBar;
  final double startTorque;

  /// Fraction of ambient pressure the closed throttle leaks.
  final double idleLeak;

  /// Fraction of fuel energy that becomes cylinder pressure work.
  final double thermalShare;
  final List<int> firingOrder;

  late final double crankRadius;
  late final double pistonArea;
  late final double displacedPerCylinder;
  late final double displacement;
  late final double clearanceVolume;
  late final List<CylinderState> cyl;

  /// Crank angle in radians.
  double theta = 0;

  /// Crankshaft angular velocity in rad/s.
  double omega = 0;

  double manifoldPressure = 42000; // Pa
  double boostPressure = 0; // Pa above ambient
  double temperature = 20; // coolant temp, C
  double fuelUsedGrams = 0;
  bool ignitionOn = false;
  bool starterEngaged = false;
  bool running = false;

  double lastTorque = 0;
  double lastPowerKw = 0;
  double _idleAir = 0;
  bool _fuelCut = false;

  static const ambientPressure = 101325.0;
  static const gasConstant = 287.0;
  static const intakeTemp = 330.0;
  static const stoichAfr = 14.7;
  static const fuelLhv = 44e6; // J/kg gasoline
  static const kPoly = 1.31;
  static const burnDurationDeg = 62.0;
  static const exhaustPressure = 108000.0;

  double get rpm => omega * 60 / (2 * pi);
  double get meanPistonSpeed => 2 * stroke * omega / (2 * pi);

  double volumetricEfficiency() {
    final r = rpm;
    final t = (r - 4200) / 3000;
    final curve = 0.92 - 0.18 * t * t;
    return curve.clamp(0.5, 0.95);
  }

  /// Combustion pressure rise per cycle (Pa) for the given charge density.
  /// Heat lands near TDC where the volume is the clearance volume, so the
  /// pressure spike is energy / Vc.
  double _combustionDeltaP(double chargeDensity) {
    const rhoAmbient = ambientPressure / (gasConstant * intakeTemp);
    final airMass = displacedPerCylinder * rhoAmbient * chargeDensity;
    final afr = chargeDensity > 1.15 ? 12.6 : stoichAfr;
    final fuelMass = airMass / afr;
    return fuelMass * fuelLhv * thermalShare / clearanceVolume;
  }

  /// Cylinder pressure at the given point in the 720 deg cycle.
  double cylinderPressure(int i, double phaseDeg, double chargeDensity) {
    final pMan = manifoldPressure;
    final vIntakeClose = _volumeDeg(180);
    final a = phaseDeg % 360.0;
    final v = _volumeDeg(a);

    if (phaseDeg < 180) {
      return pMan;
    } else if (phaseDeg < 540) {
      final motored = pMan * pow(vIntakeClose / v, kPoly);
      if (!running || !ignitionOn) return motored;
      final burnT = phaseDeg - 360;
      if (burnT < 0) return motored;
      final xb = 1 - exp(-5.0 * pow(burnT / burnDurationDeg, 3));
      final heat = _combustionDeltaP(chargeDensity) *
          xb *
          pow(clearanceVolume / v, kPoly);
      return motored + heat;
    } else {
      return exhaustPressure;
    }
  }

  double _volumeDeg(double crankDeg) {
    return clearanceVolume + displacedPerCylinder * _pistonTravelFrac(crankDeg);
  }

  /// 0 at TDC, 1 at BDC.
  double _pistonTravelFrac(double crankDeg) {
    final a = crankDeg * pi / 180;
    final r = crankRadius, l = rodLength;
    final s = sin(a);
    final x = r * cos(a) + sqrt(l * l - r * r * s * s);
    return (l + r - x) / (2 * r);
  }

  /// d(pistonTravel)/d(crank angle in rad). Positive moving away from head.
  double _dxdTheta(double crankDeg) {
    final a = crankDeg * pi / 180;
    final r = crankRadius, l = rodLength;
    final s = sin(a), c = cos(a);
    final root = sqrt(l * l - r * r * s * s);
    return r * s + r * r * s * c / root;
  }

  /// Piston position for rendering: 0 = TDC, 1 = BDC.
  double pistonPosition(int i) {
    final aDeg = ((theta * 180 / pi + cyl[i].phaseOffsetDeg) % 360 + 360) % 360;
    return _pistonTravelFrac(aDeg);
  }

  /// Current cycle phase (0-720) of a cylinder, for rendering valve events.
  double cyclePhase(int i) {
    return ((theta * 180 / pi + cyl[i].phaseOffsetDeg) % 720 + 720) % 720;
  }

  /// Gas torque produced by one cylinder right now.
  double _cylinderTorque(int i, double chargeDensity) {
    final c = cyl[i];
    final p = cylinderPressure(i, c.phaseDeg, chargeDensity);
    c.pressure = p;
    final aDeg = c.phaseDeg % 360.0;
    return (p - ambientPressure) * pistonArea * _dxdTheta(aDeg);
  }

  /// Friction + pumping mean torque, always opposing rotation.
  double _frictionTorque() {
    final r = rpm.abs();
    final fmep = 40000 + 8.0 * r + 0.00035 * r * r; // Pa
    final friction = fmep * displacement / (4 * pi);
    final pumping =
        (exhaustPressure - manifoldPressure).clamp(0, 80000) *
            displacement /
            (4 * pi) *
            0.7;
    final cold = temperature < 60 ? (60 - temperature) / 60 * 0.6 : 0.0;
    return (friction + pumping) * (1 + cold);
  }

  /// Advance the engine by dt seconds. [throttle] 0-1, [loadTorque] is the
  /// torque the clutch pulls from the crank (positive = loading the engine).
  void step(double dt, double throttle, double loadTorque) {
    // Turbo boost follows requested boost with a spool lag.
    final boostTarget = turbo
        ? maxBoostBar * 1e5 * throttle * (rpm / redlineRpm).clamp(0.0, 1.0)
        : 0.0;
    final tau = boostTarget > boostPressure ? 0.55 : 0.25;
    boostPressure += (boostTarget - boostPressure) * (dt / tau).clamp(0.0, 1.0);

    // Idle air control: an integrator trims the throttle opening to hold
    // idleRpm. It can go negative, but only once rpm is past idle —
    // otherwise it would trim the engine dead while it's still climbing.
    if (running && throttle < 0.1) {
      _idleAir += (idleRpm - rpm) * 0.001 * dt;
      final floor = rpm > idleRpm ? -idleLeak : 0.0;
      _idleAir = _idleAir.clamp(floor, 0.4);
    }
    var throttleEff = throttle;
    if (throttle < 0.1) {
      throttleEff = (throttle + _idleAir).clamp(-idleLeak, 1.0);
    }

    // Intake manifold fills toward the throttle/boost target.
    final pTarget = ambientPressure *
            (idleLeak + throttleEff * (1 - idleLeak)) +
        boostPressure * throttleEff.clamp(0.0, 1.0);
    manifoldPressure +=
        (pTarget - manifoldPressure) * (dt / 0.05).clamp(0.0, 1.0);

    final chargeDensity =
        volumetricEfficiency() * manifoldPressure / ambientPressure;

    if (rpm > redlineRpm + 100) _fuelCut = true;
    if (rpm < redlineRpm - 150) _fuelCut = false;
    // Combustion runs when the ignition is on, the limiter isn't cutting,
    // and the engine is either turning over on the starter or spinning.
    running = ignitionOn && !_fuelCut && (omega > 6 || starterEngaged);

    var gasTorque = 0.0;
    for (var i = 0; i < cylinders; i++) {
      final c = cyl[i];
      c.phaseDeg = ((theta * 180 / pi + c.phaseOffsetDeg) % 720 + 720) % 720;
      // Fuel accounting when a cylinder passes its intake.
      if (running && c.phaseDeg < 90 && !c.fueled) {
        const rhoAmbient = ambientPressure / (gasConstant * intakeTemp);
        final airMass = displacedPerCylinder * rhoAmbient * chargeDensity;
        final afr = chargeDensity > 1.15 ? 12.6 : stoichAfr;
        fuelUsedGrams += airMass / afr * 1000;
        c.fueled = true;
      }
      if (c.phaseDeg > 180) c.fueled = false;
      gasTorque += _cylinderTorque(i, chargeDensity);
    }

    var torque = gasTorque - _frictionTorque() * omega.sign;
    if (starterEngaged && rpm < 1100) {
      torque += startTorque * (1 - rpm / 1100);
    }
    torque -= loadTorque;

    omega += torque / crankInertia * dt;
    if (omega < 0) omega = 0;
    theta = (theta + omega * dt) % (4 * pi);

    lastTorque = gasTorque;
    lastPowerKw = gasTorque * omega / 1000;

    final warmTarget = 90.0;
    final heatRate = running ? (0.25 + gasTorque.abs() / 900) : -0.02;
    temperature +=
        (warmTarget - temperature).clamp(-1.0, 1.0) * heatRate * dt * 0.1;
  }
}

class CylinderState {
  CylinderState({required this.phaseOffsetDeg});

  final double phaseOffsetDeg;
  double phaseDeg = 0;
  double pressure = 101325;
  bool fueled = false;
}
