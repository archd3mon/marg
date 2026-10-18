import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/bus_chip.dart';
import '../models/itinerary_step_data.dart';
import 'itinerary_timeline_rail.dart';
import 'intermediate_stops_list.dart';

class ItineraryTimelineStep extends StatelessWidget {
  final ItineraryStepData step;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  const ItineraryTimelineStep({
    super.key,
    required this.step,
    this.isExpanded = false,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return CustomPaint(
      painter: TimelineRailPainter(
        isWalk: step.isWalk,
        isAlight: step.isAlight,
        isDestination: step.isDestination,
        blueColor: c.blue,
        grayColor: c.gray,
        redColor: c.red,
        cardColor: c.card,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: step.isDestination ? 0 : (step.isWalk ? 12 : 18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Time Column (58dp, right aligned)
            SizedBox(
              width: 58,
              child: Padding(
                padding: const EdgeInsets.only(top: 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      step.time,
                      style: MargText.subhead.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.label,
                      ),
                    ),
                    if (step.depTime != null)
                      Text(
                        step.depTime!,
                        style: MargText.caption.copyWith(
                          color: c.label2,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Rail spacing placeholder (8dp + 26dp rail + 8dp = 42dp)
            const SizedBox(width: Sp.x2 + 26.0 + Sp.x2),

            // 2. Body Column
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: MargText.headline.copyWith(color: c.label)),
                  if (step.isWalk && step.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.directions_walk, size: 15, color: c.label2),
                        const SizedBox(width: Sp.x1),
                        Text(step.subtitle!, style: MargText.footnote.copyWith(color: c.label2)),
                      ],
                    ),
                  ],
                  if (!step.isWalk && step.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(step.subtitle!, style: MargText.footnote.copyWith(color: c.label2)),
                  ],
                  if (step.busLine != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        BusChip(
                          line: step.busLine!,
                          suffix: step.lineSuffix,
                          showIcon: true,
                        ),
                        const SizedBox(width: Sp.x2),
                        if (step.headsign != null)
                          Expanded(
                            child: Text(
                              step.headsign!,
                              style: MargText.subhead.copyWith(color: c.label),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (step.meta != null) ...[
                    const SizedBox(height: 3),
                    Text(step.meta!, style: MargText.footnote.copyWith(color: c.label2)),
                  ],
                  if (step.intermediateStops.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Semantics(
                      button: true,
                      label: '${isExpanded ? "Hide" : "Show"} ${step.intermediateStops.length} intermediate stops',
                      child: InkWell(
                        onTap: onToggleExpand,
                        borderRadius: BorderRadius.circular(Rad.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isExpanded ? 'Hide stops' : 'Show stops',
                                style: MargText.footnote.copyWith(
                                  color: c.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 16,
                                color: c.blue,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      clipBehavior: Clip.hardEdge,
                      alignment: Alignment.topCenter,
                      child: isExpanded
                          ? IntermediateStopsList(stops: step.intermediateStops)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
