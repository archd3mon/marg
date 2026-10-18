import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/bus_chip.dart';
import '../../../shared/widgets/walk_chip.dart';
import '../../../shared/widgets/badge_label.dart';
import '../../../data/models/route_model.dart';

class RouteCard extends StatelessWidget {
  final TransitRoute route;
  final bool isSelected;
  final VoidCallback onTap;

  const RouteCard({
    super.key,
    required this.route,
    required this.isSelected,
    required this.onTap,
  });

  BadgeType? _getBadgeType(String routeType) => switch (routeType) {
    'fastest' || 'recommended' => BadgeType.fastest,
    'least_transfers' => BadgeType.fewerTransfers,
    'least_walking' => BadgeType.lessWalking,
    _ => null,
  };

  String _formatArrivalTime(String depTime, int durationMins) {
    try {
      int h = 8, m = 42;
      final clean = depTime.replaceAll('Now ·', '').trim();
      final match = RegExp(r'(\d+):(\d+)').firstMatch(clean);
      if (match != null) {
        h = int.parse(match.group(1)!);
        m = int.parse(match.group(2)!);
        if (clean.toLowerCase().contains('pm') && h < 12) h += 12;
      }
      final total = h * 60 + m + durationMins;
      final arrH24 = (total ~/ 60) % 24;
      final arrM = (total % 60).toString().padLeft(2, '0');
      final period = arrH24 >= 12 ? 'PM' : 'AM';
      final arrH12 = arrH24 % 12 == 0 ? 12 : arrH24 % 12;
      return '$arrH12:$arrM $period';
    } catch (_) {
      return '9:37 AM';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final badgeType = _getBadgeType(route.routeType);
    final arrivalTime = _formatArrivalTime(route.departureTimeUsed, route.totalTimeMins);
    final displayLegs = collapseLegs(route.legs);

    return Container(
      margin: const EdgeInsets.only(bottom: Sp.x3),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: isSelected ? c.blue : c.separator, width: isSelected ? 2.0 : 0.5),
        boxShadow: isSelected
            ? [BoxShadow(color: c.tint(c.blue, 0.28), blurRadius: 20, offset: const Offset(0, 8))]
            : [BoxShadow(color: c.label.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: 'Route option, ${route.totalTimeMins} minutes, arrives $arrivalTime, ${route.transfers == 0 ? "Direct" : "${route.transfers} transfer"}${route.legs.any((l) => l.line != null) ? ", via lines ${route.legs.where((l) => l.line != null).map((l) => l.line!).join(", ")}" : ""}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Rad.lg),
            child: Padding(
              padding: const EdgeInsets.all(Sp.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (badgeType != null) BadgeLabel(type: badgeType) else const SizedBox.shrink(),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: '${route.totalTimeMins}', style: MargText.title.copyWith(color: c.label, fontWeight: FontWeight.w700, fontSize: 28)),
                          TextSpan(text: ' min', style: MargText.subhead.copyWith(color: c.label, fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.x3),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < displayLegs.length; i++) ...[
                        if (displayLegs[i].mode == 'walk')
                          WalkChip(durationMins: displayLegs[i].durationMins)
                        else if (displayLegs[i].mode == 'bus')
                          BusChip(line: displayLegs[i].line ?? 'Bus', showIcon: true)
                        else if (displayLegs[i].mode == 'metro')
                          BusChip(line: displayLegs[i].line ?? 'Metro', showIcon: true),
                        if (i < displayLegs.length - 1)
                          Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.x1), child: Icon(Icons.chevron_right, size: 14, color: c.label3)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Sp.x3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      route.transfers == 0 ? 'Arrive $arrivalTime · Direct' : 'Arrive $arrivalTime · ${route.transfers} transfer',
                      style: MargText.footnote.copyWith(color: c.label2),
                    ),
                    if (route.nextBusMins != null)
                      Text('Next bus in ${route.nextBusMins} min', style: MargText.footnote.copyWith(color: c.green, fontWeight: FontWeight.w600))
                    else
                      Text('${route.totalWalkM} m walk', style: MargText.footnote.copyWith(color: c.label2)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
