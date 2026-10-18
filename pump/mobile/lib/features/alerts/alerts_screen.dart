import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/marg_tokens.dart';
import '../../shared/widgets/segmented_control.dart';
import '../../app/app_state.dart';
import 'widgets/alerts_list.dart';
import 'widgets/notify_me_group.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String _selectedSegment = 'my_routes';

  late bool _notifyDelays;
  late bool _notifyLeaveNow;
  late bool _notifyServiceChanges;
  late bool _demoAlertsEnabled;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _notifyDelays = storage.notifyDelays;
    _notifyLeaveNow = storage.notifyLeaveNow;
    _notifyServiceChanges = storage.notifyServiceChanges;
    _demoAlertsEnabled = storage.demoAlertsEnabled;
  }

  void _updateNotifyDelays(bool val) {
    setState(() => _notifyDelays = val);
    ref.read(storageServiceProvider).setNotifyDelays(val);
  }

  void _updateNotifyLeaveNow(bool val) {
    setState(() => _notifyLeaveNow = val);
    ref.read(storageServiceProvider).setNotifyLeaveNow(val);
  }

  void _updateNotifyServiceChanges(bool val) {
    setState(() => _notifyServiceChanges = val);
    ref.read(storageServiceProvider).setNotifyServiceChanges(val);
  }

  void _updateDemoAlerts(bool val) {
    setState(() => _demoAlertsEnabled = val);
    ref.read(storageServiceProvider).setDemoAlertsEnabled(val);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final repo = ref.watch(transitRepositoryProvider);
    final alerts = repo.getAlerts(
      myRoutesOnly: _selectedSegment == 'my_routes',
      showDemoAlerts: _demoAlertsEnabled,
      notifyLeaveNow: _notifyLeaveNow,
      notifyDelays: _notifyDelays,
      notifyServiceChanges: _notifyServiceChanges,
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
          children: [
            const SizedBox(height: Sp.x4),
            Text(
              'Alerts',
              style: MargText.largeTitle.copyWith(color: c.label),
            ),
            const SizedBox(height: Sp.x3),

            // Segmented Control (My Routes / All Service)
            MargSegmentedControl<String>(
              items: const [
                SegmentItem(value: 'my_routes', title: 'My Routes'),
                SegmentItem(value: 'all_service', title: 'All Service'),
              ],
              selectedValue: _selectedSegment,
              onValueChanged: (val) {
                setState(() => _selectedSegment = val);
              },
            ),

            const SizedBox(height: Sp.x4),

            // Alerts Grouped List
            AlertsList(alerts: alerts),

            const SizedBox(height: Sp.x6),

            // "NOTIFY ME" Section Header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: Sp.x2),
              child: Text(
                'NOTIFY ME',
                style: MargText.footnote.copyWith(
                  color: c.label2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Notification Toggles Container
            NotifyMeGroup(
              notifyDelays: _notifyDelays,
              notifyLeaveNow: _notifyLeaveNow,
              notifyServiceChanges: _notifyServiceChanges,
              demoAlertsEnabled: _demoAlertsEnabled,
              onNotifyDelaysChanged: _updateNotifyDelays,
              onNotifyLeaveNowChanged: _updateNotifyLeaveNow,
              onNotifyServiceChangesChanged: _updateNotifyServiceChanges,
              onDemoAlertsChanged: _updateDemoAlerts,
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
