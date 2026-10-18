import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/tile_icon.dart';
import '../../../data/models/alert_model.dart';

class AlertRow extends StatelessWidget {
  final TransitAlert alert;

  const AlertRow({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (icon, color) = switch (alert.type) {
      'delay' => (Icons.warning_amber_rounded, TileColor.orange),
      'diversion' => (Icons.alt_route_rounded, TileColor.blue),
      _ => (Icons.access_time_rounded, TileColor.green),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TileIcon(
            icon: icon,
            color: color,
            size: 40,
            iconSize: 20,
            solid: true,
            radius: 12,
          ),
          const SizedBox(width: Sp.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        alert.title,
                        style: MargText.headline.copyWith(color: c.label),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Sp.x2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (alert.isSample) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: c.fill,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Sample',
                              style: MargText.caption.copyWith(
                                color: c.label2,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          alert.timeAgo,
                          style: MargText.caption.copyWith(color: c.label2),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  alert.body,
                  style: MargText.footnote.copyWith(
                    color: c.label2,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
