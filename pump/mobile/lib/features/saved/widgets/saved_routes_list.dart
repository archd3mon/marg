import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../data/models/saved_item.dart';
import 'saved_route_row.dart';

class SavedRoutesList extends StatelessWidget {
  final List<SavedRoute> routes;
  final void Function(SavedRoute) onRouteTap;
  final void Function(SavedRoute) onRouteDelete;

  const SavedRoutesList({
    super.key,
    required this.routes,
    required this.onRouteTap,
    required this.onRouteDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    if (routes.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x6),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(Rad.md),
          border: Border.all(color: c.separator, width: 0.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_outline_rounded, size: 36, color: c.label3),
              const SizedBox(height: Sp.x2),
              Text(
                'No saved routes',
                style: MargText.headline.copyWith(color: c.label),
              ),
              const SizedBox(height: Sp.x1),
              Text(
                'Saved routes will appear here for fast access.',
                style: MargText.footnote.copyWith(color: c.label2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: c.separator, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < routes.length; i++) ...[
            Dismissible(
              key: ValueKey(routes[i].id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: Sp.x5),
                color: c.red,
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
              ),
              onDismissed: (_) => onRouteDelete(routes[i]),
              child: SavedRouteRow(
                route: routes[i],
                onTap: () => onRouteTap(routes[i]),
              ),
            ),
            if (i < routes.length - 1)
              Divider(color: c.separator, height: 1, indent: Sp.x4),
          ],
        ],
      ),
    );
  }
}
