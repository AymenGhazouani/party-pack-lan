import 'package:flutter/material.dart';

import '../audio/audio.dart';

/// Chunky pixel-art button: hard border, solid face, top highlight,
/// presses move the face down 2px.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onTap,
    this.face = const Color(0xffffd166),
    this.textColor = const Color(0xff141419),
    this.fontSize = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
    this.expand = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final Color face;
  final Color textColor;
  final double fontSize;
  final EdgeInsets padding;
  final bool expand;
  final bool enabled;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  Color get _face => widget.enabled ? widget.face : const Color(0xff555566);

  @override
  Widget build(BuildContext context) {
    final pressed = _down && widget.enabled;
    final shadowBase = const Color(0xff141419);
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _down = false);
              if (widget.onTap != null) {
                Audio.tap();
                widget.onTap!();
              }
            }
          : null,
      onTapCancel: () => setState(() => _down = false),
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _face,
          border: Border.all(color: shadowBase, width: 3),
          boxShadow: [
            BoxShadow(
              color: shadowBase,
              offset: Offset(0, pressed ? 1 : 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1px-ish inner highlight to fake depth.
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: widget.fontSize,
                color: widget.enabled ? widget.textColor : const Color(0xff9a9aa8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    final shifted = Transform.translate(
      offset: Offset(0, pressed ? 4 : 0),
      child: button,
    );
    return widget.expand ? SizedBox(width: double.infinity, child: shifted) : shifted;
  }
}

/// Dark panel with pixel border.
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = const Color(0xff26263a),
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: const Color(0xff141419), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0xff0d0d14), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: child,
    );
  }
}

/// Small label in the pixel font.
class PixelLabel extends StatelessWidget {
  const PixelLabel(
    this.text, {
    super.key,
    this.size = 12,
    this.color = const Color(0xffc9c9d6),
    this.letterSpacing = 1,
  });

  final String text;
  final double size;
  final Color color;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.4,
      ),
    );
  }
}

/// Text field styled for the pixel look.
class PixelTextField extends StatelessWidget {
  const PixelTextField({
    super.key,
    required this.controller,
    this.hint = '',
    this.maxLength = 16,
    this.fontSize = 12,
    this.onSubmitted,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final double fontSize;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: fontSize,
        color: Colors.white,
      ),
      cursorColor: const Color(0xffffd166),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: fontSize,
          color: const Color(0xff555566),
        ),
        filled: true,
        fillColor: const Color(0xff16161e),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xff141419), width: 3),
          borderRadius: BorderRadius.zero,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xff141419), width: 3),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xffffd166), width: 3),
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }
}
