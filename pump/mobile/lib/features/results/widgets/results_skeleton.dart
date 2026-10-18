import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';

class ResultsSkeleton extends StatefulWidget {
  const ResultsSkeleton({super.key});

  @override
  State<ResultsSkeleton> createState() => _ResultsSkeletonState();
}

class _ResultsSkeletonState extends State<ResultsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSkeletonCard(MargColors c) {
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.x3),
      padding: const EdgeInsets.all(Sp.x4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: c.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 76,
                height: 22,
                decoration: BoxDecoration(
                  color: c.fill,
                  borderRadius: BorderRadius.circular(Rad.sm),
                ),
              ),
              Container(
                width: 60,
                height: 26,
                decoration: BoxDecoration(
                  color: c.fill,
                  borderRadius: BorderRadius.circular(Rad.sm),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x3),
          Row(
            children: [
              Container(width: 44, height: 24, decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(7))),
              const SizedBox(width: Sp.x1),
              Icon(Icons.chevron_right, size: 14, color: c.separator),
              const SizedBox(width: Sp.x1),
              Container(width: 52, height: 24, decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(7))),
              const SizedBox(width: Sp.x1),
              Icon(Icons.chevron_right, size: 14, color: c.separator),
              const SizedBox(width: Sp.x1),
              Container(width: 52, height: 24, decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(7))),
              const SizedBox(width: Sp.x1),
              Icon(Icons.chevron_right, size: 14, color: c.separator),
              const SizedBox(width: Sp.x1),
              Container(width: 44, height: 24, decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(7))),
            ],
          ),
          const SizedBox(height: Sp.x3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(width: 140, height: 14, decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(4))),
              Container(width: 80, height: 14, decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return FadeTransition(
      opacity: _opacity,
      child: Column(
        children: [
          _buildSkeletonCard(c),
          _buildSkeletonCard(c),
          _buildSkeletonCard(c),
        ],
      ),
    );
  }
}
