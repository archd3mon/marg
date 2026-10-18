import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/marg_tokens.dart';

enum MargTab {
  explore,
  saved,
  alerts,
}

class GlassTabBar extends StatelessWidget {
  final MargTab currentTab;
  final ValueChanged<MargTab> onTabSelected;

  const GlassTabBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final blurActive = Glass.isBlurActive(context);
    final bar = Container(
      decoration: BoxDecoration(
        color: blurActive ? c.glass : c.card.withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(color: c.separator, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TabItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Explore',
                isSelected: currentTab == MargTab.explore,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabSelected(MargTab.explore);
                },
              ),
              _TabItem(
                icon: Icons.bookmark_border_rounded,
                activeIcon: Icons.bookmark_rounded,
                label: 'Saved',
                isSelected: currentTab == MargTab.saved,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabSelected(MargTab.saved);
                },
              ),
              _TabItem(
                icon: Icons.notifications_none_rounded,
                activeIcon: Icons.notifications_rounded,
                label: 'Alerts',
                isSelected: currentTab == MargTab.alerts,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabSelected(MargTab.alerts);
                },
              ),
            ],
          ),
        ),
      ),
    );

    return ClipRect(
      child: blurActive
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: bar,
            )
          : bar,
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = isSelected ? c.blue : c.gray;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '$label tab',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(minHeight: Layout.touch),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: color,
                    size: 24,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: MargText.caption.copyWith(
                      color: color,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 10,
                    ),
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
