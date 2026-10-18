import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import '../../../data/api_client.dart';

class ResultsErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const ResultsErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isColdStart = error is ApiUnavailableException || error is ApiTimeoutException;
    final isOffline = error is ApiOfflineException;

    final IconData icon = isColdStart
        ? Icons.cloud_sync_rounded
        : isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded;

    final String title = isColdStart
        ? 'Waking up Marg…'
        : isOffline ? 'No internet connection' : 'Unable to load routes';

    final String message = isColdStart
        ? 'Backend warming up (Render free tier). Routing engine will be ready shortly.'
        : isOffline
            ? 'Please check your internet connection and try again.'
            : 'An unexpected error occurred while searching for routes.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x6),
      margin: const EdgeInsets.only(bottom: Sp.x4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: c.separator, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isColdStart ? c.tint(c.blue) : c.tint(c.orange),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isColdStart ? c.blue : c.orange, size: 24),
          ),
          const SizedBox(height: Sp.x3),
          Text(title, style: MargText.headline.copyWith(color: c.label), textAlign: TextAlign.center),
          const SizedBox(height: Sp.x1),
          Text(message, style: MargText.footnote.copyWith(color: c.label2), textAlign: TextAlign.center),
          const SizedBox(height: Sp.x4),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.blue,
                foregroundColor: c.card,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
