import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/explore/explore_screen.dart';
import '../features/saved/saved_screen.dart';
import '../features/alerts/alerts_screen.dart';
import '../shared/widgets/glass_tab_bar.dart';
import 'app_state.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);

    return Scaffold(
      body: Stack(
        children: [
          // IndexedStack for persistent state across tabs
          IndexedStack(
            index: currentTab.index,
            children: const [
              ExploreScreen(),
              SavedScreen(),
              AlertsScreen(),
            ],
          ),

          // Floating Glass Tab Bar at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassTabBar(
              currentTab: currentTab,
              onTabSelected: (tab) {
                ref.read(currentTabProvider.notifier).setTab(tab);
              },
            ),
          ),
        ],
      ),
    );
  }
}
