import 'package:flutter/material.dart';
import '../../../data/models/stop.dart';
import '../../../theme/marg_tokens.dart';
import '../../../shared/widgets/skeleton.dart';
import 'nearby_stop_tile.dart';

class NearbyStopsList extends StatelessWidget {
  final List<TransitStop> stops;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<TransitStop> onStopTap;

  const NearbyStopsList({
    super.key,
    required this.stops,
    required this.isLoading,
    this.errorMessage,
    required this.onRetry,
    required this.onStopTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nearby stops',
                style: MargText.title3.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.label,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'See All',
                  style: MargText.subhead.copyWith(
                    color: c.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Sp.x2),
        if (isLoading) ...[
          const _NearbyStopsSkeleton(),
        ] else if (errorMessage != null) ...[
          _ErrorState(message: errorMessage!, onRetry: onRetry),
        ] else if (stops.isEmpty) ...[
          const _EmptyState(),
        ] else ...[
          ...stops.take(6).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final stop = entry.value;
            final isLast = index == stops.take(6).length - 1;
            return NearbyStopTile(
              stop: stop,
              showDivider: !isLast,
              onTap: () => onStopTap(stop),
            );
          }),
        ],
      ],
    );
  }
}

class _NearbyStopsSkeleton extends StatelessWidget {
  const _NearbyStopsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Skeleton(width: 36, height: 36, borderRadius: 10),
              SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(width: 140, height: 16),
                    SizedBox(height: 6),
                    Skeleton(width: 90, height: 12),
                  ],
                ),
              ),
              SizedBox(width: Sp.x2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Skeleton(width: 48, height: 20, borderRadius: 6),
                  SizedBox(height: 6),
                  Skeleton(width: 36, height: 12),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.x5),
      child: Center(
        child: Column(
          children: [
            Text(
              message,
              style: MargText.subhead.copyWith(color: c.label2),
            ),
            const SizedBox(height: Sp.x2),
            TextButton(
              onPressed: onRetry,
              child: Text('Retry', style: MargText.headline.copyWith(color: c.blue)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.x6),
      child: Center(
        child: Text(
          'No bus stops found nearby',
          style: MargText.subhead.copyWith(color: c.label2),
        ),
      ),
    );
  }
}
