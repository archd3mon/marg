// Marg design tokens + theme + glass. Copy to pump/mobile/lib/theme/.
// Source of truth: design/tokens.json. Feature widgets must use ONLY these.
import 'dart:ui';
import 'package:flutter/material.dart';

class MargColors extends ThemeExtension<MargColors> {
  const MargColors({
    required this.blue, required this.green, required this.orange, required this.red,
    required this.purple, required this.gray, required this.bg, required this.card,
    required this.glass, required this.label, required this.label2, required this.label3,
    required this.separator, required this.fill,
  });
  final Color blue, green, orange, red, purple, gray, bg, card, glass, label, label2, label3, separator, fill;

  Color tint(Color c, [double a = .13]) => c.withValues(alpha: a);

  static const light = MargColors(
    blue: Color(0xFF007AFF), green: Color(0xFF34C759), orange: Color(0xFFFF9500), red: Color(0xFFFF3B30),
    purple: Color(0xFFAF52DE), gray: Color(0xFF8E8E93), bg: Color(0xFFF2F2F7), card: Color(0xFFFFFFFF),
    glass: Color(0xC7FFFFFF), label: Color(0xFF000000), label2: Color(0x993C3C43),
    label3: Color(0x4D3C3C43), separator: Color(0x243C3C43), fill: Color(0x1F767680),
  );
  static const dark = MargColors(
    blue: Color(0xFF0A84FF), green: Color(0xFF30D158), orange: Color(0xFFFF9F0A), red: Color(0xFFFF453A),
    purple: Color(0xFFBF5AF2), gray: Color(0xFF98989D), bg: Color(0xFF000000), card: Color(0xFF1C1C1E),
    glass: Color(0xB81C1C1E), label: Color(0xFFFFFFFF), label2: Color(0x99EBEBF5),
    label3: Color(0x4DEBEBF5), separator: Color(0x73545458), fill: Color(0x3D767680),
  );

  @override
  MargColors copyWith() => this;
  @override
  MargColors lerp(MargColors? o, double t) => t < .5 ? this : (o ?? this);
}

abstract final class Sp { static const double x1 = 4, x2 = 8, x3 = 12, x4 = 16, x5 = 20, x6 = 24, x8 = 32; }
abstract final class Rad { static const double sm = 10, md = 14, lg = 20, sheet = 28; }
abstract final class Motion {
  static const fast = Duration(milliseconds: 200);
  static const base = Duration(milliseconds: 300);
  static const sheet = Duration(milliseconds: 350);
  static const curve = Curves.easeOutCubic;
}
abstract final class Layout { static const double touch = 48; static const snaps = [0.14, 0.5, 0.92]; }

TextStyle _t(double s, double lh, FontWeight w, double ls) =>
    TextStyle(fontFamily: 'Inter', fontSize: s, height: lh / s, fontWeight: w, letterSpacing: ls * s,
        fontFeatures: const [FontFeature.tabularFigures()]);

abstract final class MargText {
  static final largeTitle = _t(34, 41, FontWeight.w700, -.025);
  static final title = _t(28, 34, FontWeight.w700, -.022);
  static final title3 = _t(20, 25, FontWeight.w600, -.018);
  static final headline = _t(17, 22, FontWeight.w600, -.014);
  static final body = _t(17, 22, FontWeight.w400, -.014);
  static final subhead = _t(15, 20, FontWeight.w400, -.010);
  static final footnote = _t(13, 18, FontWeight.w400, -.006);
  static final caption = _t(12, 16, FontWeight.w400, 0);
}

extension MargContext on BuildContext {
  MargColors get c =>
      Theme.of(this).extension<MargColors>() ??
      (Theme.of(this).brightness == Brightness.dark ? MargColors.dark : MargColors.light);
}

ThemeData margTheme(Brightness b) {
  final c = b == Brightness.light ? MargColors.light : MargColors.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: c.blue, brightness: b).copyWith(primary: c.blue, surface: c.card),
    splashFactory: NoSplash.splashFactory,           // Apple-style: no ripples
    highlightColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    }),
    extensions: [c],
  );
}

/// Liquid-glass surface. Falls back to a solid fill when [blur] is false (low-end devices / reduce-motion).
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = Rad.sheet, this.blur = true, this.topOnly = false});
  final Widget child; final double radius; final bool blur, topOnly;

  static bool forceDisableBlur = false;

  static bool isBlurActive(BuildContext context, [bool blur = true]) {
    if (!blur || forceDisableBlur) return false;
    return MediaQuery.maybeOf(context)?.disableAnimations != true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final active = isBlurActive(context, blur);
    final br = topOnly ? BorderRadius.vertical(top: Radius.circular(radius)) : BorderRadius.circular(radius);
    final deco = BoxDecoration(
      color: active ? c.glass : c.card.withValues(alpha: .94),
      borderRadius: br,
      border: Border.all(color: c.separator, width: .5),
      boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 40, offset: Offset(0, -10))],
    );
    final inner = DecoratedBox(decoration: deco, child: child);
    if (!active) return ClipRRect(borderRadius: br, child: inner);
    return ClipRRect(borderRadius: br, child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: inner));
  }
}
