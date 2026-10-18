import 'package:flutter/material.dart';
import '../../theme/marg_tokens.dart';

enum TileColor {
  blue,
  orange,
  green,
  red,
  gray,
}

class TileIcon extends StatelessWidget {
  final IconData icon;
  final TileColor color;
  final double size;
  final double iconSize;
  final bool solid;
  final bool isCircle;
  final double? radius;

  const TileIcon({
    super.key,
    required this.icon,
    this.color = TileColor.blue,
    this.size = 36,
    this.iconSize = 18,
    this.solid = false,
    this.isCircle = false,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = solid
        ? switch (color) {
            TileColor.blue => (c.blue, c.card),
            TileColor.orange => (c.orange, c.card),
            TileColor.green => (c.green, c.card),
            TileColor.red => (c.red, c.card),
            TileColor.gray => (c.fill, c.blue),
          }
        : switch (color) {
            TileColor.blue => (c.tint(c.blue, 0.15), c.blue),
            TileColor.orange => (c.tint(c.orange, 0.15), c.orange),
            TileColor.green => (c.tint(c.green, 0.15), c.green),
            TileColor.red => (c.tint(c.red, 0.15), c.red),
            TileColor.gray => (c.fill, c.label2),
          };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(radius ?? Rad.sm),
      ),
      child: Center(
        child: Icon(icon, color: fg, size: iconSize),
      ),
    );
  }
}
