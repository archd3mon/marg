import 'package:flutter/material.dart';
import '../../theme/marg_tokens.dart';

class TimelineRail extends StatelessWidget {
  final Widget? time;
  final Widget child;
  final bool isFirst;
  final bool isLast;
  final bool isDotted;
  final Color? nodeColor;
  final Color? nodeBorderColor;
  final Color? railColor;
  final double railWidth;

  const TimelineRail({
    super.key,
    this.time,
    required this.child,
    this.isFirst = false,
    this.isLast = false,
    this.isDotted = false,
    this.nodeColor,
    this.nodeBorderColor,
    this.railColor,
    this.railWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final effectiveNodeColor = nodeColor ?? (isLast ? c.red : c.card);
    final effectiveBorderColor = nodeBorderColor ?? (isLast ? c.card : (isDotted ? c.gray : c.blue));
    final effectiveRailColor = railColor ?? (isDotted ? c.separator : c.blue);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (time != null) ...[
            SizedBox(
              width: 56,
              child: time!,
            ),
            const SizedBox(width: Sp.x2),
          ],
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: effectiveNodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: effectiveBorderColor,
                      width: isLast ? 2.5 : 3.0,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: isDotted
                          ? _DottedLine(color: effectiveRailColor, width: railWidth)
                          : Container(
                              width: railWidth,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              color: effectiveRailColor,
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Sp.x4),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLine extends StatelessWidget {
  final Color color;
  final double width;

  const _DottedLine({required this.color, required this.width});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        if (height <= 0) return const SizedBox.shrink();
        const dashHeight = 4.0;
        const dashSpace = 3.0;
        final count = (height / (dashHeight + dashSpace)).floor();
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count.clamp(1, 100), (index) {
            return Container(
              width: width,
              height: dashHeight,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        );
      },
    );
  }
}
