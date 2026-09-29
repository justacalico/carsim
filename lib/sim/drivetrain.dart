import 'dart:math';

/// Clutch, stepped gearbox and differential between the engine and the driven
/// wheels. The clutch is a real slip element: it transmits torque up to its
/// capacity and lets the two shafts rotate independently past that.
class Drivetrain {
  Drivetrain({
    this.gearRatios = const [3.42, 2.14, 1.45, 1.07, 0.83, 0.68],
    this.reverseRatio = -3.3,
    this.finalDrive = 3.85,
    this.clutchCapacity = 650,
    this.shiftTime = 0.16,
    this.minShiftInterval = 0.5,
    this.auto = true,
    this.upshiftRpm = 6300,
    this.downshiftRpm = 2100,
    this.lsdFactor = 0.4,
    this.shaftInertia = 0.02,
    this.wheelInertia = 1.1,
  });

  final List<double> gearRatios;
  final double reverseRatio;
  final double finalDrive;
  final double clutchCapacity;
  final double shiftTime;
  final double minShiftInterval;
  bool auto;
  final double upshiftRpm;
  final double downshiftRpm;

  /// 0 = open diff, 1 = locked diff.
  final double lsdFactor;

  /// Propshaft + gearbox inertia on the wheel side of the clutch.
  final double shaftInertia;

  /// Per-wheel rotating inertia, used by the clutch constraint solve.
  final double wheelInertia;

  /// 0 = neutral, 1..n = forward gears, -1 = reverse.
  int gear = 0;

  /// Angular velocity of the gearbox output shaft (after final drive this is
  /// the average driven wheel speed).
  double outputOmega = 0;

  double shiftTimer = 0;
  int pendingGear = 0;
  double shiftCooldown = 0;
  double clutchSlip = 0;
  double _autoClutch = 1.0;
  double lockedTime = 0;

  double lastClutchTorque = 0;

  double get currentRatio =>
      gear > 0 ? gearRatios[gear - 1] : (gear < 0 ? reverseRatio : 0);

  bool requestShift(int target) {
    if (target == gear || shiftTimer > 0 || shiftCooldown > 0) return false;
    if (target > gearRatios.length || target < -1) return false;
    pendingGear = target;
    shiftTimer = shiftTime;
    return true;
  }

  /// [clutchPedal] 0 = fully engaged, 1 = fully pressed.
  /// Returns the torque the clutch applies to the engine (positive loads it).
  double step(
    double dt,
    double engineOmega,
    double clutchPedal,
    double engineRpm,
    double throttle,
    double engineInertia,
  ) {
    if (shiftCooldown > 0) shiftCooldown -= dt;
    if (shiftTimer > 0) {
      shiftTimer -= dt;
      if (shiftTimer <= 0) {
        gear = pendingGear;
        shiftTimer = 0;
        shiftCooldown = minShiftInterval;
        _autoClutch = 0.45; // ease the clutch back in after engagement
      }
    }

    // In auto mode the clutch feed-in ramp smooths nothing; the torque
    // converter below handles launch. Manual mode keeps the ramp.
    if (!auto) {
      _autoClutch = min(1.0, _autoClutch + dt / 1.1);
    } else {
      _autoClutch = 1.0;
    }

    if (auto && gear >= 0 && clutchPedal < 0.05) {
      if (gear == 0 && throttle > 0.05 && engineRpm > 700) {
        // Pull away: engage first when the driver asks.
        requestShift(1);
      } else if (outputOmega > 1.5 &&
          engineRpm > upshiftRpm &&
          gear < gearRatios.length &&
          gear > 0 &&
          lockedTime > 0.25) {
        requestShift(gear + 1);
      } else if (engineRpm < downshiftRpm && gear > 1 && throttle < 0.6) {
        requestShift(gear - 1);
      } else if (engineRpm < 3200 && gear > 1 && throttle > 0.85) {
        // Kickdown.
        requestShift(gear - 1);
      }
    }

    final ratio = currentRatio;
    if (ratio == 0 || shiftTimer > 0 || clutchPedal > 0.98) {
      lastClutchTorque = 0;
      return 0;
    }

    // Slip is engine speed minus the wheel side referred through the gears.
    final wheelSideOmega = outputOmega * ratio;
    final slip = engineOmega - wheelSideOmega;
    clutchSlip = slip;

    final capacity =
        clutchCapacity * (1 - clutchPedal).clamp(0.0, 1.0) * _autoClutch;
    final gFd = (ratio * finalDrive).abs();
    final iWheelSide = shaftInertia + 2 * wheelInertia / (gFd * gFd);
    final iRed = 1 / (1 / engineInertia + 1 / iWheelSide);
    final tKill = slip * iRed / dt;

    double clutchTorque;
    if (auto) {
      // Torque converter: pump torque grows with the square of engine speed
      // and falls as the turbine catches up (speed ratio -> 1). Slightly
      // negative past r=1 gives engine braking on overrun.
      final r = engineOmega > 1 ? wheelSideOmega / engineOmega : 0.0;
      final fluid = 0.0058 *
          engineOmega *
          engineOmega *
          (1.0 - r).clamp(-0.12, 1.15);
      // Lockup clutch blends in above ~85% speed match from 2nd gear up.
      final lockup = gear > 1 ? ((r - 0.85) / 0.1).clamp(0.0, 1.0) : 0.0;
      var lock = 0.0;
      if (lockup > 0) {
        var t = capacity * _tanh(slip / 6);
        if (slip > 0 && t > tKill) t = tKill;
        if (slip < 0 && t < tKill) t = tKill;
        lock = t;
      }
      clutchTorque = fluid * (1 - lockup) + lock * lockup;
    } else {
      // Dry clutch: implicit solve keeps the constraint stable.
      var t = capacity * _tanh(slip / 6);
      if (slip > 0 && t > tKill) t = tKill;
      if (slip < 0 && t < tKill) t = tKill;
      clutchTorque = t;
    }

    if (slip.abs() < 60) {
      lockedTime += dt;
    } else {
      lockedTime = 0;
    }

    // Torque applied to wheel side, through gearing.
    wheelTorqueDemand = clutchTorque * ratio * finalDrive;
    lastClutchTorque = clutchTorque;
    return clutchTorque;
  }

  double wheelTorqueDemand = 0;

  static double _tanh(double x) {
    if (x > 20) return 1;
    if (x < -20) return -1;
    final e = exp(2 * x);
    return (e - 1) / (e + 1);
  }

  /// Splits output-shaft torque between two driven wheels. Returns
  /// (left, right) drive torque in Nm at the wheels.
  (double, double) splitTorque(double leftOmega, double rightOmega) {
    if (gear == 0 || wheelTorqueDemand == 0) return (0, 0);
    final half = wheelTorqueDemand / 2;
    // LSD pushes torque toward the slower wheel.
    final bias = ((rightOmega - leftOmega) * lsdFactor).clamp(-0.5, 0.5);
    return (half * (1 + bias), half * (1 - bias));
  }

  /// Called by the car after wheels integrate; keeps output shaft in sync
  /// with the average driven wheel speed (referred through final drive).
  void syncOutput(double leftWheelOmega, double rightWheelOmega) {
    outputOmega = (leftWheelOmega + rightWheelOmega) / 2 * finalDrive;
  }
}
