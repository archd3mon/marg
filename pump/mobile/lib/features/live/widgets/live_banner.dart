import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';

class LiveBanner extends StatelessWidget {
  final String nextStop;
  final int stopsRemaining;
  final String routeLine;

  const LiveBanner({
    super.key,
    required this.nextStop,
    required this.stopsRemaining,
    required this.routeLine,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final darkC = MargColors.dark;
    final borderRadius = BorderRadius.circular(26);
    final blurActive = Glass.isBlurActive(context);

    final bannerContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x4),
      decoration: BoxDecoration(
        color: blurActive ? darkC.glass : darkC.card.withValues(alpha: 0.94),
        borderRadius: borderRadius,
        border: Border.all(color: darkC.separator, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: darkC.label.withValues(alpha: 0.35),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: c.blue,
              borderRadius: BorderRadius.circular(Rad.md),
            ),
            child: Center(
              child: Icon(
                Icons.directions_bus_rounded,
                color: darkC.label,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Get off at',
                  style: MargText.footnote.copyWith(
                    color: darkC.label2,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  nextStop,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MargText.title3.copyWith(
                    color: darkC.label,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    letterSpacing: -0.6,
                  ),
                ),
                Text(
                  '$stopsRemaining stops · $routeLine',
                  style: MargText.footnote.copyWith(
                    color: darkC.label2,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.tint(c.green, 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: c.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.green.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'SCHEDULED',
                  style: MargText.caption.copyWith(
                    color: c.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x2),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: blurActive
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: bannerContent,
                )
              : bannerContent,
        ),
      ),
    );
  }
}
