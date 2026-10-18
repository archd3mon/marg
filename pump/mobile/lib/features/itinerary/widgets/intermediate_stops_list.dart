import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';

class IntermediateStopsList extends StatelessWidget {
  final List<String> stops;

  const IntermediateStopsList({super.key, required this.stops});

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Padding(
      padding: const EdgeInsets.only(top: Sp.x2, left: Sp.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: stops.map((stop) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.label3,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Sp.x2),
                Text(
                  stop,
                  style: MargText.footnote.copyWith(color: c.label2),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
