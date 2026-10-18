import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marg_app/theme/marg_tokens.dart';
import 'package:marg_app/shared/widgets/shared_widgets.dart';

Widget _wrap(Widget child, Brightness brightness) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: margTheme(brightness),
    home: Scaffold(
      backgroundColor: brightness == Brightness.light ? MargColors.light.bg : MargColors.dark.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.x4),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Golden Tests - Shared Widgets (Light & Dark)', () {
    // 1. BusChip
    testWidgets('BusChip light', (tester) async {
      await tester.pumpWidget(_wrap(const BusChip(line: '17', showIcon: true), Brightness.light));
      await expectLater(find.byType(BusChip), matchesGoldenFile('goldens/bus_chip_light.png'));
    });

    testWidgets('BusChip dark', (tester) async {
      await tester.pumpWidget(_wrap(const BusChip(line: '17', showIcon: true), Brightness.dark));
      await expectLater(find.byType(BusChip), matchesGoldenFile('goldens/bus_chip_dark.png'));
    });

    // 2. WalkChip
    testWidgets('WalkChip light', (tester) async {
      await tester.pumpWidget(_wrap(const WalkChip(durationMins: 6), Brightness.light));
      await expectLater(find.byType(WalkChip), matchesGoldenFile('goldens/walk_chip_light.png'));
    });

    testWidgets('WalkChip dark', (tester) async {
      await tester.pumpWidget(_wrap(const WalkChip(durationMins: 6), Brightness.dark));
      await expectLater(find.byType(WalkChip), matchesGoldenFile('goldens/walk_chip_dark.png'));
    });

    // 3. BadgeLabel
    testWidgets('BadgeLabel light', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeLabel(type: BadgeType.fastest), Brightness.light));
      await expectLater(find.byType(BadgeLabel), matchesGoldenFile('goldens/badge_label_light.png'));
    });

    testWidgets('BadgeLabel dark', (tester) async {
      await tester.pumpWidget(_wrap(const BadgeLabel(type: BadgeType.fastest), Brightness.dark));
      await expectLater(find.byType(BadgeLabel), matchesGoldenFile('goldens/badge_label_dark.png'));
    });

    // 4. PrimaryButton
    testWidgets('PrimaryButton light', (tester) async {
      await tester.pumpWidget(_wrap(PrimaryButton(label: 'Show Routes', onPressed: () {}), Brightness.light));
      await expectLater(find.byType(PrimaryButton), matchesGoldenFile('goldens/primary_button_light.png'));
    });

    testWidgets('PrimaryButton dark', (tester) async {
      await tester.pumpWidget(_wrap(PrimaryButton(label: 'Show Routes', onPressed: () {}), Brightness.dark));
      await expectLater(find.byType(PrimaryButton), matchesGoldenFile('goldens/primary_button_dark.png'));
    });

    // 5. Segmented
    testWidgets('Segmented light', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Segmented<String>(
            items: [
              SegmentItem(value: 'bus', title: 'Bus'),
              SegmentItem(value: 'metro', title: 'Metro', badge: 'Soon', disabled: true),
            ],
            selectedValue: 'bus',
            onValueChanged: _noop,
          ),
          Brightness.light,
        ),
      );
      await expectLater(find.byType(Segmented<String>), matchesGoldenFile('goldens/segmented_light.png'));
    });

    testWidgets('Segmented dark', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Segmented<String>(
            items: [
              SegmentItem(value: 'bus', title: 'Bus'),
              SegmentItem(value: 'metro', title: 'Metro', badge: 'Soon', disabled: true),
            ],
            selectedValue: 'bus',
            onValueChanged: _noop,
          ),
          Brightness.dark,
        ),
      );
      await expectLater(find.byType(Segmented<String>), matchesGoldenFile('goldens/segmented_dark.png'));
    });

    // 6. GlassSheet
    testWidgets('GlassSheet light', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassSheet(
            child: SizedBox(
              height: 60,
              child: Center(child: Text('GlassSheet Content')),
            ),
          ),
          Brightness.light,
        ),
      );
      await expectLater(find.byType(GlassSheet), matchesGoldenFile('goldens/glass_sheet_light.png'));
    });

    testWidgets('GlassSheet dark', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassSheet(
            child: SizedBox(
              height: 60,
              child: Center(child: Text('GlassSheet Content')),
            ),
          ),
          Brightness.dark,
        ),
      );
      await expectLater(find.byType(GlassSheet), matchesGoldenFile('goldens/glass_sheet_dark.png'));
    });

    // 7. SettingsRow
    testWidgets('SettingsRow light', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SettingsRow(
            title: 'Notifications',
            subtitle: 'Real-time delay alerts',
            leading: const Icon(Icons.notifications_active),
            trailing: Switch.adaptive(value: true, onChanged: (_) {}),
          ),
          Brightness.light,
        ),
      );
      await expectLater(find.byType(SettingsRow), matchesGoldenFile('goldens/settings_row_light.png'));
    });

    testWidgets('SettingsRow dark', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SettingsRow(
            title: 'Notifications',
            subtitle: 'Real-time delay alerts',
            leading: const Icon(Icons.notifications_active),
            trailing: Switch.adaptive(value: true, onChanged: (_) {}),
          ),
          Brightness.dark,
        ),
      );
      await expectLater(find.byType(SettingsRow), matchesGoldenFile('goldens/settings_row_dark.png'));
    });

    // 8. Skeleton
    testWidgets('Skeleton light', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Skeleton.card(width: 200, height: 40),
          Brightness.light,
        ),
      );
      await expectLater(find.byType(Skeleton), matchesGoldenFile('goldens/skeleton_light.png'));
    });

    testWidgets('Skeleton dark', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Skeleton.card(width: 200, height: 40),
          Brightness.dark,
        ),
      );
      await expectLater(find.byType(Skeleton), matchesGoldenFile('goldens/skeleton_dark.png'));
    });

    // 9. TimelineRail
    testWidgets('TimelineRail light', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TimelineRail(
            time: Text('8:42'),
            child: Text('Kothrud Depot'),
          ),
          Brightness.light,
        ),
      );
      await expectLater(find.byType(TimelineRail), matchesGoldenFile('goldens/timeline_rail_light.png'));
    });

    testWidgets('TimelineRail dark', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TimelineRail(
            time: Text('8:42'),
            child: Text('Kothrud Depot'),
          ),
          Brightness.dark,
        ),
      );
      await expectLater(find.byType(TimelineRail), matchesGoldenFile('goldens/timeline_rail_dark.png'));
    });
  });
}

void _noop(String _) {}
