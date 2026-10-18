import 'package:flutter/material.dart';
import '../../theme/marg_tokens.dart';

enum ButtonVariant {
  primary,
  tinted,
  danger,
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final ButtonVariant variant;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isEnabled = onPressed != null;

    final (bgColor, fgColor) = switch (variant) {
      ButtonVariant.primary => (isEnabled ? c.blue : c.fill, isEnabled ? c.card : c.label3),
      ButtonVariant.tinted => (c.tint(c.blue, 0.12), c.blue),
      ButtonVariant.danger => (c.tint(c.red, 0.12), c.red),
    };

    return SizedBox(
      width: width ?? double.infinity,
      height: Layout.touch + 2,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(Rad.md),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Rad.md),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: Sp.x2),
                ],
                Text(
                  label,
                  style: MargText.headline.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w600,
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
