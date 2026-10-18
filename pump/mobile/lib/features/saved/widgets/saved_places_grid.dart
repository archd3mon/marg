import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/tile_icon.dart';
import '../../../data/models/saved_item.dart';
import 'saved_place_card.dart';
import 'edit_place_sheet.dart';

class SavedPlacesGrid extends StatelessWidget {
  final List<SavedPlace> places;
  final void Function(SavedPlace) onPlaceTap;

  const SavedPlacesGrid({
    super.key,
    required this.places,
    required this.onPlaceTap,
  });

  @override
  Widget build(BuildContext context) {
    final homePlace = places.firstWhere(
      (p) => p.type == 'home',
      orElse: () => const SavedPlace(
        id: 'home',
        name: 'Home',
        locationName: 'Kothrud',
        lat: 18.5074,
        lng: 73.8077,
        type: 'home',
      ),
    );

    final workPlace = places.firstWhere(
      (p) => p.type == 'work',
      orElse: () => const SavedPlace(
        id: 'work',
        name: 'Work',
        locationName: 'Viman Nagar',
        lat: 18.5679,
        lng: 73.9143,
        type: 'work',
      ),
    );

    return Row(
      children: [
        Expanded(
          child: SavedPlaceCard(
            place: homePlace,
            icon: Icons.home_rounded,
            color: TileColor.blue,
            onTap: () => onPlaceTap(homePlace),
            onEdit: () => EditPlaceSheet.show(context, homePlace),
          ),
        ),
        const SizedBox(width: Sp.x3),
        Expanded(
          child: SavedPlaceCard(
            place: workPlace,
            icon: Icons.work_rounded,
            color: TileColor.orange,
            onTap: () => onPlaceTap(workPlace),
            onEdit: () => EditPlaceSheet.show(context, workPlace),
          ),
        ),
      ],
    );
  }
}
