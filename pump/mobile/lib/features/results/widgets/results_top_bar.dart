import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/marg_tokens.dart';
import '../../../data/models/place.dart';

class ResultsTopBar extends StatelessWidget {
  final Place from;
  final Place to;

  const ResultsTopBar({
    super.key,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x2),
        child: Row(
          children: [
            // Circular Glass Back Button
            SizedBox(
              width: 44,
              height: 44,
              child: Glass(
                radius: 22,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.blue, size: 18),
                  onPressed: () => context.pop(),
                  tooltip: 'Back to plan',
                ),
              ),
            ),
            const SizedBox(width: Sp.x3),

            // Origin > Destination Pill
            Expanded(
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Glass(
                  radius: 22,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            from.name,
                            overflow: TextOverflow.ellipsis,
                            style: MargText.subhead.copyWith(
                              color: c.label,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Sp.x2),
                          child: Icon(Icons.chevron_right, size: 16, color: c.label2),
                        ),
                        Flexible(
                          child: Text(
                            to.name,
                            overflow: TextOverflow.ellipsis,
                            style: MargText.subhead.copyWith(
                              color: c.label,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
