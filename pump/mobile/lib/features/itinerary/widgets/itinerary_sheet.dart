import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/badge_label.dart';
import '../models/itinerary_step_data.dart';
import 'itinerary_header.dart';
import 'itinerary_timeline_step.dart';
import 'itinerary_cta_bar.dart';

class ItinerarySheet extends StatefulWidget {
  final int totalTimeMins;
  final String arrivalTime;
  final int transfers;
  final int totalWalkM;
  final BadgeType badgeType;
  final List<ItineraryStepData> steps;
  final VoidCallback onStartTrip;
  final VoidCallback onToggleSave;
  final bool isSaved;

  const ItinerarySheet({
    super.key,
    required this.totalTimeMins,
    required this.arrivalTime,
    required this.transfers,
    required this.totalWalkM,
    this.badgeType = BadgeType.fastest,
    required this.steps,
    required this.onStartTrip,
    required this.onToggleSave,
    this.isSaved = false,
  });

  @override
  State<ItinerarySheet> createState() => _ItinerarySheetState();
}

class _ItinerarySheetState extends State<ItinerarySheet> {
  final Set<int> _expandedSteps = {};

  void _toggleStep(int index) {
    setState(() {
      if (_expandedSteps.contains(index)) {
        _expandedSteps.remove(index);
      } else {
        _expandedSteps.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      snap: true,
      builder: (context, scrollController) {
        return Glass(
          radius: Rad.sheet,
          topOnly: true,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: Sp.x5),
            children: [
              ItineraryHeader(
                totalTimeMins: widget.totalTimeMins,
                arrivalTime: widget.arrivalTime,
                transfers: widget.transfers,
                totalWalkM: widget.totalWalkM,
                badgeType: widget.badgeType,
              ),
              const SizedBox(height: Sp.x4),
              for (int i = 0; i < widget.steps.length; i++)
                ItineraryTimelineStep(
                  step: widget.steps[i],
                  isExpanded: _expandedSteps.contains(i),
                  onToggleExpand: () => _toggleStep(i),
                ),
              const SizedBox(height: Sp.x5),
              ItineraryCtaBar(
                onStartTrip: widget.onStartTrip,
                onToggleSave: widget.onToggleSave,
                isSaved: widget.isSaved,
              ),
              const SizedBox(height: Sp.x6),
            ],
          ),
        );
      },
    );
  }
}
