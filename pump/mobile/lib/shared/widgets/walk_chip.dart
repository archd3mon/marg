import 'package:flutter/material.dart';
import '../../theme/marg_tokens.dart';

class WalkChip extends StatelessWidget {
  final int durationMins;

  const WalkChip({
    super.key,
    required this.durationMins,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x2, vertical: Sp.x1 / 2),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(Rad.sm / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.directions_walk, size: 13, color: c.gray),
          const SizedBox(width: Sp.x1 / 2),
          Text(
            '$durationMins',
            style: MargText.caption.copyWith(
              color: c.label2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
