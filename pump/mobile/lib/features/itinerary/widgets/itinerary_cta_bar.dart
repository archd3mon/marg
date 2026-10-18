import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/primary_button.dart';

class ItineraryCtaBar extends StatelessWidget {
  final VoidCallback onStartTrip;
  final VoidCallback onToggleSave;
  final bool isSaved;

  const ItineraryCtaBar({
    super.key,
    required this.onStartTrip,
    required this.onToggleSave,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Row(
      children: [
        // 1. Primary CTA: Start Trip
        Expanded(
          child: PrimaryButton(
            label: 'Start Trip',
            icon: Transform.rotate(
              angle: 0.785, // 45 degrees
              child: Icon(Icons.near_me, color: c.card, size: 17),
            ),
            onPressed: onStartTrip,
          ),
        ),
        const SizedBox(width: Sp.x3),

        // 2. Save Route Bookmark Button
        Semantics(
          button: true,
          label: isSaved ? 'Route saved' : 'Save route',
          child: Material(
            color: c.tint(c.blue, 0.12),
            borderRadius: BorderRadius.circular(Rad.md),
            child: InkWell(
              onTap: onToggleSave,
              borderRadius: BorderRadius.circular(Rad.md),
              child: SizedBox(
                width: 52,
                height: Layout.touch + 4,
                child: Center(
                  child: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: c.blue,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
