import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/marg_tokens.dart';

class ResultsEmptyView extends StatelessWidget {
  const ResultsEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x6),
      margin: const EdgeInsets.only(bottom: Sp.x4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: c.separator, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: c.tint(c.gray), shape: BoxShape.circle),
            child: Icon(Icons.directions_bus_outlined, color: c.label2, size: 24),
          ),
          const SizedBox(height: Sp.x3),
          Text('Too far from transit network', style: MargText.headline.copyWith(color: c.label), textAlign: TextAlign.center),
          const SizedBox(height: Sp.x1),
          Text(
            'No PMPML bus routes found between these locations. Try adjusting your origin or destination pin.',
            style: MargText.footnote.copyWith(color: c.label2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Sp.x4),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.blue,
                side: BorderSide(color: c.blue, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
              ),
              child: const Text('Change Points'),
            ),
          ),
        ],
      ),
    );
  }
}
