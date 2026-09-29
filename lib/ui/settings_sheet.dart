import 'package:flutter/material.dart';

import '../app_state.dart';

/// Environment and car settings. All values feed straight into the physics.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final w = state.env.wind;
    return Container(
      color: const Color(0xFF0B0D10),
      padding: const EdgeInsets.all(16),
      child: ListView(
        shrinkWrap: true,
        children: [
          _slider('wind speed', w.baseSpeed, 0, 30, 'm/s',
              (v) => w.baseSpeed = v),
          _slider('wind direction', w.baseDirectionDeg, 0, 360, 'deg',
              (v) => w.baseDirectionDeg = v),
          _slider('turbulence', w.turbulence, 0, 1, '',
              (v) => w.turbulence = v),
          _slider('gust strength', w.gustStrength, 0, 20, 'm/s',
              (v) => w.gustStrength = v),
          _slider('surface grip', state.env.gripScale, 0.4, 1.3, 'x',
              (v) => state.env.gripScale = v),
          _slider('air density', state.env.airDensity, 0.9, 1.5, 'kg/m3',
              (v) => state.env.airDensity = v),
          const Divider(color: Colors.white12, height: 24),
          _toggle('automatic gearbox', state.car.drivetrain.auto,
              (v) => state.toggleAuto()),
          _toggle('ABS', state.input.absEnabled,
              (v) => state.input.absEnabled = v),
          _toggle('traction control', state.input.tcsEnabled,
              (v) => state.input.tcsEnabled = v),
          _toggle('camera follows car', state.cameraRotate,
              (v) => state.cameraRotate = v),
          _toggle('engine cutaway', state.showEngine,
              (v) => state.showEngine = v),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      String unit, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
            width: 110,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12))),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: const Color(0xFFFF5A1F),
              thumbColor: const Color(0xFFFF5A1F),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 74,
          child: Text(
            '${value.toStringAsFixed(unit == 'deg' || unit == 'm/s' ? 0 : 2)} $unit',
            style: const TextStyle(
                color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFFFF5A1F),
        ),
      ],
    );
  }
}
