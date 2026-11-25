import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../state/input_bus.dart';

/// Virtual joystick anchored bottom-left. Emits normalized vectors on the
/// global [inputBus]; releasing recentres it.
class Joystick extends StatefulWidget {
  const Joystick({
    super.key,
    this.size = 128,
    this.lockX = false,
  });

  /// Diameter of the base circle.
  final double size;
  final bool lockX;

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _knob = Offset.zero;

  double get _radius => widget.size / 2 - 14;

  void _update(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    var delta = localPosition - center;
    if (widget.lockX) delta = Offset(delta.dx, 0);
    final dist = delta.distance;
    if (dist > _radius) {
      delta = delta / dist * _radius;
    }
    setState(() => _knob = delta);
    inputBus.setJoystick(delta.dx / _radius, delta.dy / _radius);
  }

  void _reset() {
    setState(() => _knob = Offset.zero);
    inputBus.setJoystick(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      onTap: () => _update(Offset(widget.size / 2, widget.size / 2)),
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _JoystickPainter(knobOffset: _knob, radius: _radius),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({required this.knobOffset, required this.radius});

  final Offset knobOffset;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..color = const Color(0x33ffffff)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fill = Paint()..color = const Color(0x22000000);
    canvas.drawCircle(center, radius + 14, fill);
    canvas.drawCircle(center, radius + 14, ring);

    // Pixel-ish cross ticks.
    final tick = Paint()
      ..color = const Color(0x44ffffff)
      ..strokeWidth = 3;
    canvas.drawLine(center - Offset(radius + 4, 0), center - Offset(radius - 6, 0), tick);
    canvas.drawLine(center + Offset(radius + 4, 0), center + Offset(radius - 6, 0), tick);
    canvas.drawLine(center - Offset(0, radius + 4), center - Offset(0, radius - 6), tick);
    canvas.drawLine(center + Offset(0, radius + 4), center + Offset(0, radius - 6), tick);

    final knob = knobOffset + center;
    canvas.drawCircle(knob, 24, Paint()..color = const Color(0xffffd166));
    canvas.drawCircle(
      knob,
      24,
      Paint()
        ..color = const Color(0xff141419)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.knobOffset != knobOffset;
}

/// Round hold-to-fire action button (fire-and-forget style with tap/hold).
class ActionHoldButton extends StatefulWidget {
  const ActionHoldButton({
    super.key,
    required this.label,
    required this.onDown,
    required this.onUp,
    this.size = 96,
    this.face = const Color(0xff4cc9f0),
  });

  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final double size;
  final Color face;

  @override
  State<ActionHoldButton> createState() => _ActionHoldButtonState();
}

class _ActionHoldButtonState extends State<ActionHoldButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _down = true);
        widget.onDown();
      },
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onUp();
      },
      onTapCancel: () {
        setState(() => _down = false);
        widget.onUp();
      },
      child: Transform.translate(
        offset: Offset(0, _down ? 3 : 0),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.face,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xff141419), width: 4),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 11,
              color: Color(0xff141419),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big MASH button for tug-of-war.
class MashButton extends StatefulWidget {
  const MashButton({super.key});

  @override
  State<MashButton> createState() => _MashButtonState();
}

class _MashButtonState extends State<MashButton> {
  int _pop = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        inputBus.tapMash();
        Audio.mash();
        setState(() => _pop++);
      },
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_pop),
        tween: Tween(begin: 1.25, end: 1.0),
        duration: const Duration(milliseconds: 120),
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          child: child,
        ),
        child: Container(
          width: 150,
          height: 150,
          decoration: const BoxDecoration(
            color: Color(0xffef476f),
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xff141419), width: 5),
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'MASH!',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
