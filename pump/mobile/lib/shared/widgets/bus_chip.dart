import 'package:flutter/material.dart';
import '../../theme/marg_tokens.dart';

class BusChip extends StatelessWidget {
  final String line;
  final bool showIcon;

  const BusChip({
    super.key,
    required this.line,
    this.showIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x2, vertical: Sp.x1 / 2),
      decoration: BoxDecoration(
        color: c.blue,
        borderRadius: BorderRadius.circular(Rad.sm / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Icon(Icons.directions_bus, size: 12, color: c.card),
            const SizedBox(width: Sp.x1),
          ],
          Text(
            line,
            style: MargText.caption.copyWith(
              color: c.card,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
