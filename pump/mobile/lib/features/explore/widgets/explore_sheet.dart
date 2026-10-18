import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/stop.dart';
import '../../../theme/marg_tokens.dart';
import 'explore_shortcuts.dart';
import 'nearby_stops_list.dart';

class ExploreSheet extends StatelessWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onHomeTap;
  final VoidCallback onWorkTap;
  final VoidCallback onAddTap;
  final List<TransitStop> stops;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<TransitStop> onStopTap;

  const ExploreSheet({
    super.key,
    required this.onSearchTap,
    required this.onHomeTap,
    required this.onWorkTap,
    required this.onAddTap,
    required this.stops,
    required this.isLoading,
    this.errorMessage,
    required this.onRetry,
    required this.onStopTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return DraggableScrollableSheet(
      initialChildSize: Layout.snaps[1],
      minChildSize: Layout.snaps[0],
      maxChildSize: Layout.snaps[2],
      snap: true,
      snapSizes: Layout.snaps,
      builder: (context, scrollController) {
        final blurActive = Glass.isBlurActive(context);
        final sheetContent = Container(
          decoration: BoxDecoration(
            color: blurActive ? c.glass : c.card.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.sheet)),
            border: Border(
              top: BorderSide(color: c.separator, width: 0.5),
              left: BorderSide(color: c.separator, width: 0.5),
              right: BorderSide(color: c.separator, width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: c.label.withValues(alpha: 0.14),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
            children: [
              const SizedBox(height: Sp.x2),
              // Grabber handle
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: c.label3,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: Sp.x3),

              // "Where to?" Search Field
              Semantics(
                button: true,
                label: 'Where to? Tap to search destinations',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onSearchTap();
                    },
                    borderRadius: BorderRadius.circular(Rad.md),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: Sp.x3),
                      decoration: BoxDecoration(
                        color: c.fill,
                        borderRadius: BorderRadius.circular(Rad.md),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: c.label2, size: 20),
                          const SizedBox(width: Sp.x2),
                          Text(
                            'Where to?',
                            style: MargText.headline.copyWith(
                              color: c.label2,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Sp.x4),

              // Shortcuts (Home, Work, Add)
              ExploreShortcuts(
                onHomeTap: onHomeTap,
                onWorkTap: onWorkTap,
                onAddTap: onAddTap,
              ),
              const SizedBox(height: Sp.x4),

              // Nearby stops
              NearbyStopsList(
                stops: stops,
                isLoading: isLoading,
                errorMessage: errorMessage,
                onRetry: onRetry,
                onStopTap: onStopTap,
              ),
              const SizedBox(height: 90), // Bottom padding for tab bar
            ],
          ),
        );

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.sheet)),
          child: blurActive
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                  child: sheetContent,
                )
              : sheetContent,
        );
      },
    );
  }
}
