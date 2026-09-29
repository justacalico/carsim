import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';

/// Keyboard + touch driver inputs. Keyboard: W/S throttle/brake, A/D steer,
/// Q/E gears, I ignition, R reset, H handbrake, P pause, C clutch.
class DriveControls extends StatefulWidget {
  const DriveControls({super.key, required this.state, required this.child});

  final AppState state;
  final Widget child;

  @override
  State<DriveControls> createState() => _DriveControlsState();
}

class _DriveControlsState extends State<DriveControls> {
  final _focus = FocusNode();

  // Held-key state -> analog channels.
  final Set<LogicalKeyboardKey> _held = {};

  AppState get s => widget.state;

  void _apply() {
    final i = s.input;
    i.throttle = _down(LogicalKeyboardKey.keyW) ||
            _down(LogicalKeyboardKey.arrowUp)
        ? 1.0
        : 0.0;
    i.brake = _down(LogicalKeyboardKey.keyS) ||
            _down(LogicalKeyboardKey.arrowDown)
        ? 1.0
        : 0.0;
    i.clutch = _down(LogicalKeyboardKey.keyC) ? 1.0 : 0.0;
    i.handbrake = _down(LogicalKeyboardKey.space);
    var steer = 0.0;
    if (_down(LogicalKeyboardKey.keyA) ||
        _down(LogicalKeyboardKey.arrowLeft)) {
      steer += 1;
    }
    if (_down(LogicalKeyboardKey.keyD) ||
        _down(LogicalKeyboardKey.arrowRight)) {
      steer -= 1;
    }
    i.steer = steer;
  }

  bool _down(LogicalKeyboardKey k) => _held.contains(k);

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final k = e.logicalKey;
    if (e is KeyDownEvent) {
      if (!_held.contains(k)) {
        _held.add(k);
        if (k == LogicalKeyboardKey.keyI) s.input.ignition = !s.input.ignition;
        if (k == LogicalKeyboardKey.keyE) s.input.gearUp = true;
        if (k == LogicalKeyboardKey.keyQ) s.input.gearDown = true;
        if (k == LogicalKeyboardKey.keyR) s.resetCar();
        if (k == LogicalKeyboardKey.keyP) s.togglePaused();
        if (k == LogicalKeyboardKey.keyM) s.toggleAuto();
      }
    } else if (e is KeyUpEvent) {
      _held.remove(k);
    }
    _apply();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: _focus.requestFocus,
        child: widget.child,
      ),
    );
  }
}

/// On-screen pedals + steering for touch / compact layouts.
class TouchControls extends StatelessWidget {
  const TouchControls({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SteerPad(state: state)),
        _Pedal(
          label: 'BRK',
          color: const Color(0xFFFF3B30),
          onLevel: (v) => state.input.brake = v,
        ),
        _Pedal(
          label: 'THR',
          color: const Color(0xFF30D158),
          onLevel: (v) => state.input.throttle = v,
        ),
      ],
    );
  }
}

class _SteerPad extends StatefulWidget {
  const _SteerPad({required this.state});

  final AppState state;

  @override
  State<_SteerPad> createState() => _SteerPadState();
}

class _SteerPadState extends State<_SteerPad> {
  double _x = 0;

  void _update(Offset local) {
    final w = (context.findRenderObject() as RenderBox).size.width;
    setState(() {
      _x = ((local.dx / w) * 2 - 1).clamp(-1.0, 1.0);
      widget.state.input.steer = -_x; // drag left = steer left
    });
  }

  void _release() {
    setState(() {
      _x = 0;
      widget.state.input.steer = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _update(e.localPosition),
      onPointerMove: (e) => _update(e.localPosition),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: Container(
        height: double.infinity,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF14181D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text('STEER',
                style: TextStyle(color: Colors.white24, fontSize: 10)),
            Align(
              alignment: Alignment(_x * 0.85, 0),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1F6FEB),
                  border:
                      Border.all(color: Colors.white24, width: 1.5),
                ),
                child: const Icon(Icons.circle_outlined,
                    color: Colors.white54, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pedal extends StatefulWidget {
  const _Pedal({required this.label, required this.color, required this.onLevel});

  final String label;
  final Color color;
  final ValueChanged<double> onLevel;

  @override
  State<_Pedal> createState() => _PedalState();
}

class _PedalState extends State<_Pedal> {
  double _level = 0;

  void _set(double v) {
    setState(() => _level = v);
    widget.onLevel(v);
  }

  void _fromPointer(Offset local) {
    final h = (context.findRenderObject() as RenderBox).size.height;
    _set(((h - local.dy) / h).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _fromPointer(e.localPosition),
      onPointerMove: (e) => _fromPointer(e.localPosition),
      onPointerUp: (_) => _set(0),
      onPointerCancel: (_) => _set(0),
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF14181D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            FractionallySizedBox(
              heightFactor: _level,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(widget.label,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }
}
