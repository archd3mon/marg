import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/marg_tokens.dart';

class PriorityChips extends StatelessWidget {
  final String selectedPriority;
  final ValueChanged<String> onPriorityChanged;

  const PriorityChips({
    super.key,
    required this.selectedPriority,
    required this.onPriorityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Sp.x2,
      runSpacing: Sp.x2,
      children: [
        _PriorityFilterChip(
          title: 'Fastest',
          icon: Icons.bolt,
          isSelected: selectedPriority == 'fastest',
          onTap: () {
            HapticFeedback.selectionClick();
            onPriorityChanged('fastest');
          },
        ),
        _PriorityFilterChip(
          title: 'Fewer transfers',
          isSelected: selectedPriority == 'least_transfers',
          onTap: () {
            HapticFeedback.selectionClick();
            onPriorityChanged('least_transfers');
          },
        ),
        _PriorityFilterChip(
          title: 'Less walking',
          isSelected: selectedPriority == 'least_walking',
          onTap: () {
            HapticFeedback.selectionClick();
            onPriorityChanged('least_walking');
          },
        ),
      ],
    );
  }
}

class _PriorityFilterChip extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityFilterChip({
    required this.title,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title priority',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(horizontal: Sp.x3 + 2, vertical: Sp.x2),
          decoration: BoxDecoration(
            color: isSelected ? c.blue : c.card,
            borderRadius: BorderRadius.circular(Rad.lg),
            border: Border.all(
              color: isSelected ? c.blue : c.separator,
              width: 0.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: c.tint(c.blue, 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? c.card : c.label2,
                ),
                const SizedBox(width: Sp.x1),
              ],
              Text(
                title,
                style: MargText.subhead.copyWith(
                  color: isSelected ? c.card : c.label,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
