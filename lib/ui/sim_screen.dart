import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'controls.dart';
import 'dashboard.dart';
import 'engine_view.dart';
import 'settings_sheet.dart';
import 'telemetry_panel.dart';
import 'track_view.dart';

class SimScreen extends StatelessWidget {
  const SimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return DriveControls(
      state: state,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1410),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              return wide ? _wide(state) : _compact(state);
            },
          ),
        ),
      ),
    );
  }

  Widget _wide(AppState s) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRect(
                        child: TrackView(
                          car: s.car,
                          env: s.env,
                          rotate: s.cameraRotate,
                          particles: s.particles,
                        ),
                      ),
                    ),
                    if (s.showEngine)
                      SizedBox(
                        height: 170,
                        child: EngineView(engine: s.car.engine),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 300, child: TelemetryPanel(state: s)),
            ],
          ),
        ),
        Dashboard(state: s),
        _Toolbar(state: s),
      ],
    );
  }

  Widget _compact(AppState s) {
    return Column(
      children: [
        Expanded(
          child: ClipRect(
            child: TrackView(
              car: s.car,
              env: s.env,
              rotate: s.cameraRotate,
              particles: s.particles,
            ),
          ),
        ),
        SizedBox(height: 120, child: TouchControls(state: s)),
        _Toolbar(state: s),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0D10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _btn(
            icon: state.input.ignition
                ? Icons.power_settings_new
                : Icons.power_off,
            label: 'IGN',
            active: state.input.ignition,
            onTap: () => state.input.ignition = !state.input.ignition,
          ),
          _btn(
            icon: Icons.replay,
            label: 'RESET',
            onTap: state.resetCar,
          ),
          _btn(
            icon: state.running ? Icons.pause : Icons.play_arrow,
            label: state.running ? 'PAUSE' : 'RUN',
            onTap: state.togglePaused,
          ),
          _btn(
            icon: state.car.drivetrain.auto
                ? Icons.settings_suggest
                : Icons.back_hand,
            label: state.car.drivetrain.auto ? 'AUTO' : 'MANUAL',
            onTap: state.toggleAuto,
          ),
          _btn(
            icon: Icons.shutter_speed,
            label: '-',
            onTap: () => state.input.gearDown = true,
          ),
          _btn(
            icon: Icons.shutter_speed,
            label: '+',
            onTap: () => state.input.gearUp = true,
          ),
          const Spacer(),
          _btn(
            icon: Icons.tune,
            label: 'SETUP',
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => SettingsSheet(state: state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn({
    required IconData icon,
    required String label,
    bool active = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFFF5A1F).withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active
                  ? const Color(0xFFFF5A1F)
                  : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 14,
                  color:
                      active ? const Color(0xFFFF5A1F) : Colors.white38),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? const Color(0xFFFF5A1F)
                      : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
