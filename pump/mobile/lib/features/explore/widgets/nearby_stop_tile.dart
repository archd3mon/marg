import 'package:flutter/material.dart';
import '../../../data/models/stop.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/bus_chip.dart';
import '../../../shared/widgets/tile_icon.dart';

class NearbyStopTile extends StatelessWidget {
  final TransitStop stop;
  final bool showDivider;
  final VoidCallback? onTap;

  const NearbyStopTile({
    super.key,
    required this.stop,
    this.showDivider = true,
    this.onTap,
  });

  String _formatDistance(int meters) {
    if (meters < 50) return 'Nearby';
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final distanceText = _formatDistance(stop.distanceMeters);
    final subtitle = stop.subtext.isNotEmpty ? '$distanceText · ${stop.subtext}' : distanceText;

    final routesSummary = stop.etas.isNotEmpty ? 'lines ${stop.etas.map((e) => e.route).join(", ")}' : '';
    return Semantics(
      button: true,
      label: '${stop.name}, $subtitle${routesSummary.isNotEmpty ? ", $routesSummary" : ""}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Rad.sm),
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  const TileIcon(
                    icon: Icons.directions_bus_rounded,
                    color: TileColor.blue,
                    size: 36,
                    iconSize: 18,
                    solid: true,
                    radius: 10,
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          style: MargText.headline.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.label,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: MargText.footnote.copyWith(
                            color: c.label2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Sp.x2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (stop.etas.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: stop.etas.take(3).map((eta) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: BusChip(line: eta.route),
                            );
                          }).toList(),
                        ),
                      if (stop.etas.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${stop.etas.first.mins} min',
                          style: MargText.footnote.copyWith(
                            color: c.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: c.separator,
                ),
              ),
          ],
        ),
      ),
    ),
  );
  }
}
