import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generate launcher png icons', () async {
    final densities = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };

    Future<void> renderAndSave(double size, bool isRound, String outputPath) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

      // Background Gradient
      final gradient = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(size, size),
        [const Color(0xFF3395FF), const Color(0xFF0066E6)],
      );
      final bgPaint = Paint()..shader = gradient..isAntiAlias = true;

      final rect = Rect.fromLTWH(0, 0, size, size);
      if (isRound) {
        canvas.drawCircle(Offset(size / 2, size / 2), size / 2, bgPaint);
      } else {
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size * 0.24));
        canvas.drawRRect(rrect, bgPaint);
      }

      // Route spline and nodes
      final scale = size / 88.0;
      final linePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 6.0 * scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      final path = Path();
      path.moveTo(size * 0.3, size * 0.72);
      path.cubicTo(
        size * 0.3, size * 0.45,
        size * 0.7, size * 0.55,
        size * 0.7, size * 0.28,
      );
      canvas.drawPath(path, linePaint);

      final outerDot = Paint()..color = Colors.white..style = PaintingStyle.fill..isAntiAlias = true;
      final innerDot = Paint()..color = const Color(0xFF0066E6)..style = PaintingStyle.fill..isAntiAlias = true;

      // Start circle
      canvas.drawCircle(Offset(size * 0.3, size * 0.72), 8.0 * scale, outerDot);
      canvas.drawCircle(Offset(size * 0.3, size * 0.72), 3.5 * scale, innerDot);

      // End circle
      canvas.drawCircle(Offset(size * 0.7, size * 0.28), 8.0 * scale, outerDot);

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final file = File(outputPath);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
    }

    for (final entry in densities.entries) {
      final name = entry.key;
      final s = entry.value.toDouble();
      await renderAndSave(s, false, 'android/app/src/main/res/mipmap-$name/ic_launcher.png');
      await renderAndSave(s, true, 'android/app/src/main/res/mipmap-$name/ic_launcher_round.png');
    }

    // Play store 512x512 icon
    await renderAndSave(512, false, 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_512.png');
    await renderAndSave(512, false, 'assets/icon/app_icon_512.png');
  });
}
