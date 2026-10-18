import 'package:flutter/material.dart';
import '../../theme/marg_tokens.dart';

class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShapeBorder? shape;

  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = Rad.sm,
    this.shape,
  });

  const Skeleton.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = size / 2,
        shape = const CircleBorder();

  const Skeleton.card({
    super.key,
    this.width,
    this.height = 80,
    this.borderRadius = Rad.md,
    this.shape,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: widget.shape != null
              ? ShapeDecoration(
                  shape: widget.shape!,
                  color: c.fill.withValues(alpha: c.fill.a * _animation.value),
                )
              : BoxDecoration(
                  color: c.fill.withValues(alpha: c.fill.a * _animation.value),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
        );
      },
    );
  }
}
