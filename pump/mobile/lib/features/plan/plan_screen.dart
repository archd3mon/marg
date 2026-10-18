import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_state.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/segmented_control.dart';
import '../../theme/marg_tokens.dart';
import 'widgets/leave_time_row.dart';
import 'widgets/od_input_card.dart';
import 'widgets/place_search_sheet.dart';
import 'widgets/priority_chips.dart';
import 'widgets/recent_searches_list.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  String _travelMode = 'bus';

  void _swapPoints() {
    final state = ref.read(tripPlanStateProvider);
    ref.read(tripPlanStateProvider.notifier).setPlan(state.copyWith(
      from: state.to,
      to: state.from,
    ));
  }

  void _showPlaceSearch(bool isSelectingFrom) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlaceSearchSheet(
        isSelectingFrom: isSelectingFrom,
        onPlaceSelected: (place) {
          final s = ref.read(tripPlanStateProvider);
          if (isSelectingFrom) {
            ref.read(tripPlanStateProvider.notifier).setPlan(s.copyWith(from: place));
          } else {
            ref.read(tripPlanStateProvider.notifier).setPlan(s.copyWith(to: place));
          }
        },
        onPickOnMap: () {
          ref.read(mapPickTargetProvider.notifier).setTarget(
            isSelectingFrom ? MapPickTarget.origin : MapPickTarget.destination,
          );
          context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tripPlan = ref.watch(tripPlanStateProvider);
    final recents = ref.watch(storageServiceProvider).getRecentSearches();
    final canShowRoutes = tripPlan.from.name.isNotEmpty && tripPlan.to.name.isNotEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: Text(
            'Cancel',
            style: MargText.headline.copyWith(
              color: c.blue,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        title: Text(
          'Plan Trip',
          style: MargText.headline.copyWith(
            color: c.label,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                children: [
                  const SizedBox(height: Sp.x2),

                  // Origin / Destination Card
                  OdInputCard(
                    from: tripPlan.from,
                    to: tripPlan.to,
                    onFromTap: () => _showPlaceSearch(true),
                    onToTap: () => _showPlaceSearch(false),
                    onSwap: _swapPoints,
                  ),

                  const SizedBox(height: Sp.x3),

                  // Leave Row
                  LeaveTimeRow(
                    departureTime: tripPlan.departureTime,
                    onTimeChanged: (newTime) {
                      ref.read(tripPlanStateProvider.notifier).updatePlan(
                        (s) => s.copyWith(departureTime: newTime),
                      );
                    },
                  ),

                  const SizedBox(height: Sp.x4),

                  // Travel By
                  Text(
                    'TRAVEL BY',
                    style: MargText.footnote.copyWith(
                      color: c.label2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                  MargSegmentedControl<String>(
                    items: const [
                      SegmentItem(
                        value: 'bus',
                        title: 'Bus',
                        icon: Icon(Icons.directions_bus_rounded, size: 16),
                      ),
                      SegmentItem(
                        value: 'metro',
                        title: 'Metro',
                        icon: Icon(Icons.subway_rounded, size: 16),
                        badge: 'SOON',
                        disabled: true,
                      ),
                    ],
                    selectedValue: _travelMode,
                    onValueChanged: (val) {
                      setState(() => _travelMode = val);
                    },
                  ),

                  const SizedBox(height: Sp.x4),

                  // Prioritise
                  Text(
                    'PRIORITISE',
                    style: MargText.footnote.copyWith(
                      color: c.label2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: Sp.x2),
                  PriorityChips(
                    selectedPriority: tripPlan.priority,
                    onPriorityChanged: (priority) {
                      ref.read(tripPlanStateProvider.notifier).updatePlan(
                        (s) => s.copyWith(priority: priority),
                      );
                    },
                  ),

                  const SizedBox(height: Sp.x5),

                  // Recent
                  if (recents.isNotEmpty) ...[
                    Text(
                      'RECENT',
                      style: MargText.footnote.copyWith(
                        color: c.label2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: Sp.x2),
                    RecentSearchesList(
                      recents: recents,
                      onPlaceTap: (place) {
                        ref.read(tripPlanStateProvider.notifier).updatePlan(
                          (s) => s.copyWith(to: place),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: Sp.x4),
                ],
              ),
            ),

            // Show Routes Primary Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
              child: PrimaryButton(
                label: 'Show Routes',
                onPressed: canShowRoutes
                    ? () {
                        HapticFeedback.lightImpact();
                        context.push('/results');
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
