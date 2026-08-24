import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_controller.dart';
import 'screens/browser_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/focus_screen.dart';
import 'screens/home_screen.dart';
import 'screens/news_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stocks_screen.dart';
import 'screens/weather_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('Home'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.calendar_today_outlined),
      selectedIcon: Icon(Icons.calendar_today),
      label: Text('Calendar'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.cloud_outlined),
      selectedIcon: Icon(Icons.cloud),
      label: Text('Weather'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.show_chart),
      selectedIcon: Icon(Icons.monitor_heart),
      label: Text('Markets'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.newspaper_outlined),
      selectedIcon: Icon(Icons.newspaper),
      label: Text('News'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.checklist_outlined),
      selectedIcon: Icon(Icons.checklist),
      label: Text('Planner'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.timer_outlined),
      selectedIcon: Icon(Icons.timer),
      label: Text('Focus'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.public_outlined),
      selectedIcon: Icon(Icons.public),
      label: Text('Browser'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('Settings'),
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
