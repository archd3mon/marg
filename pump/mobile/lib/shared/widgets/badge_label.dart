import 'package:flutter/material.dart';
import '../../theme/marg_tokens.dart';

enum BadgeType {
  fastest,
  fewerTransfers,
  lessWalking,
}

class BadgeLabel extends StatelessWidget {
  final BadgeType type;

  const BadgeLabel({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (label, color, icon) = switch (type) {
      BadgeType.fastest => ('Fastest', c.green, Icons.bolt),
      BadgeType.fewerTransfers => ('Fewer transfers', c.blue, Icons.alt_route),
      BadgeType.lessWalking => ('Less walking', c.orange, Icons.directions_walk),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x2, vertical: Sp.x1),
      decoration: BoxDecoration(
        color: c.tint(color, 0.15),
        borderRadius: BorderRadius.circular(Rad.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: Sp.x1),
          Text(
            label,
            style: MargText.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
