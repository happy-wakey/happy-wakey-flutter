import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/core/app_controller.dart';
import 'package:happy_wakey/src/startup/happy_wakey_bootstrap.dart';

void main() {
  testWidgets('shows Happy Wakey while device startup is pending', (
    tester,
  ) async {
    final startup = Completer<AppController>();

    await tester.pumpWidget(
      HappyWakeyBootstrapApp(
        startup: () => startup.future,
        startupTimeout: const Duration(seconds: 30),
      ),
    );

    expect(find.text('Happy Wakey'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('happy-wakey-startup-loading')),
      findsOneWidget,
    );
  });

  testWidgets('bounds startup and exposes a fresh retry attempt', (
    tester,
  ) async {
    var attempts = 0;

    await tester.pumpWidget(
      HappyWakeyBootstrapApp(
        startup: () {
          attempts += 1;
          return Completer<AppController>().future;
        },
        startupTimeout: const Duration(milliseconds: 10),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Happy Wakey'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('happy-wakey-startup-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('happy-wakey-startup-retry')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('happy-wakey-startup-retry')));
    await tester.pump();

    expect(attempts, 2);
    expect(
      find.byKey(const ValueKey('happy-wakey-startup-loading')),
      findsOneWidget,
    );
  });
}
