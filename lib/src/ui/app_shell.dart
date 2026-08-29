import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_controller.dart';
import '../core/desktop_destinations.dart';
import 'screens/browser_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/focus_screen.dart';
import 'screens/home_screen.dart';
import 'screens/news_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stocks_screen.dart';
import 'screens/weather_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _destinationIcons = <String, (IconData, IconData)>{
    'home': (Icons.home_outlined, Icons.home),
    'calendar': (Icons.calendar_today_outlined, Icons.calendar_today),
    'weather': (Icons.cloud_outlined, Icons.cloud),
    'markets': (Icons.show_chart, Icons.monitor_heart),
    'news': (Icons.newspaper_outlined, Icons.newspaper),
    'planner': (Icons.checklist_outlined, Icons.checklist),
    'focus': (Icons.timer_outlined, Icons.timer),
    'devices': (Icons.bluetooth_outlined, Icons.bluetooth_connected),
    'browser': (Icons.public_outlined, Icons.public),
    'settings': (Icons.settings_outlined, Icons.settings),
  };

  static final destinations = [
    for (final destination in kDesktopDestinations)
      NavigationRailDestination(
        icon: Icon(_destinationIcons[destination.id]!.$1),
        selectedIcon: Icon(_destinationIcons[destination.id]!.$2),
        label: Text(destination.label),
      ),
  ];

  static const screens = <Widget>[
    HomeScreen(),
    CalendarScreen(),
    WeatherScreen(),
    StocksScreen(),
    NewsScreen(),
    PlannerScreen(),
    FocusScreen(),
    DevicesScreen(),
    BrowserScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final width = MediaQuery.sizeOf(context).width;
    final extended = width >= 1180;
    final compact = width < 760;
    return Scaffold(
      appBar: compact
          ? AppBar(
              title: const _Brand(),
              actions: [
                IconButton(
                  tooltip: 'Refresh essentials',
                  onPressed: controller.refreshAll,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
      drawer: compact
          ? NavigationDrawer(
              selectedIndex: controller.selectedDestination,
              onDestinationSelected: (index) {
                controller.selectDestination(index);
                Navigator.pop(context);
              },
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(28, 24, 16, 12),
                  child: _Brand(),
                ),
                ...destinations.map(
                  (destination) => NavigationDrawerDestination(
                    icon: destination.icon,
                    selectedIcon: destination.selectedIcon,
                    label: destination.label,
                  ),
                ),
              ],
            )
          : null,
      body: Row(
        children: [
          if (!compact)
            NavigationRail(
              extended: extended,
              minExtendedWidth: 220,
              selectedIndex: controller.selectedDestination,
              onDestinationSelected: controller.selectDestination,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: _Brand(),
              ),
              destinations: destinations,
            ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: controller.selectedDestination,
                    children: screens,
                  ),
                ),
                _StatusBar(
                  status: controller.status,
                  signedIn: controller.machine.isSignedIn,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.wb_sunny_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 10),
      const Text(
        'Happy Wakey',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
    ],
  );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.status, required this.signedIn});
  final String status;
  final bool signedIn;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: signedIn ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
  );
}
