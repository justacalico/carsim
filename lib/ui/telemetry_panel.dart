import 'package:flutter/material.dart';

import '../app_state.dart';
import '../sim/vec2.dart';

/// Numeric telemetry column: wheel loads, slips, temperatures, suspension,
/// wind and g-forces. Every number is live physics.
class TelemetryPanel extends StatelessWidget {
  const TelemetryPanel({super.key, required this.state});

  final AppState state;

  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    color: Colors.white70,
  );
  static const _dim = TextStyle(
    fontFamily: 'monospace',
    fontSize: 10,
    color: Colors.white38,
  );

  @override
  Widget build(BuildContext context) {
    final t = state.telemetry;
    if (t == null) return const SizedBox.shrink();
    final w = state.car.wheels;

    return Container(
      color: const Color(0xFF0B0D10),
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          _section('WHEELS  FL / FR / RL / RR'),
          _row('load N',
              t.wheelLoad.map((v) => v.toStringAsFixed(0)).join('  ')),
          _row('slip %',
              t.slipRatio.map((v) => (v * 100).toStringAsFixed(0)).join('  ')),
          _row('slip ang',
              t.slipAngleDeg.map((v) => v.toStringAsFixed(1)).join('  ')),
          _row('tire C',
              t.tireTemp.map((v) => v.toStringAsFixed(0)).join('  ')),
          _row('brake C',
              t.brakeTemp.map((v) => v.toStringAsFixed(0)).join('  ')),
          _row('susp mm',
              t.suspensionTravel
                  .map((v) => (v * 1000).toStringAsFixed(0))
                  .join('  ')),
          const SizedBox(height: 10),
          _section('ENGINE'),
          _row('torque', '${t.engineTorque.toStringAsFixed(0)} Nm'),
          _row('power', '${t.powerKw.toStringAsFixed(0)} kW'),
          _row('manifold', '${t.manifoldBar.toStringAsFixed(2)} bar'),
          _row('boost', '${t.boostBar.toStringAsFixed(2)} bar'),
          _row('coolant', '${t.engineTemp.toStringAsFixed(0)} C'),
          _row('fuel used', '${t.fuelUsedKg.toStringAsFixed(2)} kg'),
          _row('clutch', '${t.clutchTorque.toStringAsFixed(0)} Nm'),
          const SizedBox(height: 10),
          _section('BODY'),
          _row('lat G', t.latG.toStringAsFixed(2)),
          _row('long G', t.longG.toStringAsFixed(2)),
          _row('heave', '${(t.heave * 1000).toStringAsFixed(0)} mm'),
          _row('pitch', '${t.pitchDeg.toStringAsFixed(2)} deg'),
          _row('roll', '${t.rollDeg.toStringAsFixed(2)} deg'),
          _row('downforce', '${t.downforceN.toStringAsFixed(0)} N'),
          const SizedBox(height: 10),
          _section('WIND'),
          _WindCompass(wind: t.windVec),
          _row('speed', '${(t.windVec.length * 3.6).toStringAsFixed(1)} km/h'),
          _row('apparent', '${t.apparentWindKmh.toStringAsFixed(1)} km/h'),
          const SizedBox(height: 10),
          _section('CYLINDER PRESSURE bar'),
          _PressureBars(pressures: t.cylinderPressureBar),
          _row('phase',
              t.cyclePhase.map((p) => p.toStringAsFixed(0)).join('  ')),
          const SizedBox(height: 10),
          _section('TRACK'),
          _row('lap pos', '${(t.lapProgress).toStringAsFixed(0)} m'),
          _row('offset', '${t.lateralOffset.toStringAsFixed(1)} m'),
          const SizedBox(height: 8),
          if (w.isNotEmpty) ...[],
        ],
      ),
    );
  }

  Widget _section(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 4),
        child: Text(s, style: _dim.copyWith(letterSpacing: 1.4)),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: _dim),
            Text(value, style: _mono),
          ],
        ),
      );
}

class _WindCompass extends StatelessWidget {
  const _WindCompass({required this.wind});

  final Vec2 wind;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: CustomPaint(
        painter: _CompassPainter(wind),
        size: const Size(double.infinity, 56),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter(this.wind);

  final Vec2 wind;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, 24, Paint()..color = const Color(0xFF1A1E24));
    final dir = wind.length > 0.1 ? wind.normalized() : Vec2.zero;
    final len = (wind.length * 2.2).clamp(0.0, 22.0);
    if (len > 0.5) {
      canvas.drawLine(
        c,
        c + Offset(dir.x, dir.y) * len,
        Paint()
          ..color = const Color(0xFF64D2FF)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.wind != wind;
}

class _PressureBars extends StatelessWidget {
  const _PressureBars({required this.pressures});

  final List<double> pressures;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in pressures)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  height: 4 + (p / 140).clamp(0.0, 1.0) * 30,
                  color: Color.lerp(const Color(0xFF3E7CB1),
                      const Color(0xFFFF5A1F), (p / 120).clamp(0.0, 1.0)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
