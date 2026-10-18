import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/marg_tokens.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/tile_icon.dart';
import '../../app/app_state.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: Sp.x6),
              // App Icon with Marg glyph
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.tint(c.blue, 0.8),
                      c.blue,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: c.tint(c.blue, 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _MargLogoPainter(cardColor: c.card, blueColor: c.blue),
                ),
              ),
              const SizedBox(height: Sp.x5),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Welcome to\n',
                      style: MargText.largeTitle.copyWith(color: c.label),
                    ),
                    TextSpan(
                      text: 'Marg',
                      style: MargText.largeTitle.copyWith(color: c.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Sp.x2),
              Text(
                "Pune's buses, planned beautifully.",
                style: MargText.body.copyWith(color: c.label2),
              ),
              const SizedBox(height: Sp.x6),
              // Feature 1
              const _FeatureRow(
                icon: Icons.alt_route_rounded,
                color: TileColor.blue,
                title: 'Plan with confidence',
                description: 'Ranked routes with arrival times, transfers and walking at a glance.',
              ),
              const SizedBox(height: Sp.x5),
              // Feature 2
              const _FeatureRow(
                icon: Icons.access_time_rounded,
                color: TileColor.green,
                title: 'Know when it arrives',
                description: 'Live bus positions and calm alerts when something changes.',
              ),
              const SizedBox(height: Sp.x5),
              // Feature 3
              const _FeatureRow(
                icon: Icons.location_on_rounded,
                color: TileColor.orange,
                title: 'Made for Pune',
                description: 'Covers the PMPML bus network. Metro joins in a future update.',
              ),
              const Spacer(),
              Center(
                child: Text(
                  'Location is used only to find stops near you.',
                  style: MargText.footnote.copyWith(color: c.label3),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Sp.x3),
              PrimaryButton(
                label: 'Continue',
                onPressed: () async {
                  try {
                    final permission = await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      await Geolocator.requestPermission();
                    }
                  } catch (_) {}

                  await ref.read(storageServiceProvider).setHasSeenOnboarding(true);
                  if (context.mounted) {
                    context.go('/explore');
                  }
                },
              ),
              const SizedBox(height: Sp.x4),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final TileColor color;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TileIcon(icon: icon, color: color, size: 44, iconSize: 22, solid: true, radius: 12),
        const SizedBox(width: Sp.x4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MargText.headline.copyWith(color: c.label),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: MargText.subhead.copyWith(color: c.label2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MargLogoPainter extends CustomPainter {
  final Color cardColor;
  final Color blueColor;

  _MargLogoPainter({required this.cardColor, required this.blueColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = cardColor
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.72);
    path.cubicTo(
      size.width * 0.3, size.height * 0.45,
      size.width * 0.7, size.height * 0.55,
      size.width * 0.7, size.height * 0.28,
    );
    canvas.drawPath(path, paintLine);

    final dotOuter = Paint()..color = cardColor..style = PaintingStyle.fill;
    final dotInner = Paint()..color = blueColor..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.72), 8, dotOuter);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.72), 3.5, dotInner);

    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.28), 8, dotOuter);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
