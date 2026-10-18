import 'package:flutter/material.dart';

class TimelineRailPainter extends CustomPainter {
  final bool isWalk;
  final bool isAlight;
  final bool isDestination;
  final Color blueColor;
  final Color grayColor;
  final Color redColor;
  final Color cardColor;

  const TimelineRailPainter({
    required this.isWalk,
    required this.isAlight,
    required this.isDestination,
    required this.blueColor,
    required this.grayColor,
    required this.redColor,
    required this.cardColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Center X of rail: Time column (58) + Sp.x2 (8) + half rail (13) = 79.0
    const centerX = 58.0 + 8.0 + 13.0;
    const nodeCenterY = 10.0;
    const nodeRadius = 8.5; // 17dp diameter

    // 1. Draw rail line downwards if not destination
    if (!isDestination) {
      if (isWalk) {
        final dotPaint = Paint()
          ..color = grayColor
          ..style = PaintingStyle.fill;
        const dotRadius = 1.7;
        const spacing = 8.0;
        double y = nodeCenterY + nodeRadius + 3.0;
        while (y < size.height) {
          canvas.drawCircle(Offset(centerX, y), dotRadius, dotPaint);
          y += spacing;
        }
      } else {
        final linePaint = Paint()
          ..color = blueColor
          ..strokeWidth = 5.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          const Offset(centerX, nodeCenterY + 4.0),
          Offset(centerX, size.height),
          linePaint,
        );
      }
    }

    // 2. Draw node (white-filled circle with 4px border)
    final borderColor = isDestination
        ? redColor
        : (isAlight ? grayColor : blueColor);

    // Inner fill
    final fillPaint = Paint()
      ..color = cardColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(centerX, nodeCenterY), nodeRadius, fillPaint);

    // Outer border
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(const Offset(centerX, nodeCenterY), nodeRadius - 2.0, borderPaint);
  }

  @override
  bool shouldRepaint(covariant TimelineRailPainter oldDelegate) {
    return oldDelegate.isWalk != isWalk ||
        oldDelegate.isAlight != isAlight ||
        oldDelegate.isDestination != isDestination ||
        oldDelegate.blueColor != blueColor ||
        oldDelegate.grayColor != grayColor ||
        oldDelegate.redColor != redColor ||
        oldDelegate.cardColor != cardColor;
  }
}
