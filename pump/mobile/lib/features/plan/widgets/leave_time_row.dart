import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/tile_icon.dart';
import '../../../theme/marg_tokens.dart';

class LeaveTimeRow extends StatelessWidget {
  final String departureTime;
  final ValueChanged<String> onTimeChanged;

  const LeaveTimeRow({
    super.key,
    required this.departureTime,
    required this.onTimeChanged,
  });

  void _showTimePickerSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    final c = context.c;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Glass(
          radius: Rad.sheet,
          topOnly: true,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: c.label3,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: Sp.x4),
                Text(
                  'Departure Time',
                  style: MargText.headline.copyWith(color: c.label),
                ),
                const SizedBox(height: Sp.x3),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const TileIcon(
                    icon: Icons.flash_on_rounded,
                    color: TileColor.blue,
                    size: 32,
                    iconSize: 18,
                  ),
                  title: Text('Leave Now', style: MargText.body.copyWith(color: c.label)),
                  trailing: departureTime.startsWith('Now')
                      ? Icon(Icons.check_rounded, color: c.blue, size: 20)
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final now = TimeOfDay.now();
                    final formatted = _formatTimeOfDay(now);
                    onTimeChanged('Now · $formatted');
                    Navigator.pop(ctx);
                  },
                ),
                Divider(color: c.separator, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const TileIcon(
                    icon: Icons.schedule_rounded,
                    color: TileColor.gray,
                    size: 32,
                    iconSize: 18,
                  ),
                  title: Text('In 15 minutes', style: MargText.body.copyWith(color: c.label)),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final future = DateTime.now().add(const Duration(minutes: 15));
                    final formatted = _formatDateTime(future);
                    onTimeChanged('Today · $formatted');
                    Navigator.pop(ctx);
                  },
                ),
                Divider(color: c.separator, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const TileIcon(
                    icon: Icons.schedule_rounded,
                    color: TileColor.gray,
                    size: 32,
                    iconSize: 18,
                  ),
                  title: Text('In 30 minutes', style: MargText.body.copyWith(color: c.label)),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final future = DateTime.now().add(const Duration(minutes: 30));
                    final formatted = _formatDateTime(future);
                    onTimeChanged('Today · $formatted');
                    Navigator.pop(ctx);
                  },
                ),
                Divider(color: c.separator, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const TileIcon(
                    icon: Icons.edit_calendar_rounded,
                    color: TileColor.gray,
                    size: 32,
                    iconSize: 18,
                  ),
                  title: Text('Custom Time...', style: MargText.body.copyWith(color: c.label)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (picked != null) {
                      HapticFeedback.selectionClick();
                      onTimeChanged('Today · ${_formatTimeOfDay(picked)}');
                    }
                  },
                ),
                const SizedBox(height: Sp.x4),
              ],
            ),
          ),
        ),
      );
    },
    );
  }

  static String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  static String _formatDateTime(DateTime dt) {
    final hourOfPeriod = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hourOfPeriod:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: c.separator, width: 0.5),
      ),
      child: Semantics(
        button: true,
        label: 'Departure time: $departureTime',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showTimePickerSheet(context),
            borderRadius: BorderRadius.circular(Rad.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x3),
              child: Row(
                children: [
                  const TileIcon(
                    icon: Icons.access_time_rounded,
                    color: TileColor.blue,
                    size: 32,
                    iconSize: 16,
                  ),
                  const SizedBox(width: Sp.x3),
                  Text('Leave', style: MargText.body.copyWith(color: c.label)),
                  const Spacer(),
                  Text(
                    departureTime,
                    style: MargText.body.copyWith(color: c.label2),
                  ),
                  const SizedBox(width: Sp.x1),
                  Icon(Icons.chevron_right, color: c.label3, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
