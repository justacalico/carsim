/// Raw driver controls. All 0-1 except steer (-1..1) and the edge-triggered
/// gear flags which are consumed by the car each step.
class DriverInput {
  double throttle = 0;
  double brake = 0;
  double clutch = 0; // 0 = engaged, 1 = fully pressed
  double steer = 0; // -1 left ... 1 right
  bool gearUp = false;
  bool gearDown = false;
  bool ignition = false;
  bool starter = false;
  bool handbrake = false;
  bool absEnabled = true;
  bool tcsEnabled = true;

  void consumeGears() {
    gearUp = false;
    gearDown = false;
  }
}
