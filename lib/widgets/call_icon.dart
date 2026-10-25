import 'package:flutter/material.dart';

/// The green call badge used across Samsung's own dialer/contacts apps — a
/// green squircle with a white phone-handset glyph — instead of a plain
/// Material icon dropped straight onto whatever background is behind it.
///
/// Two shapes are exposed:
/// - [CallIcon] draws the full badge (green squircle + white handset). Use
///   it wherever the surrounding surface isn't already this green — a case
///   key, a list tile's leading/trailing slot, a button on a white card.
/// - [CallGlyph] draws just the handset, no squircle behind it. Use it on a
///   surface that's already this green, e.g. the home screen's CALL tile,
///   where a second green badge on top of the green tile would double up.
class CallIcon extends StatelessWidget {
  const CallIcon({
    super.key,
    this.size = 40,
    this.color = const Color(0xFF3FAE4C),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: CallGlyph(size: size * 0.56, color: Colors.white),
    );
  }
}

class CallGlyph extends StatelessWidget {
  const CallGlyph({super.key, required this.size, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.call, size: size, color: color);
  }
}
