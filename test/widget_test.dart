import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/app.dart';
import 'package:happy_wakey/src/core/app_controller.dart';
import 'package:happy_wakey/src/core/config_store.dart';
import 'package:happy_wakey/src/core/desktop_destinations.dart';
import 'package:happy_wakey/src/services/api_client.dart';
import 'package:happy_wakey/src/services/auth_service.dart';
import 'package:happy_wakey/src/services/bluetooth_service.dart';
import 'package:happy_wakey/src/services/calendar_service.dart';
import 'package:happy_wakey/src/services/cloud_reminder_service.dart';
import 'package:happy_wakey/src/services/news_service.dart';
import 'package:happy_wakey/src/services/notification_service.dart';
import 'package:happy_wakey/src/services/stock_service.dart';
import 'package:happy_wakey/src/services/supabase_config_service.dart';
import 'package:happy_wakey/src/services/weather_service.dart';
import 'package:provider/provider.dart';

Future<AppController> _bootstrap() async {
  final api = ApiClient();
  return AppController.bootstrap(
    configStore: MemoryConfigStore(),
    auth: AuthService(null),
    bluetooth: const UnavailableHappyWakeyBluetoothService(),
    remoteConfig: SupabaseConfigService(null),
    weather: WeatherService(api),
    stocks: StockService(api, apiKey: ''),
    news: NewsService(api, apiKey: ''),
    calendar: CalendarService(api),
    notifications: NotificationService(),
    cloudReminders: CloudReminderService(api),
  );
}

const _visibleTitles = <String, String>{
  'calendar': 'Calendar command center',
  'weather': 'Weather',
  'markets': 'Markets',
  'news': 'Headlines',
  'planner': 'Daily planner',
  'focus': 'Focus',
  'devices': 'Bluetooth devices',
  'browser': 'Useful links',
  'settings': 'Settings and diagnostics',
};

void main() {
  testWidgets('onboarding renders and transitions into the adaptive shell', (
    tester,
  ) async {
    final controller = await _bootstrap();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HappyWakeyApp(),
      ),
    );
    expect(find.text('Start the day in one place'), findsNWidgets(2));

    await controller.onboardingSkip();
    await controller.onboardingFinish();
    await tester.pumpAndSettle();

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('Daily planner'), findsNothing);
  });

  testWidgets('shell can open every shared desktop destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _bootstrap();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HappyWakeyApp(),
      ),
    );
    await controller.onboardingSkip();
    await controller.onboardingFinish();
    await tester.pumpAndSettle();

    expect(kDesktopDestinations, hasLength(10));
    controller.selectDestination(-1);
    controller.selectDestination(99);
    expect(controller.selectedDestination, 0);

    for (var index = 0; index < kDesktopDestinations.length; index++) {
      controller.selectDestination(index);
      await tester.pumpAndSettle();
      expect(controller.selectedDestination, index);
      final id = kDesktopDestinations[index].id;
      if (id == 'home') {
        expect(find.textContaining('Good '), findsOneWidget);
      } else if (const {'weather', 'markets', 'focus'}.contains(id)) {
        expect(find.text(_visibleTitles[id]!), findsWidgets);
      } else {
        expect(find.text(_visibleTitles[id]!), findsOneWidget);
      }
    }
  });

  testWidgets('home jump cards open planner, focus, and devices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _bootstrap();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HappyWakeyApp(),
      ),
    );
    await controller.onboardingSkip();
    await controller.onboardingFinish();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose the important work'));
    await tester.pumpAndSettle();
    expect(find.text('Daily planner'), findsOneWidget);

    controller.selectDestination(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start a focus block'));
    await tester.pumpAndSettle();
    expect(find.text('Focus'), findsWidgets);

    controller.selectDestination(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect an alarm device'));
    await tester.pumpAndSettle();
    expect(find.text('Bluetooth devices'), findsOneWidget);
    expect(find.text('Bluetooth Low Energy is unavailable'), findsOneWidget);
  });

  testWidgets('focus can start, pause, resume, and reset', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _bootstrap();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HappyWakeyApp(),
      ),
    );
    await controller.onboardingSkip();
    await controller.onboardingFinish();
    controller.selectDestination(6);
    await tester.pumpAndSettle();

    expect(find.text('IDLE'), findsOneWidget);
    await tester.tap(find.text('Start focus'));
    await tester.pump();
    expect(find.text('RUNNING'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(find.text('RUNNING'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('IDLE'), findsOneWidget);
  });

  testWidgets('browser lists only persisted https bookmarks', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _bootstrap();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HappyWakeyApp(),
      ),
    );
    await controller.onboardingSkip();
    await controller.onboardingFinish();
    controller.selectDestination(8);
    await tester.pumpAndSettle();

    expect(find.text('Useful links'), findsOneWidget);
    expect(controller.config.browserBookmarks, isNotEmpty);
    for (final bookmark in controller.config.browserBookmarks) {
      expect(bookmark.url.scheme, 'https');
      expect(bookmark.url.userInfo, isEmpty);
    }
    expect(find.textContaining('javascript:'), findsNothing);
  });

  testWidgets('planner can add a local task', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await _bootstrap();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const HappyWakeyApp(),
      ),
    );
    await controller.onboardingSkip();
    await controller.onboardingFinish();
    controller.selectDestination(5);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ship the parity tests');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Ship the parity tests'), findsOneWidget);
    expect(controller.config.tasks.single.title, 'Ship the parity tests');
  });
}
