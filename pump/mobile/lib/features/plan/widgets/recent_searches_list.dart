import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/place.dart';
import '../../../shared/widgets/tile_icon.dart';
import '../../../theme/marg_tokens.dart';

class RecentSearchesList extends StatelessWidget {
  final List<Place> recents;
  final ValueChanged<Place> onPlaceTap;

  const RecentSearchesList({
    super.key,
    required this.recents,
    required this.onPlaceTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (recents.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: c.separator, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < recents.length; i++) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPlaceTap(recents[i]);
                },
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(Rad.md) : Radius.zero,
                  bottom: i == recents.length - 1 ? const Radius.circular(Rad.md) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x3),
                  child: Row(
                    children: [
                      const TileIcon(
                        icon: Icons.access_time_rounded,
                        color: TileColor.gray,
                        size: 32,
                        iconSize: 16,
                      ),
                      const SizedBox(width: Sp.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recents[i].name,
                              style: MargText.body.copyWith(
                                color: c.label,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              recents[i].displayName,
                              style: MargText.caption.copyWith(color: c.label2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i < recents.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Divider(color: c.separator, height: 0.5, thickness: 0.5),
              ),
          ],
        ],
      ),
    );
  }
}
