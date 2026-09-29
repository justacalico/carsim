import 'dart:math';

import 'vec2.dart';

/// Closed circuit built from a Catmull-Rom spline through seeded control
/// points. Provides surface lookup (tarmac vs grass) and spawn pose.
class Track {
  Track({this.halfWidth = 6.5, int seed = 11, int points = 1600}) {
    final rng = Random(seed);
    const n = 14;
    final ctrl = <Vec2>[];
    for (var i = 0; i < n; i++) {
      final a = 2 * pi * i / n;
      final rad = 120 + rng.nextDouble() * 70;
      ctrl.add(Vec2(cos(a) * rad * 1.35, sin(a) * rad));
    }
    centerline = _sampleSpline(ctrl, points);
    _cumulative = List.filled(centerline.length + 1, 0.0);
    for (var i = 0; i < centerline.length; i++) {
      _cumulative[i + 1] =
          _cumulative[i] + (centerline[(i + 1) % centerline.length] - centerline[i]).length;
    }
    totalLength = _cumulative[centerline.length];
  }

  final double halfWidth;
  late final List<Vec2> centerline;
  late final List<double> _cumulative;
  late final double totalLength;

  int _hint = 0;

  static List<Vec2> _sampleSpline(List<Vec2> ctrl, int count) {
    final out = <Vec2>[];
    final n = ctrl.length;
    for (var i = 0; i < count; i++) {
      final t = i / count * n;
      final seg = t.floor() % n;
      final u = t - t.floor();
      final p0 = ctrl[(seg - 1 + n) % n];
      final p1 = ctrl[seg];
      final p2 = ctrl[(seg + 1) % n];
      final p3 = ctrl[(seg + 2) % n];
      out.add(_catmull(p0, p1, p2, p3, u));
    }
    return out;
  }

  static Vec2 _catmull(Vec2 p0, Vec2 p1, Vec2 p2, Vec2 p3, double t) {
    final t2 = t * t, t3 = t2 * t;
    double f(Vec2 a, Vec2 b, Vec2 c, Vec2 d, double Function(Vec2) g) =>
        0.5 *
        ((2 * g(b)) +
            (-g(a) + g(c)) * t +
            (2 * g(a) - 5 * g(b) + 4 * g(c) - g(d)) * t2 +
            (-g(a) + 3 * g(b) - 3 * g(c) + g(d)) * t3);
    return Vec2(
      f(p0, p1, p2, p3, (p) => p.x),
      f(p0, p1, p2, p3, (p) => p.y),
    );
  }

  /// Nearest centerline index to [p], searching a local window around the
  /// previous result then falling back to a full scan.
  int nearestIndex(Vec2 p) {
    var best = _hint;
    var bestD = double.infinity;
    final n = centerline.length;
    const window = 80;
    for (var k = -window; k <= window; k++) {
      final i = (_hint + k + n) % n;
      final d = (p - centerline[i]).lengthSquared;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (bestD > 900) {
      for (var i = 0; i < n; i++) {
        final d = (p - centerline[i]).lengthSquared;
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
    }
    _hint = best;
    return best;
  }

  /// Signed-ish distance from the centerline (always positive here).
  double distanceToCenterline(Vec2 p) =>
      (p - centerline[nearestIndex(p)]).length;

  /// Surface grip coefficient at a world position.
  double surfaceMu(Vec2 p) {
    final d = distanceToCenterline(p);
    if (d <= halfWidth) return 1.0;
    if (d <= halfWidth + 1.5) return 0.75; // kerb
    return 0.45; // grass
  }

  /// Arc length along the centerline nearest to [p].
  double progress(Vec2 p) => _cumulative[nearestIndex(p)];

  Vec2 tangentAt(int i) =>
      (centerline[(i + 1) % centerline.length] - centerline[i]).normalized();

  /// Spawn pose: on the centerline, aligned with the tangent.
  (Vec2 pos, double heading) spawn() {
    final i = 0;
    return (centerline[i], tangentAt(i).angle);
  }

  /// Signed lateral offset: positive = left of travel direction.
  double lateralOffset(Vec2 p) {
    final i = nearestIndex(p);
    final t = tangentAt(i);
    return t.cross(p - centerline[i]);
  }
}
