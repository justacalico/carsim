import 'track.dart';
import 'vec2.dart';
import 'wind.dart';

/// World conditions: wind field, air density, temperature, gravity and the
/// road surface. All user-tunable at runtime.
class Environment {
  Environment({Track? track, WindField? wind, this.airDensity = 1.225})
      : track = track ?? Track(),
        wind = wind ?? WindField();

  final Track track;
  final WindField wind;
  double airDensity;

  /// Extra grip multiplier applied on top of the track's own surface map.
  double gripScale = 1.0;

  double gravity = 9.81;

  double surfaceMu(Vec2 p) => (track.surfaceMu(p) * gripScale).clamp(0.15, 1.4);
}
