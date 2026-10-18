import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/badge_label.dart';

class ItineraryHeader extends StatelessWidget {
  final int totalTimeMins;
  final String arrivalTime;
  final int transfers;
  final int totalWalkM;
  final BadgeType badgeType;

  const ItineraryHeader({
    super.key,
    required this.totalTimeMins,
    required this.arrivalTime,
    required this.transfers,
    required this.totalWalkM,
    this.badgeType = BadgeType.fastest,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sheet grabber handle
        Center(
          child: Container(
            width: 36,
            height: 5,
            margin: const EdgeInsets.only(top: 7, bottom: Sp.x2),
            decoration: BoxDecoration(
              color: c.label3,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),

        // Header Title and Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalTimeMins min',
                    style: MargText.title.copyWith(
                      color: c.label,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Arrive $arrivalTime · $transfers ${transfers == 1 ? "transfer" : "transfers"} · $totalWalkM m walk',
                    style: MargText.footnote.copyWith(color: c.label2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Sp.x2),
            BadgeLabel(type: badgeType),
          ],
        ),
      ],
    );
  }
}
