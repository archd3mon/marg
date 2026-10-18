import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';

class LiveStatsRow extends StatelessWidget {
  final int remainingMins;
  final String arrivalTime;
  final String routeLine;
  final String statusText;

  const LiveStatsRow({
    super.key,
    required this.remainingMins,
    required this.arrivalTime,
    required this.routeLine,
    this.statusText = 'On time',
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Row(
      children: [
        Expanded(
          child: _StatColumn(
            primary: '$remainingMins',
            secondary: 'min',
            label: 'Remaining',
            color: c.label,
          ),
        ),
        Expanded(
          child: _StatColumn(
            primary: arrivalTime,
            label: 'Arrival',
            color: c.label,
          ),
        ),
        Expanded(
          child: _StatColumn(
            primary: 'On',
            secondary: ' time',
            label: routeLine,
            color: c.green,
          ),
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String primary;
  final String? secondary;
  final String label;
  final Color color;

  const _StatColumn({
    required this.primary,
    this.secondary,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              primary,
              style: MargText.largeTitle.copyWith(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
            if (secondary != null)
              Text(
                secondary!,
                style: MargText.headline.copyWith(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MargText.footnote.copyWith(
            color: c.label2,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
