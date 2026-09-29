import 'dart:math';

import 'vec2.dart';

/// Wind field: a steady base vector plus Ornstein-Uhlenbeck turbulence and
/// discrete traveling gusts, so the air over the car is never still.
class WindField {
  WindField({
    this.baseSpeed = 4.0,
    this.baseDirectionDeg = 40,
    this.turbulence = 0.6,
    this.gustStrength = 7.0,
    this.gustRate = 0.08, // expected gusts per second
    int seed = 7,
  }) : _rng = Random(seed);

  double baseSpeed;
  double baseDirectionDeg;
  double turbulence; // 0-1 intensity
  double gustStrength;
  double gustRate;

  final Random _rng;

  Vec2 _turb = Vec2.zero;
  final List<_Gust> _gusts = [];

  Vec2 lastWind = Vec2.zero;

  Vec2 get baseWind {
    final a = baseDirectionDeg * pi / 180;
    return Vec2(cos(a) * baseSpeed, sin(a) * baseSpeed);
  }

  /// Samples the wind at world position [p] after advancing the field by dt.
  Vec2 sample(Vec2 p, double dt) {
    // OU turbulence, correlation time ~1.4s.
    const tau = 1.4;
    final sigma = turbulence * 3.2;
    final decay = exp(-dt / tau);
    final scale = sigma * sqrt(1 - decay * decay);
    _turb = Vec2(
      _turb.x * decay + scale * _gauss(),
      _turb.y * decay + scale * _gauss(),
    );

    // Spawn gusts as a Poisson process.
    if (_rng.nextDouble() < gustRate * turbulence * dt * 60 / 60) {
      final dir = _rng.nextDouble() * 2 * pi;
      _gusts.add(_Gust(
        pos: p +
            Vec2(cos(dir), sin(dir)) * (30 + _rng.nextDouble() * 120),
        vel: Vec2(cos(dir + pi / 2), sin(dir + pi / 2)) *
            gustStrength *
            (0.5 + _rng.nextDouble()),
        radius: 18 + _rng.nextDouble() * 30,
        life: 2.5 + _rng.nextDouble() * 3,
      ));
    }

    var gustWind = Vec2.zero;
    _gusts.removeWhere((g) {
      g.life -= dt;
      if (g.life <= 0) return true;
      // Gust core drifts with the base wind.
      g.pos = g.pos + baseWind * dt * 0.6;
      final d = (p - g.pos).length;
      if (d < g.radius) {
        final shape = cos(pi / 2 * d / g.radius);
        gustWind += g.vel * shape * min(1.0, g.life);
      }
      return false;
    });

    lastWind = baseWind + _turb + gustWind;
    return lastWind;
  }

  double _gauss() {
    final u1 = max(_rng.nextDouble(), 1e-9);
    final u2 = _rng.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }
}

class _Gust {
  _Gust({required this.pos, required this.vel, required this.radius, required this.life});
  Vec2 pos;
  Vec2 vel;
  double radius;
  double life;
}
