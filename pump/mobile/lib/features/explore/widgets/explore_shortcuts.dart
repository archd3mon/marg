import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/tile_icon.dart';

class ExploreShortcuts extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onWorkTap;
  final VoidCallback onAddTap;

  const ExploreShortcuts({
    super.key,
    required this.onHomeTap,
    required this.onWorkTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ShortcutItem(
          label: 'Home',
          icon: Icons.home_rounded,
          color: TileColor.blue,
          solid: true,
          onTap: onHomeTap,
        ),
        _ShortcutItem(
          label: 'Work',
          icon: Icons.work_rounded,
          color: TileColor.orange,
          solid: true,
          onTap: onWorkTap,
        ),
        _ShortcutItem(
          label: 'Add',
          icon: Icons.add_rounded,
          color: TileColor.gray,
          solid: true,
          onTap: onAddTap,
        ),
      ],
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final TileColor color;
  final bool solid;
  final VoidCallback onTap;

  const _ShortcutItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.solid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Semantics(
      button: true,
      label: '$label shortcut',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(26),
          child: Container(
            constraints: const BoxConstraints(minWidth: Layout.touch, minHeight: Layout.touch),
            padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TileIcon(
                icon: icon,
                color: color,
                size: 52,
                iconSize: 24,
                solid: solid,
                isCircle: true,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: MargText.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: c.label,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
