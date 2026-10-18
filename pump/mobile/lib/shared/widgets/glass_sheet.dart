import 'package:flutter/material.dart';
import '../../theme/marg_tokens.dart';

class GlassSheet extends StatelessWidget {
  final Widget child;
  final bool showHandle;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? maxHeight;
  final bool blur;

  const GlassSheet({
    super.key,
    required this.child,
    this.showHandle = true,
    this.padding,
    this.height,
    this.maxHeight,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Glass(
      topOnly: true,
      radius: Rad.sheet,
      blur: blur,
      child: Container(
        height: height,
        constraints: maxHeight != null ? BoxConstraints(maxHeight: maxHeight!) : null,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: Sp.x3),
                  decoration: BoxDecoration(
                    color: c.separator,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ],
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
