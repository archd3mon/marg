import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';

class ResultsHeader extends StatelessWidget {
  final int routeCount;
  final String? warning;

  const ResultsHeader({
    super.key,
    required this.routeCount,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$routeCount routes', style: MargText.title3.copyWith(color: c.label, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('PMPML buses · live schedule', style: MargText.footnote.copyWith(color: c.label2)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x1 + 1),
              decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(Rad.sm)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: c.label),
                  const SizedBox(width: Sp.x1),
                  Text('Leave now', style: MargText.footnote.copyWith(color: c.label, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        if (warning != null && warning!.isNotEmpty) ...[
          const SizedBox(height: Sp.x2),
          Text(warning!, style: MargText.caption.copyWith(color: c.orange)),
        ],
      ],
    );
  }
}
