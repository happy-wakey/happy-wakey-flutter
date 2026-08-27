/// Canonical desktop destinations shared with the Qt app and e2e contract.
final class DesktopDestination {
  const DesktopDestination({required this.id, required this.label});

  final String id;
  final String label;
}

const kDesktopDestinations = <DesktopDestination>[
  DesktopDestination(id: 'home', label: 'Home'),
  DesktopDestination(id: 'calendar', label: 'Calendar'),
  DesktopDestination(id: 'weather', label: 'Weather'),
  DesktopDestination(id: 'markets', label: 'Markets'),
  DesktopDestination(id: 'news', label: 'News'),
  DesktopDestination(id: 'planner', label: 'Planner'),
  DesktopDestination(id: 'focus', label: 'Focus'),
  DesktopDestination(id: 'devices', label: 'Devices'),
  DesktopDestination(id: 'browser', label: 'Browser'),
  DesktopDestination(id: 'settings', label: 'Settings'),
];
