import 'package:flutter_test/flutter_test.dart';
import 'package:happy_wakey/src/app.dart';
import 'package:happy_wakey/src/core/app_controller.dart';
import 'package:happy_wakey/src/core/config_store.dart';
import 'package:happy_wakey/src/services/api_client.dart';
import 'package:happy_wakey/src/services/auth_service.dart';
import 'package:happy_wakey/src/services/calendar_service.dart';
import 'package:happy_wakey/src/services/cloud_reminder_service.dart';
import 'package:happy_wakey/src/services/news_service.dart';
import 'package:happy_wakey/src/services/notification_service.dart';
import 'package:happy_wakey/src/services/stock_service.dart';
import 'package:happy_wakey/src/services/supabase_config_service.dart';
import 'package:happy_wakey/src/services/weather_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('onboarding renders and transitions into the adaptive shell', (
    tester,
  ) async {
    final api = ApiClient();
    final auth = AuthService(null);
    final controller = await AppController.bootstrap(
      configStore: MemoryConfigStore(),
      auth: auth,
      remoteConfig: SupabaseConfigService(null),
      weather: WeatherService(api),
      stocks: StockService(api, apiKey: ''),
      news: NewsService(api, apiKey: ''),
      calendar: CalendarService(api),
      notifications: NotificationService(),
      cloudReminders: CloudReminderService(api),
    );
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
}
