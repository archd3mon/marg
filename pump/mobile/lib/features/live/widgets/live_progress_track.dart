import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';

class LiveProgressTrack extends StatelessWidget {
  final double progressPercent;

  const LiveProgressTrack({
    super.key,
    required this.progressPercent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final clampedProgress = progressPercent.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const busSize = 32.0;
        final busLeft = (totalWidth * clampedProgress - (busSize / 2)).clamp(0.0, totalWidth - busSize);

        return SizedBox(
          height: 40,
          width: totalWidth,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // 1. Base track line
              Positioned(
                left: 0,
                right: 0,
                top: 17,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.fill,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // 2. Active done track line
              Positioned(
                left: 0,
                top: 17,
                child: Container(
                  width: totalWidth * clampedProgress,
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.blue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // 3. Stop dots along track
              _buildStopDot(
                left: 0,
                color: c.blue,
                borderColor: c.blue,
                cardColor: c.card,
              ),
              _buildStopDot(
                left: totalWidth * 0.29 - 5,
                color: c.card,
                borderColor: clampedProgress >= 0.29 ? c.blue : c.gray,
                cardColor: c.card,
              ),
              _buildStopDot(
                left: totalWidth * 0.72 - 5,
                color: c.card,
                borderColor: clampedProgress >= 0.72 ? c.blue : c.gray,
                cardColor: c.card,
              ),
              _buildStopDot(
                left: totalWidth - 14,
                color: c.card,
                borderColor: c.red,
                size: 14,
                borderWidth: 2.5,
                cardColor: c.card,
              ),

              // 4. Moving bus indicator (me)
              Positioned(
                left: busLeft,
                top: 4,
                child: Container(
                  width: busSize,
                  height: busSize,
                  decoration: BoxDecoration(
                    color: c.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.card, width: 3.5),
                    boxShadow: [
                      BoxShadow(
                        color: c.blue.withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.directions_bus_rounded,
                      color: c.card,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStopDot({
    required double left,
    required Color color,
    required Color borderColor,
    required Color cardColor,
    double size = 10,
    double borderWidth = 2.5,
  }) {
    return Positioned(
      left: left,
      top: (40 - size) / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
      ),
    );
  }
}
