import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/core/desktop_destinations.dart';
import 'package:happy_wakey/src/ui/app_shell.dart';

void main() {
  test('shell destinations match the shared desktop contract', () {
    expect(kDesktopDestinations.map((destination) => destination.id).toList(), [
      'home',
      'calendar',
      'weather',
      'markets',
      'news',
      'planner',
      'focus',
      'devices',
      'browser',
      'settings',
    ]);
    expect(AppShell.destinations, hasLength(kDesktopDestinations.length));
    expect(AppShell.screens, hasLength(kDesktopDestinations.length));
    for (var index = 0; index < kDesktopDestinations.length; index++) {
      expect(
        (AppShell.destinations[index].label as Text).data,
        kDesktopDestinations[index].label,
      );
    }
  });
}
