import 'car.dart';
import 'vec2.dart';

/// Immutable snapshot of everything the UI might want to draw. Built fresh
/// each frame; cheap because it's just numbers.
class Telemetry {
  Telemetry._();

  late Vec2 pos;
  late Vec2 vel;
  late double yaw;
  late double yawRate;
  late double speedKmh;

  late double rpm;
  late double engineTorque;
  late double powerKw;
  late double manifoldBar;
  late double boostBar;
  late double engineTemp;
  late double fuelUsedKg;
  late bool engineRunning;

  late int gear;
  late bool shifting;
  late double clutchTorque;

  late List<double> pistonPos;
  late List<double> cylinderPressureBar;
  late List<double> cyclePhase;

  late List<double> wheelSpeedKmh;
  late List<double> slipRatio;
  late List<double> slipAngleDeg;
  late List<double> wheelLoad;
  late List<double> brakeTemp;
  late List<double> tireTemp;
  late List<bool> absActive;
  late List<double> suspensionTravel;

  late Vec2 windVec;
  late double apparentWindKmh;
  late double downforceN;
  late double latG;
  late double longG;

  late double heave;
  late double pitchDeg;
  late double rollDeg;
  late double lapProgress;
  late double lateralOffset;

  static Telemetry capture(Car c) {
    final t = Telemetry._();
    t.pos = c.pos;
    t.vel = c.vel;
    t.yaw = c.yaw;
    t.yawRate = c.yawRate;
    t.speedKmh = c.speedKmh;

    t.rpm = c.engine.rpm;
    t.engineTorque = c.engine.lastTorque;
    t.powerKw = c.engine.lastPowerKw;
    t.manifoldBar = c.engine.manifoldPressure / 1e5;
    t.boostBar = c.engine.boostPressure / 1e5;
    t.engineTemp = c.engine.temperature;
    t.fuelUsedKg = c.engine.fuelUsedGrams / 1000;
    t.engineRunning = c.engine.running;

    t.gear = c.drivetrain.gear;
    t.shifting = c.drivetrain.shiftTimer > 0;
    t.clutchTorque = c.drivetrain.lastClutchTorque;

    t.pistonPos = List.generate(
        c.engine.cylinders, (i) => c.engine.pistonPosition(i));
    t.cylinderPressureBar = List.generate(
        c.engine.cylinders,
        (i) => c.engine.cyl[i].pressure / 1e5);
    t.cyclePhase = List.generate(
        c.engine.cylinders, (i) => c.engine.cyclePhase(i));

    t.wheelSpeedKmh =
        c.wheels.map((w) => w.speedKmh).toList(growable: false);
    t.slipRatio = c.wheels.map((w) => w.slipRatio).toList(growable: false);
    t.slipAngleDeg = c.wheels
        .map((w) => w.slipAngle * 180 / 3.14159265)
        .toList(growable: false);
    t.wheelLoad = c.wheels.map((w) => w.fz).toList(growable: false);
    t.brakeTemp = c.wheels.map((w) => w.brakeTemp).toList(growable: false);
    t.tireTemp =
        c.wheels.map((w) => w.tire.temperature).toList(growable: false);
    t.absActive = c.wheels.map((w) => w.absActive).toList(growable: false);
    t.suspensionTravel = List.of(c.suspension.compression);

    t.windVec = c.env.wind.lastWind;
    t.apparentWindKmh = c.aero.apparentWindSpeed * 3.6;
    t.downforceN = c.aero.lastDownforce;

    // Body-frame g forces.
    final aBody = c.lastAccel.rotated(-c.yaw);
    t.latG = aBody.y / 9.81;
    t.longG = aBody.x / 9.81;

    t.heave = c.heave;
    t.pitchDeg = c.pitch * 180 / 3.14159265;
    t.rollDeg = c.roll * 180 / 3.14159265;
    t.lapProgress = c.env.track.progress(c.pos);
    t.lateralOffset = c.env.track.lateralOffset(c.pos);
    return t;
  }
}
