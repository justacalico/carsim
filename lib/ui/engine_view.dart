import 'dart:math';

import 'package:flutter/material.dart';

import '../sim/engine.dart';

/// Live cross-section of the engine: every piston rides its slider-crank,
/// valves tick on the cycle, combustion flashes orange, and a pressure bar
/// under each bore tracks instantaneous cylinder pressure.
class EngineView extends StatelessWidget {
  const EngineView({super.key, required this.engine});

  final Engine engine;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EnginePainter(engine),
      size: Size.infinite,
    );
  }
}

class _EnginePainter extends CustomPainter {
  _EnginePainter(this.e);

  final Engine e;

  static const _metal = Color(0xFF8E959E);
  static const _metalDark = Color(0xFF4A5058);
  static const _bg = Color(0xFF0B0D10);
  static const _hot = Color(0xFFFF5A1F);
  static const _gas = Color(0xFF3E7CB1);
  static const _exhaust = Color(0xFF6E5A44);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);

    final n = e.cylinders;
    final colW = size.width / n;
    final boreW = colW * 0.55;
    final topPad = size.height * 0.16;
    final boreTop = topPad + size.height * 0.06;
    final boreBottom = size.height * 0.62;
    final crankY = size.height * 0.82;
    final crankR = min(colW * 0.28, size.height * 0.14);
    final strokePx = boreBottom - boreTop;

    for (var i = 0; i < n; i++) {
      final cx = colW * (i + 0.5);
      final phase = e.cyclePhase(i);
      final pos = e.pistonPosition(i); // 0 TDC .. 1 BDC
      final pistonY = boreTop + pos * strokePx;
      final pressure = e.cyl[i].pressure / 1e5;

      // Gas fill colour shows what's in the cylinder right now.
      Color gasColor;
      if (phase < 180) {
        gasColor = _gas.withValues(alpha: 0.25);
      } else if (phase < 360) {
        gasColor = _gas.withValues(alpha: 0.12);
      } else if (phase < 540) {
        final burnGlow =
            phase < 430 ? (1 - (phase - 360) / 70).clamp(0.0, 1.0) : 0.0;
        gasColor = Color.lerp(
          _exhaust.withValues(alpha: 0.15),
          _hot,
          burnGlow * 0.85,
        )!;
      } else {
        gasColor = _exhaust.withValues(alpha: 0.2);
      }
      canvas.drawRect(
        Rect.fromLTRB(cx - boreW / 2, boreTop, cx + boreW / 2, pistonY),
        Paint()..color = gasColor,
      );

      // Bore walls.
      final wallPaint = Paint()
        ..color = _metalDark
        ..strokeWidth = 2;
      canvas.drawLine(
          Offset(cx - boreW / 2, boreTop - 4),
          Offset(cx - boreW / 2, boreBottom + 4),
          wallPaint);
      canvas.drawLine(
          Offset(cx + boreW / 2, boreTop - 4),
          Offset(cx + boreW / 2, boreBottom + 4),
          wallPaint);
      canvas.drawLine(Offset(cx - boreW / 2 - 6, boreTop - 4),
          Offset(cx + boreW / 2 + 6, boreTop - 4), wallPaint);

      // Valves: open during intake / exhaust strokes.
      final intakeOpen = phase < 180 ? _lift(phase, 0, 180) : 0.0;
      final exhaustOpen = phase >= 540 ? _lift(phase - 540, 0, 180) : 0.0;
      _valve(canvas, cx - boreW * 0.22, boreTop - 8, intakeOpen, _gas);
      _valve(canvas, cx + boreW * 0.22, boreTop - 8, exhaustOpen, _exhaust);

      // Spark flash during combustion.
      if (phase >= 355 && phase < 400 && e.running) {
        canvas.drawCircle(
          Offset(cx, boreTop - 10),
          4 + (phase - 355) / 45 * 6,
          Paint()..color = _hot.withValues(alpha: 0.8),
        );
      }

      // Connecting rod: piston pin to crank pin.
      final crankA = (e.theta + e.cyl[i].phaseOffsetDeg * pi / 180);
      final pinX = cx + sin(crankA) * crankR;
      final pinY = crankY - cos(crankA) * crankR;
      canvas.drawLine(
        Offset(cx, pistonY + 6),
        Offset(pinX, pinY),
        Paint()
          ..color = _metal
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );

      // Piston.
      canvas.drawRect(
        Rect.fromLTRB(
            cx - boreW / 2 + 2, pistonY, cx + boreW / 2 - 2, pistonY + 12),
        Paint()..color = _metal,
      );

      // Crank web.
      canvas.drawCircle(
          Offset(cx, crankY), crankR * 0.55, Paint()..color = _metalDark);
      canvas.drawLine(
        Offset(cx, crankY),
        Offset(pinX, pinY),
        Paint()
          ..color = _metalDark
          ..strokeWidth = 6,
      );
      canvas.drawCircle(Offset(pinX, pinY), 3, Paint()..color = _metal);

      // Pressure bar.
      final pFrac = (pressure / 140).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(cx - boreW / 2, size.height - 10, boreW * pFrac, 6),
        Paint()
          ..color = Color.lerp(_gas, _hot, (pFrac * 2).clamp(0.0, 1.0))!,
      );
    }
  }

  double _lift(double phase, double start, double dur) {
    final t = ((phase - start) / dur).clamp(0.0, 1.0);
    return sin(t * pi);
  }

  void _valve(
      Canvas canvas, double x, double y, double lift, Color color) {
    canvas.drawLine(
      Offset(x, y - lift * 6),
      Offset(x, y - 12 - lift * 6),
      Paint()
        ..color = _metal
        ..strokeWidth = 2.5,
    );
    canvas.drawLine(
      Offset(x - 6, y - lift * 6),
      Offset(x + 6, y - lift * 6),
      Paint()
        ..color = lift > 0.3 ? color : _metal
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_EnginePainter old) => true;
}
