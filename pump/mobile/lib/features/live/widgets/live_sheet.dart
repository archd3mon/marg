import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import 'live_stats_row.dart';
import 'live_progress_track.dart';

class LiveSheet extends StatelessWidget {
  final int remainingMins;
  final String arrivalTime;
  final String routeLine;
  final String statusText;
  final double progressPercent;
  final VoidCallback onShareEta;
  final VoidCallback onEndTrip;

  const LiveSheet({
    super.key,
    required this.remainingMins,
    required this.arrivalTime,
    required this.routeLine,
    required this.statusText,
    required this.progressPercent,
    required this.onShareEta,
    required this.onEndTrip,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Glass(
      radius: Rad.sheet,
      topOnly: true,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, Sp.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grabber handle
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: c.label3,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: Sp.x3),

              // Stats Row (Remaining, Arrival, On time)
              LiveStatsRow(
                remainingMins: remainingMins,
                arrivalTime: arrivalTime,
                routeLine: routeLine,
                statusText: statusText,
              ),
              const SizedBox(height: Sp.x3),

              // Progress Track
              LiveProgressTrack(
                progressPercent: progressPercent,
              ),
              const SizedBox(height: Sp.x4),

              // Action buttons (Share ETA + End Trip)
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Share ETA',
                      variant: ButtonVariant.tinted,
                      onPressed: onShareEta,
                    ),
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: PrimaryButton(
                      label: 'End Trip',
                      variant: ButtonVariant.danger,
                      onPressed: onEndTrip,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
