import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/place.dart';
import '../../../theme/marg_tokens.dart';

class OdInputCard extends StatelessWidget {
  final Place? from;
  final Place? to;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback onSwap;

  const OdInputCard({
    super.key,
    required this.from,
    required this.to,
    required this.onFromTap,
    required this.onToTap,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isFromCurrentLocation = from?.name == 'Current Location';

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: c.separator, width: 0.5),
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // Dotted connector line
          Positioned(
            left: 21,
            top: 26,
            bottom: 26,
            child: SizedBox(
              width: 2,
              child: CustomPaint(
                painter: _DottedLinePainter(color: c.label3),
              ),
            ),
          ),

          // Origin and Destination fields
          Column(
            children: [
              // From Field
              Semantics(
                button: true,
                label: 'Origin: ${from?.name.isNotEmpty == true ? from!.name : "Choose starting point"}',
                child: InkWell(
                  onTap: onFromTap,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.lg)),
                  child: Padding(
                    padding: const EdgeInsets.only(left: Sp.x4, right: 60, top: Sp.x3, bottom: Sp.x3),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: c.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.blue, width: 3),
                          ),
                        ),
                        const SizedBox(width: Sp.x3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From',
                                style: MargText.caption.copyWith(
                                  color: c.label3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                from?.name.isNotEmpty == true ? from!.name : 'Choose starting point',
                                style: MargText.body.copyWith(
                                  color: isFromCurrentLocation ? c.blue : (from != null ? c.label : c.label3),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Divider between From and To
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Divider(color: c.separator, height: 0.5, thickness: 0.5),
              ),

              // To Field
              Semantics(
                button: true,
                label: 'Destination: ${to?.name.isNotEmpty == true ? to!.name : "Search destination"}',
                child: InkWell(
                  onTap: onToTap,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Rad.lg)),
                  child: Padding(
                    padding: const EdgeInsets.only(left: Sp.x4, right: 60, top: Sp.x3, bottom: Sp.x3),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: c.red, size: 14),
                        const SizedBox(width: Sp.x3 - 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'To',
                                style: MargText.caption.copyWith(
                                  color: c.label3,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                to?.name.isNotEmpty == true ? to!.name : 'Search destination',
                                style: MargText.body.copyWith(
                                  color: to != null && to!.name.isNotEmpty ? c.label : c.label3,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Swap button
          Positioned(
            right: Sp.x3,
            child: Semantics(
              button: true,
              label: 'Swap origin and destination',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSwap();
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.fill,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.swap_vert_rounded,
                      color: c.blue,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;

  const _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dotRadius = 1.0;
    const dotSpacing = 4.0;
    double currentY = 0;

    while (currentY < size.height) {
      canvas.drawCircle(Offset(size.width / 2, currentY), dotRadius, paint);
      currentY += dotSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) => oldDelegate.color != color;
}
