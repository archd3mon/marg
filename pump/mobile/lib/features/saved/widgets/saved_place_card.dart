import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/tile_icon.dart';
import '../../../data/models/saved_item.dart';

class SavedPlaceCard extends StatelessWidget {
  final SavedPlace place;
  final IconData icon;
  final TileColor color;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const SavedPlaceCard({
    super.key,
    required this.place,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Semantics(
      button: true,
      label: '${place.name}, ${place.locationName}',
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(Rad.lg),
        child: InkWell(
          onTap: onTap,
          onLongPress: onEdit,
          borderRadius: BorderRadius.circular(Rad.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 116),
            padding: const EdgeInsets.symmetric(horizontal: Sp.x3 + 2, vertical: Sp.x3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rad.lg),
              border: Border.all(color: c.separator, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TileIcon(
                  icon: icon,
                  color: color,
                  size: 40,
                  iconSize: 20,
                  isCircle: true,
                  solid: true,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      place.name,
                      style: MargText.headline.copyWith(color: c.label),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.locationName,
                      style: MargText.footnote.copyWith(color: c.label2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
