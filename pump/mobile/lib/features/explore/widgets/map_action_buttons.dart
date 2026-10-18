import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/marg_tokens.dart';

class MapActionButtons extends StatelessWidget {
  final VoidCallback onLocateMe;
  final VoidCallback onToggleLayers;

  const MapActionButtons({
    super.key,
    required this.onLocateMe,
    required this.onToggleLayers,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final blurActive = Glass.isBlurActive(context);
    final buttonBox = Container(
      decoration: BoxDecoration(
        color: blurActive ? c.glass : c.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: c.separator, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: c.label.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: Icons.near_me_rounded,
            tooltip: 'My Location',
            onPressed: () {
              HapticFeedback.selectionClick();
              onLocateMe();
            },
          ),
          Container(
            width: 44,
            height: 0.5,
            color: c.separator,
          ),
          _ActionButton(
            icon: Icons.layers_outlined,
            tooltip: 'Map Layers',
            onPressed: () {
              HapticFeedback.selectionClick();
              onToggleLayers();
            },
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(Rad.md),
      child: blurActive
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: buttonBox,
            )
          : buttonBox,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            constraints: const BoxConstraints(
              minWidth: Layout.touch,
              minHeight: Layout.touch,
            ),
            child: Icon(
              icon,
              color: c.blue,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
