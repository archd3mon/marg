import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/app_state.dart';
import '../theme/marg_tokens.dart';

enum HealthGateStatus { checking, healthy, error }

class HealthGate extends ConsumerStatefulWidget {
  final Widget child;
  final List<Duration>? backoffDelays;

  const HealthGate({
    super.key,
    required this.child,
    this.backoffDelays,
  });

  static const List<Duration> defaultBackoff = [
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
  ];

  @override
  ConsumerState<HealthGate> createState() => _HealthGateState();
}

class _HealthGateState extends ConsumerState<HealthGate> {
  HealthGateStatus _status = HealthGateStatus.checking;

  @override
  void initState() {
    super.initState();
    _startHealthGate();
  }

  Future<void> _startHealthGate() async {
    setState(() {
      _status = HealthGateStatus.checking;
    });

    final repo = ref.read(transitRepositoryProvider);
    final initialHealthy = await repo.checkHealth();
    if (!mounted) return;
    if (initialHealthy) {
      setState(() => _status = HealthGateStatus.healthy);
      return;
    }

    final delays = widget.backoffDelays ?? HealthGate.defaultBackoff;
    for (final delay in delays) {
      await Future.delayed(delay);
      if (!mounted) return;

      final healthy = await repo.checkHealth();
      if (!mounted) return;
      if (healthy) {
        setState(() => _status = HealthGateStatus.healthy);
        return;
      }
    }

    if (mounted) {
      setState(() => _status = HealthGateStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_status == HealthGateStatus.healthy) {
      return widget.child;
    }

    final c = context.c;
    final isError = _status == HealthGateStatus.error;

    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x6),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(Rad.lg),
              border: Border.all(color: c.separator, width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isError ? c.tint(c.orange) : c.tint(c.blue),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_sync_rounded,
                    color: isError ? c.orange : c.blue,
                    size: 26,
                  ),
                ),
                const SizedBox(height: Sp.x3),
                Text(
                  'Waking up Marg…',
                  style: MargText.headline.copyWith(color: c.label),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Sp.x2),
                Text(
                  isError
                      ? 'Backend took too long to wake up. Please check your connection and retry.'
                      : 'Backend warming up (Render free tier). Routing engine will be ready shortly.',
                  style: MargText.footnote.copyWith(color: c.label2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Sp.x4),
                if (!isError)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.blue,
                    ),
                  )
                else
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _startHealthGate,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.blue,
                        foregroundColor: c.card,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Rad.md),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
