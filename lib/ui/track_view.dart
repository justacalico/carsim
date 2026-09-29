import 'dart:math';

import 'package:flutter/material.dart';

import '../sim/car.dart';
import '../sim/environment.dart';
import '../sim/vec2.dart';

/// Top-down chase view of the car on the circuit. Camera centers on the car
/// and can rotate with its heading.
class TrackView extends StatelessWidget {
  const TrackView({
    super.key,
    required this.car,
    required this.env,
    required this.rotate,
    required this.particles,
  });

  final Car car;
  final Environment env;
  final bool rotate;
  final List<Vec2> particles;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrackPainter(
        car: car,
        env: env,
        rotate: rotate,
        particles: particles,
      ),
      size: Size.infinite,
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.car,
    required this.env,
    required this.rotate,
    required this.particles,
  });

  final Car car;
  final Environment env;
  final bool rotate;
  final List<Vec2> particles;

  static const _grass = Color(0xFF0E1410);
  static const _tarmac = Color(0xFF2B2E33);
  static const _kerbA = Color(0xFFB33030);
  static const _kerbB = Color(0xFFD8D8D8);
  static const _carBody = Color(0xFF1F6FEB);
  static const _accent = Color(0xFFFF5A1F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _grass);

    // Camera: meters -> pixels.
    const zoom = 7.0;
    final camAngle = rotate ? -car.yaw - pi / 2 : -pi / 2;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.rotate(camAngle);
    canvas.translate(-car.pos.x, -car.pos.y);

    _paintTrack(canvas);
    _paintWind(canvas);
    _paintCar(canvas);

    canvas.restore();
  }

  void _paintTrack(Canvas canvas) {
    final line = env.track.centerline;
    final path = Path()..moveTo(line[0].x, line[0].y);
    for (final p in line) {
      path.lineTo(p.x, p.y);
    }
    path.close();

    // Kerb band under the tarmac.
    canvas.drawPath(
      path,
      Paint()
        ..color = _kerbB
        ..style = PaintingStyle.stroke
        ..strokeWidth = env.track.halfWidth * 2 + 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _tarmac
        ..style = PaintingStyle.stroke
        ..strokeWidth = env.track.halfWidth * 2
        ..strokeJoin = StrokeJoin.round,
    );

    // Kerb stripes: short perpendicular ticks at intervals.
    final tickPaint = Paint()
      ..color = _kerbA
      ..strokeWidth = 0.9;
    for (var i = 0; i < line.length; i += 40) {
      final t = env.track.tangentAt(i);
      final n = t.perp();
      for (final s in [-1.0, 1.0]) {
        final a = line[i] + n * (env.track.halfWidth + 0.4) * s;
        final b = line[i] + n * (env.track.halfWidth + 1.4) * s;
        canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), tickPaint);
      }
    }

    // Start line.
    final t0 = env.track.tangentAt(0);
    final n0 = t0.perp();
    canvas.drawLine(
      Offset(line[0].x - n0.x * env.track.halfWidth,
          line[0].y - n0.y * env.track.halfWidth),
      Offset(line[0].x + n0.x * env.track.halfWidth,
          line[0].y + n0.y * env.track.halfWidth),
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 0.5,
    );
  }

  void _paintWind(Canvas canvas) {
    final wind = env.wind.lastWind;
    final wLen = wind.length;
    if (wLen < 0.5) return;
    final dir = wind.normalized();
    final alpha = (wLen / 18).clamp(0.05, 0.5);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = 0.12
      ..strokeCap = StrokeCap.round;
    for (final p in particles) {
      canvas.drawLine(
        Offset(p.x, p.y),
        Offset(p.x - dir.x * 1.4, p.y - dir.y * 1.4),
        paint,
      );
    }
  }

  void _paintCar(Canvas canvas) {
    canvas.save();
    canvas.translate(car.pos.x, car.pos.y);
    canvas.rotate(car.yaw);

    // Shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-1.45, -0.75, 4.55, 1.62),
        const Radius.circular(0.35),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Wheels at their steered angles.
    final wheelPaint = Paint()..color = const Color(0xFF15171A);
    for (var i = 0; i < 4; i++) {
      final r = car.relPos[i];
      canvas.save();
      canvas.translate(r.x, r.y);
      canvas.rotate(car.wheels[i].angle);
      final brakeGlow =
          ((car.wheels[i].brakeTemp - 60) / 500).clamp(0.0, 1.0);
      canvas.drawRect(
        const Rect.fromLTWH(-0.32, -0.13, 0.64, 0.26),
        brakeGlow > 0.15
            ? (Paint()
              ..color = Color.lerp(const Color(0xFF15171A),
                  const Color(0xFFFF3300), brakeGlow)!)
            : wheelPaint,
      );
      canvas.restore();
    }

    // Body.
    final body = Path()
      ..moveTo(3.0, 0)
      ..lineTo(2.4, 0.72)
      ..lineTo(-1.35, 0.8)
      ..lineTo(-1.55, 0.55)
      ..lineTo(-1.55, -0.55)
      ..lineTo(-1.35, -0.8)
      ..lineTo(2.4, -0.72)
      ..close();
    canvas.drawPath(body, Paint()..color = _carBody);
    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.04,
    );
    // Cabin.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-0.7, -0.6, 1.7, 1.2),
        const Radius.circular(0.3),
      ),
      Paint()..color = const Color(0xFF0D1117),
    );
    // Steering direction marker.
    canvas.drawCircle(
      const Offset(2.6, 0),
      0.09,
      Paint()..color = _accent,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrackPainter old) => true;
}
