import 'dart:math';

class Vec2 {
  const Vec2(this.x, this.y);

  final double x;
  final double y;

  static const zero = Vec2(0, 0);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 operator /(double s) => Vec2(x / s, y / s);
  Vec2 operator -() => Vec2(-x, -y);

  double dot(Vec2 o) => x * o.x + y * o.y;
  double cross(Vec2 o) => x * o.y - y * o.x;
  double get length => sqrt(x * x + y * y);
  double get lengthSquared => x * x + y * y;
  double get angle => atan2(y, x);

  Vec2 normalized() {
    final l = length;
    return l < 1e-9 ? zero : this / l;
  }

  Vec2 rotated(double a) {
    final c = cos(a), s = sin(a);
    return Vec2(x * c - y * s, x * s + y * c);
  }

  Vec2 perp() => Vec2(-y, x);

  Vec2 clamped(double maxLen) {
    final l = length;
    return l > maxLen ? this * (maxLen / l) : this;
  }
}
