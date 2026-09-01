import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../src/app.dart';
import '../core/app_controller.dart';
import '../core/config_store.dart';
import '../core/environment.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/bluetooth_service.dart';
import '../services/calendar_service.dart';
import '../services/cloud_reminder_service.dart';
import '../services/news_service.dart';
import '../services/notification_service.dart';
import '../services/stock_service.dart';
import '../services/supabase_config_service.dart';
import '../services/weather_service.dart';

typedef HappyWakeyStartup = Future<AppController> Function();

Future<void>? _supabaseStartup;

Future<void> _ensureSupabaseInitialized() async {
  if (!Environment.supabaseConfigured) return;
  final pending = _supabaseStartup;
  if (pending != null) {
    await pending;
    return;
  }

  final startup = Supabase.initialize(
    url: Environment.supabaseUrl,
    publishableKey: Environment.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  ).then<void>((_) {});
  _supabaseStartup = startup;
  try {
    await startup;
  } catch (_) {
    if (identical(_supabaseStartup, startup)) {
      _supabaseStartup = null;
    }
    rethrow;
  }
}

Future<AppController> bootstrapHappyWakeyRuntime() async {
  await _ensureSupabaseInitialized();

  final api = ApiClient();
  final auth = AuthService(
    Environment.supabaseConfigured ? Supabase.instance.client : null,
  );
  return AppController.bootstrap(
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
}

class HappyWakeyBootstrapApp extends StatefulWidget {
  const HappyWakeyBootstrapApp({
    super.key,
    this.startup,
    this.startupTimeout = const Duration(seconds: 15),
  });

  final HappyWakeyStartup? startup;
  final Duration startupTimeout;

  @override
  State<HappyWakeyBootstrapApp> createState() => _HappyWakeyBootstrapAppState();
}

enum _StartupPhase { starting, ready, failed }

class _HappyWakeyBootstrapAppState extends State<HappyWakeyBootstrapApp> {
  _StartupPhase _phase = _StartupPhase.starting;
  AppController? _controller;
  String? _failureMessage;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    final attempt = ++_attempt;
    if (mounted) {
      setState(() {
        _phase = _StartupPhase.starting;
        _failureMessage = null;
      });
    }

    final source = (widget.startup ?? bootstrapHappyWakeyRuntime)();
    try {
      final controller = await source.timeout(widget.startupTimeout);
      _accept(controller, attempt);
    } on TimeoutException {
      _fail(
        attempt,
        'Startup took too long. Device services remain inactive; check connectivity or permissions and retry.',
      );
      unawaited(_acceptLateCompletion(source, attempt));
    } catch (_) {
      _fail(
        attempt,
        'Happy Wakey could not prepare its local command center. No account or reminder data was opened.',
      );
    }
  }

  Future<void> _acceptLateCompletion(
    Future<AppController> source,
    int attempt,
  ) async {
    try {
      final controller = await source;
      _accept(controller, attempt);
    } catch (_) {
      // The visible failure state remains authoritative until a retry succeeds.
    }
  }

  void _accept(AppController controller, int attempt) {
    if (!mounted || attempt != _attempt) {
      controller.dispose();
      return;
    }
    _controller?.dispose();
    setState(() {
      _controller = controller;
      _phase = _StartupPhase.ready;
      _failureMessage = null;
    });
  }

  void _fail(int attempt, String message) {
    if (!mounted || attempt != _attempt) return;
    setState(() {
      _phase = _StartupPhase.failed;
      _failureMessage = message;
    });
  }

  @override
  void dispose() {
    _attempt += 1;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_phase == _StartupPhase.ready && controller != null) {
      return ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: const HappyWakeyApp(),
      );
    }
    return _StartupSurface(
      failed: _phase == _StartupPhase.failed,
      message: _failureMessage,
      onRetry: _start,
    );
  }
}

class _StartupSurface extends StatelessWidget {
  const _StartupSurface({
    required this.failed,
    required this.message,
    required this.onRetry,
  });

  final bool failed;
  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Happy Wakey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xfff1a23a),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  key: const ValueKey('happy-wakey-startup-surface'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wb_sunny_outlined, size: 68),
                    const SizedBox(height: 18),
                    Text(
                      'Happy Wakey',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      failed
                          ? message ?? 'Startup failed safely.'
                          : 'Preparing your daily command center…',
                      key: ValueKey(
                        failed
                            ? 'happy-wakey-startup-error'
                            : 'happy-wakey-startup-loading',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (failed)
                      FilledButton.icon(
                        key: const ValueKey('happy-wakey-startup-retry'),
                        onPressed: () => unawaited(onRetry()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      )
                    else
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Bluetooth, notifications, reminders, and account data stay inactive until startup completes.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
