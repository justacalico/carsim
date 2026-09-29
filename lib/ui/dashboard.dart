import 'package:flutter/material.dart';

import '../app_state.dart';

/// Instrument strip: tach, digital speed, gear, warning lamps and lap timer.
class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = state.telemetry;
    return Container(
      color: const Color(0xFF0B0D10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _Tacho(state: state)),
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t == null ? '0' : t.speedKmh.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const Text('km/h',
                  style: TextStyle(fontSize: 11, color: Colors.white38)),
              const SizedBox(height: 4),
              _GearBadge(gear: t?.gear ?? 0),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Lamps(state: state),
              const SizedBox(height: 6),
              _LapTimes(state: state),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tacho extends StatelessWidget {
  const _Tacho({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = state.telemetry;
    final rpm = t?.rpm ?? 0;
    final redline = state.car.engine.redlineRpm;
    return LayoutBuilder(
      builder: (context, c) {
        return CustomPaint(
          painter: _TachoPainter(rpm: rpm, redline: redline),
          size: Size(c.maxWidth, c.maxHeight),
        );
      },
    );
  }
}

class _TachoPainter extends CustomPainter {
  _TachoPainter({required this.rpm, required this.redline});

  final double rpm;
  final double redline;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final maxRpm = redline * 1.1;
    final frac = (rpm / maxRpm).clamp(0.0, 1.0);
    final redFrac = redline / maxRpm;

    // Track.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.3, w, h * 0.4),
      Paint()..color = const Color(0xFF1A1E24),
    );
    // Fill.
    final fillColor = frac > redFrac
        ? const Color(0xFFFF3B30)
        : const Color(0xFFFF5A1F);
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.3, w * frac, h * 0.4),
      Paint()..color = fillColor,
    );
    // Redline marker.
    canvas.drawRect(
      Rect.fromLTWH(w * redFrac - 1, h * 0.22, 2, h * 0.56),
      Paint()..color = Colors.white54,
    );

    _text(canvas, 'rpm ${rpm.toStringAsFixed(0)}',
        Offset(4, h * 0.3 - 16), 11, Colors.white54);
    _text(canvas, (redline / 1000).toStringAsFixed(0),
        Offset(w * redFrac - 6, h * 0.78), 10, Colors.white38);
  }

  void _text(Canvas canvas, String s, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: size, color: color, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_TachoPainter old) => old.rpm != rpm;
}

class _GearBadge extends StatelessWidget {
  const _GearBadge({required this.gear});

  final int gear;

  @override
  Widget build(BuildContext context) {
    final label = gear == 0 ? 'N' : (gear < 0 ? 'R' : '$gear');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFFF5A1F), width: 1.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFF5A1F),
        ),
      ),
    );
  }
}

class _Lamps extends StatelessWidget {
  const _Lamps({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = state.telemetry;
    final e = state.car.engine;
    final absOn = t?.absActive.any((a) => a) ?? false;
    final tcsOn = state.input.tcsEnabled;
    final limit = e.rpm > e.redlineRpm - 200;
    final fuelLow = e.fuelUsedGrams / 1000 > 40;
    final stalled = state.input.ignition && !e.running;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _lamp('IGN', state.input.ignition, const Color(0xFF30D158)),
        _lamp('ENG', stalled, const Color(0xFFFF9F0A)),
        _lamp('ABS', absOn, const Color(0xFF64D2FF)),
        _lamp('TCS', tcsOn, const Color(0xFF30D158)),
        _lamp('FUEL', fuelLow, const Color(0xFFFF9F0A)),
        _lamp('LIM', limit, const Color(0xFFFF3B30)),
      ],
    );
  }

  Widget _lamp(String label, bool on, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: on ? color.withValues(alpha: 0.2) : Colors.transparent,
        border: Border.all(
            color: on ? color : Colors.white24, width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: on ? color : Colors.white24,
        ),
      ),
    );
  }
}

class _LapTimes extends StatelessWidget {
  const _LapTimes({required this.state});

  final AppState state;

  String _fmt(Duration? d) {
    if (d == null) return '--:--.--';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final cs = (d.inMilliseconds % 1000) ~/ 10;
    return '$m:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontSize: 11, color: Colors.white70, fontFamily: 'monospace');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('LAP  ${_fmt(state.currentLapStart == null ? null : state.simTime - state.currentLapStart!)}',
            style: style),
        Text('LAST ${_fmt(state.lastLap)}', style: style),
        Text('BEST ${_fmt(state.bestLap)}', style: style),
      ],
    );
  }
}
