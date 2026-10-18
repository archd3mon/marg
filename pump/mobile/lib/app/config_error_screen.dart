import 'package:flutter/material.dart';
import '../theme/marg_tokens.dart';

class ConfigErrorScreen extends StatelessWidget {
  final String message;

  const ConfigErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Sp.x5, vertical: Sp.x6),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(Rad.lg),
                border: Border.all(color: c.separator, width: 0.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: c.tint(c.red),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: c.red,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: Sp.x4),
                  Text(
                    'Configuration Error',
                    style: MargText.headline.copyWith(color: c.label),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Sp.x3),
                  Text(
                    message,
                    style: MargText.subhead.copyWith(color: c.label2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Sp.x5),
                  Container(
                    padding: const EdgeInsets.all(Sp.x3),
                    decoration: BoxDecoration(
                      color: c.fill,
                      borderRadius: BorderRadius.circular(Rad.md),
                    ),
                    child: Text(
                      'flutter run --release \\\n  --dart-define=API_BASE=https://api.marg.in/api/v1',
                      style: MargText.caption.copyWith(
                        color: c.label,
                        fontFamily: 'Inter',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
