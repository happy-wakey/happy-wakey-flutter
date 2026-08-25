import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/core/app_controller.dart';
import 'src/core/config_store.dart';
import 'src/core/environment.dart';
import 'src/services/api_client.dart';
import 'src/services/auth_service.dart';
import 'src/services/bluetooth_service.dart';
import 'src/services/calendar_service.dart';
import 'src/services/cloud_reminder_service.dart';
import 'src/services/news_service.dart';
import 'src/services/notification_service.dart';
import 'src/services/stock_service.dart';
import 'src/services/supabase_config_service.dart';
import 'src/services/weather_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Environment.supabaseConfigured) {
    await Supabase.initialize(
      url: Environment.supabaseUrl,
      publishableKey: Environment.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  final api = ApiClient();
  final auth = AuthService(
    Environment.supabaseConfigured ? Supabase.instance.client : null,
  );
  final controller = await AppController.bootstrap(
    configStore: SharedPreferencesConfigStore(),
    auth: auth,
    bluetooth: UniversalHappyWakeyBluetoothService(),
    remoteConfig: SupabaseConfigService(auth.client),
    weather: WeatherService(api),
    stocks: StockService(api, apiKey: Environment.finnhubApiKey),
    news: NewsService(api, apiKey: Environment.newsApiKey),
    calendar: CalendarService(api),
    notifications: NotificationService(),
    cloudReminders: CloudReminderService(api),
  );

  runApp(
    ChangeNotifierProvider.value(
      value: controller,
      child: const HappyWakeyApp(),
    ),
  );
}
