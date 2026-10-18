import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/bus_chip.dart';
import '../../../data/models/saved_item.dart';

class SavedRouteRow extends StatelessWidget {
  final SavedRoute route;
  final VoidCallback onTap;

  const SavedRouteRow({
    super.key,
    required this.route,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Semantics(
      button: true,
      label: '${route.title}, ${route.totalTimeMins} minutes, ${route.statusText}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3 + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        route.title,
                        style: MargText.headline.copyWith(color: c.label),
                      ),
                      const SizedBox(height: Sp.x1),
                      Row(
                        children: [
                          for (int i = 0; i < route.busLines.length; i++) ...[
                            BusChip(line: route.busLines[i]),
                            if (i < route.busLines.length - 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: Sp.x1 / 2),
                                child: Icon(Icons.chevron_right, size: 12, color: c.label3),
                              ),
                          ],
                          const SizedBox(width: Sp.x2),
                          Flexible(
                            child: Text(
                              route.scheduleText,
                              style: MargText.footnote.copyWith(color: c.label2),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.x2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${route.totalTimeMins}',
                          style: MargText.headline.copyWith(
                            color: c.label,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          ' min',
                          style: MargText.footnote.copyWith(
                            color: c.label2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      route.statusText,
                      style: MargText.footnote.copyWith(
                        color: route.isOnTime ? c.green : c.label2,
                        fontWeight: route.isOnTime ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
