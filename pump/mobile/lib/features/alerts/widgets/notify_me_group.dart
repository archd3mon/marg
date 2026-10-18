import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';
import 'toggle_row.dart';

class NotifyMeGroup extends StatelessWidget {
  final bool notifyDelays;
  final bool notifyLeaveNow;
  final bool notifyServiceChanges;
  final bool demoAlertsEnabled;
  final ValueChanged<bool> onNotifyDelaysChanged;
  final ValueChanged<bool> onNotifyLeaveNowChanged;
  final ValueChanged<bool> onNotifyServiceChangesChanged;
  final ValueChanged<bool> onDemoAlertsChanged;

  const NotifyMeGroup({
    super.key,
    required this.notifyDelays,
    required this.notifyLeaveNow,
    required this.notifyServiceChanges,
    required this.demoAlertsEnabled,
    required this.onNotifyDelaysChanged,
    required this.onNotifyLeaveNowChanged,
    required this.onNotifyServiceChangesChanged,
    required this.onDemoAlertsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: c.separator, width: 0.5),
      ),
      child: Column(
        children: [
          ToggleRow(
            title: 'Delays on saved routes',
            value: notifyDelays,
            onChanged: onNotifyDelaysChanged,
          ),
          Divider(color: c.separator, height: 1, indent: Sp.x4),
          ToggleRow(
            title: 'Leave-now reminders',
            value: notifyLeaveNow,
            onChanged: onNotifyLeaveNowChanged,
          ),
          Divider(color: c.separator, height: 1, indent: Sp.x4),
          ToggleRow(
            title: 'Service changes',
            value: notifyServiceChanges,
            onChanged: onNotifyServiceChangesChanged,
          ),
          if (!kReleaseMode) ...[
            Divider(color: c.separator, height: 1, indent: Sp.x4),
            ToggleRow(
              title: 'Sample notices (kDemoAlerts)',
              subtitle: 'Demo flag (default false · off in release)',
              value: demoAlertsEnabled,
              activeColor: c.blue,
              onChanged: onDemoAlertsChanged,
            ),
          ],
        ],
      ),
    );
  }
}
