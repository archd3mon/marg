import 'package:flutter/material.dart';
import '../../theme/marg_tokens.dart';

class SegmentItem<T> {
  final T value;
  final String title;
  final Widget? icon;
  final String? badge;
  final bool disabled;

  const SegmentItem({
    required this.value,
    required this.title,
    this.icon,
    this.badge,
    this.disabled = false,
  });
}

class MargSegmentedControl<T> extends StatelessWidget {
  final List<SegmentItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;

  const MargSegmentedControl({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(Rad.sm),
      ),
      child: Row(
        children: items.map((item) {
          final isSelected = item.value == selectedValue;
          return Expanded(
            child: GestureDetector(
              onTap: item.disabled ? null : () => onValueChanged(item.value),
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.symmetric(vertical: Sp.x2),
                decoration: BoxDecoration(
                  color: isSelected ? c.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(Rad.sm - 2),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: c.label.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      item.icon!,
                      const SizedBox(width: Sp.x1),
                    ],
                    Text(
                      item.title,
                      style: MargText.subhead.copyWith(
                        color: item.disabled
                            ? c.label3
                            : isSelected
                                ? c.label
                                : c.label2,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (item.badge != null) ...[
                      const SizedBox(width: Sp.x1),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Sp.x1 + 1, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.tint(c.purple, 0.16),
                          borderRadius: BorderRadius.circular(Rad.sm / 2),
                        ),
                        child: Text(
                          item.badge!,
                          style: MargText.caption.copyWith(
                            color: c.purple,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

typedef Segmented<T> = MargSegmentedControl<T>;

