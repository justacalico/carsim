import 'package:carsim/sim/car.dart';
import 'package:carsim/sim/driver_input.dart';
import 'package:carsim/sim/environment.dart';

void main() {
  final car = Car(env: Environment());
  final input = DriverInput()
    ..ignition = true
    ..starter = true;
  for (var i = 0; i < 500; i++) {
    car.step(0.001, input);
    if (i % 100 == 0) {
      print('t=${i}ms omega=${car.engine.omega.toStringAsFixed(2)} rpm=${car.engine.rpm.toStringAsFixed(0)} running=${car.engine.running} theta=${car.engine.theta.toStringAsFixed(2)} clutch=${car.drivetrain.lastClutchTorque}');
    }
  }
}
