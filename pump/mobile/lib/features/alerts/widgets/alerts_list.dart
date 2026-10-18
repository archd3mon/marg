import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../data/models/alert_model.dart';
import 'alert_row.dart';

class AlertsList extends StatelessWidget {
  final List<TransitAlert> alerts;

  const AlertsList({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x6),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(Rad.md),
          border: Border.all(color: c.separator, width: 0.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 36, color: c.green),
              const SizedBox(height: Sp.x2),
              Text(
                'No active alerts',
                style: MargText.headline.copyWith(color: c.label),
              ),
              const SizedBox(height: Sp.x1),
              Text(
                'All buses on your routes are operating on schedule.',
                style: MargText.footnote.copyWith(color: c.label2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: c.separator, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < alerts.length; i++) ...[
            AlertRow(alert: alerts[i]),
            if (i < alerts.length - 1)
              Divider(color: c.separator, height: 1, indent: 64),
          ],
        ],
      ),
    );
  }
}
