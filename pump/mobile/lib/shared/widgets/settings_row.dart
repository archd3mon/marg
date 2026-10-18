import 'package:flutter/material.dart';
import '../../theme/marg_tokens.dart';

class SettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Rad.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Layout.touch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x2),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: Sp.x3),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: MargText.body.copyWith(
                            color: c.label,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: MargText.caption.copyWith(color: c.label2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],

              ),
            ),
          ),
          if (showDivider)
            Divider(
              height: 1,
              thickness: 0.5,
              indent: leading != null ? 56 : Sp.x4,
              color: c.separator,
            ),
        ],
      ),
    );
  }
}
