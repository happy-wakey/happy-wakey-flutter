import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/bluetooth_service.dart';
import '../services/calendar_service.dart';
import '../services/cloud_reminder_service.dart';
import '../services/news_service.dart';
import '../services/notification_service.dart';
import '../services/stock_service.dart';
import '../services/supabase_config_service.dart';
import '../services/weather_service.dart';
import 'app_config.dart';
import 'app_state.dart';
import 'config_store.dart';
import 'desktop_destinations.dart';
import 'focus_state.dart';
import 'reactive_app_state.dart';

final class AppController extends ChangeNotifier {
  AppController._({
    required this._configStore,
    required this._config,
    required this._machine,
    required this._auth,
    required this._bluetooth,
    required this._remoteConfig,
    required this._weather,
    required this._stocks,
    required this._news,
    required this._calendar,
    required this._notifications,
    required this._cloudReminders,
  });

  static Future<AppController> bootstrap({
    required ConfigStore configStore,
    required AuthService auth,
    required HappyWakeyBluetoothService bluetooth,
    required SupabaseConfigService remoteConfig,
    required WeatherService weather,
    required StockService stocks,
    required NewsService news,
    required CalendarService calendar,
    required NotificationService notifications,
    required CloudReminderService cloudReminders,
  }) async {
    final config = (await configStore.load()).sanitized();
    final machine = AppMachine(
      signedIn: auth.currentSession != null,
      onboarding: config.onboarding.step,
    );
    final controller = AppController._(
      configStore: configStore,
      config: config,
      machine: machine,
      auth: auth,
      bluetooth: bluetooth,
      remoteConfig: remoteConfig,
      weather: weather,
      stocks: stocks,
      news: news,
      calendar: calendar,
      notifications: notifications,
      cloudReminders: cloudReminders,
    );
    controller._reactiveState = ReactiveAppState(
      projectReactiveSnapshot(machine: machine, status: controller._status),
    );
    controller._authSubscription = auth.sessionChanges.listen(
      controller._onAuthSessionChanged,
    );
    controller._dispatch(const StartupCompleted());
    try {
      controller._bluetoothSupported = await bluetooth.isSupported().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      controller._bluetoothSupported = false;
    }
    try {
      await notifications.initialize();
    } catch (error) {
      controller._status =
          'Notifications are unavailable on this platform: $error';
    }
    unawaited(controller.hydrateOnboarding());
    return controller;
  }

  final ConfigStore _configStore;
  AppConfig _config;
  final AppMachine _machine;
  final AuthService _auth;
  final HappyWakeyBluetoothService _bluetooth;
  final SupabaseConfigService _remoteConfig;
  final WeatherService _weather;
  final StockService _stocks;
  final NewsService _news;
  final CalendarService _calendar;
  final NotificationService _notifications;
  final CloudReminderService _cloudReminders;
  final FocusMachine _focusMachine = FocusMachine();
  ReactiveAppState? _reactiveState;

  StreamSubscription<AuthSessionSnapshot?>? _authSubscription;
  Timer? _focusTimer;
  Timer? _loginTimer;
  OperationToken? _loginToken;
  bool _disposed = false;
  String _status = 'Ready';
  int _selectedDestination = 0;
  List<WeatherData> _weatherData = const [];
  List<StockQuote> _stockData = const [];
  List<NewsItem> _newsData = const [];
  List<HappyWakeyBleDevice> _bluetoothDevices = const [];
  bool _bluetoothSupported = false;
  String? _connectedBluetoothDeviceId;
  List<CalendarEvent> _calendarEvents = const [];
  CalendarAgenda _agenda = const CalendarAgenda.empty();
  int _cloudReminderPending = 0;

  AppConfig get config => _config;
  AppMachine get machine => _machine;
  FocusSnapshot get focus => _focusMachine.snapshot;
  String get status => _status;
  int get selectedDestination => _selectedDestination;
  List<WeatherData> get weatherData => _weatherData;
  List<StockQuote> get stockData => _stockData;
  List<NewsItem> get newsData => _newsData;
  List<HappyWakeyBleDevice> get bluetoothDevices => _bluetoothDevices;
  bool get bluetoothSupported => _bluetoothSupported;
  String? get connectedBluetoothDeviceId => _connectedBluetoothDeviceId;
  List<CalendarEvent> get calendarEvents => _calendarEvents;
  CalendarAgenda get agenda => _agenda;
  int get cloudReminderPending => _cloudReminderPending;
  AuthSessionSnapshot? get session => _auth.currentSession;
  bool get supabaseConfigured => _auth.configured;
  ReactiveAppState get reactiveState => _reactiveState!;

  bool loading(OperationLane lane) => _machine.lane(lane).isRunning;

  void selectDestination(int index) {
    if (index < 0 || index >= kDesktopDestinations.length) return;
    if (index == _selectedDestination) return;
    _selectedDestination = index;
    notifyListeners();
  }

  Future<void> login(AuthProvider provider) async {
    final outcome = _dispatch(LoginRequested(provider));
    final token = outcome.token;
    if (token == null) return _reject(outcome);
    _loginToken = token;
    _loginTimer?.cancel();
    _loginTimer = Timer(const Duration(minutes: 5), () {
      if (_disposed || !_machine.acceptsAuthToken(token)) return;
      if (_dispatch(LoginFailed(token)).committed) {
        _loginToken = null;
        _setStatus('Sign-in timed out safely; try again when ready');
      }
    });
    _setStatus('Opening ${provider.name} sign-in…');
    try {
      await _auth.startLogin(provider);
    } catch (error) {
      _loginTimer?.cancel();
      if (_dispatch(LoginFailed(token)).committed) {
        _loginToken = null;
        _setStatus('Sign-in failed: $error');
      }
    }
  }

  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (error) {
      _setStatus('Logout failed closed: $error');
      return;
    }
    if (!_dispatch(const LogoutRequested()).committed) return;
    _loginTimer?.cancel();
    _loginToken = null;
    _cloudReminders.clearSession();
    _calendarEvents = const [];
    _agenda = const CalendarAgenda.empty();
    _cloudReminderPending = 0;
    _setStatus('Signed out');
  }

  void _onAuthSessionChanged(AuthSessionSnapshot? value) {
    if (value != null) {
      final token = _loginToken;
      if (token != null && _machine.acceptsAuthToken(token)) {
        _loginTimer?.cancel();
        _dispatch(LoginSucceeded(token));
        _loginToken = null;
        _setStatus(
          'Signed in as ${value.email.isEmpty ? value.userId : value.email}',
        );
        unawaited(hydrateOnboarding());
      }
    } else if (_machine.isSignedIn || _machine.authenticationInProgress) {
      _loginTimer?.cancel();
      _dispatch(const LogoutRequested());
      _loginToken = null;
      _cloudReminders.clearSession();
      _calendarEvents = const [];
      _agenda = const CalendarAgenda.empty();
      _setStatus('Signed out');
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([refreshWeather(), refreshStocks(), refreshNews()]);
    if (_machine.isSignedIn) await refreshCalendar();
  }

  Future<void> scanBluetooth() async {
    final token = _beginLane(OperationLane.bluetooth);
    if (token == null) return;
    _setStatus('Scanning for Happy Wakey Bluetooth devices…');
    try {
      final devices = await _bluetooth.scan();
      if (!_finishLane(OperationLane.bluetooth, token, succeeded: true)) return;
      _bluetoothDevices = devices;
      _setStatus(
        devices.isEmpty
            ? 'No Happy Wakey Bluetooth devices found'
            : 'Found ${devices.length} Happy Wakey Bluetooth device(s)',
      );
    } catch (error) {
      if (_finishLane(OperationLane.bluetooth, token, succeeded: false)) {
        _setStatus('Bluetooth scan failed: $error');
      }
    }
  }

  Future<void> connectBluetooth(String deviceId) async {
    final token = _beginLane(OperationLane.bluetooth);
    if (token == null) return;
    _setStatus('Connecting to Happy Wakey Bluetooth device…');
    try {
      await _bluetooth.connect(deviceId);
      if (!_finishLane(OperationLane.bluetooth, token, succeeded: true)) {
        await _bluetooth.disconnect();
        return;
      }
      _connectedBluetoothDeviceId = _bluetooth.connectedDeviceId;
      _setStatus('Happy Wakey Bluetooth device connected');
    } catch (error) {
      if (_finishLane(OperationLane.bluetooth, token, succeeded: false)) {
        _setStatus('Bluetooth connection failed: $error');
      }
    }
  }

  Future<void> disconnectBluetooth() async {
    final token = _beginLane(OperationLane.bluetooth);
    if (token == null) return;
    _setStatus('Disconnecting Bluetooth device…');
    try {
      await _bluetooth.disconnect();
      if (!_finishLane(OperationLane.bluetooth, token, succeeded: true)) return;
      _connectedBluetoothDeviceId = null;
      _setStatus('Bluetooth device disconnected');
    } catch (error) {
      if (_finishLane(OperationLane.bluetooth, token, succeeded: false)) {
        _setStatus('Bluetooth disconnect failed: $error');
      }
    }
  }

  Future<void> previewBluetoothAlarm() async {
    final token = _beginLane(OperationLane.bluetooth);
    if (token == null) return;
    _setStatus('Sending a three-second alarm preview…');
    try {
      await _bluetooth.sendPreviewAlarm();
      if (!_finishLane(OperationLane.bluetooth, token, succeeded: true)) return;
      _setStatus('Bluetooth alarm preview sent');
    } catch (error) {
      if (_finishLane(OperationLane.bluetooth, token, succeeded: false)) {
        _setStatus('Bluetooth alarm preview failed: $error');
      }
    }
  }

  Future<void> refreshWeather() async {
    final token = _beginLane(OperationLane.weather);
    if (token == null) return;
    if (_config.weatherLocations.isEmpty) {
      _finishLane(OperationLane.weather, token, succeeded: false);
      return _setStatus('Add a weather location in Settings');
    }
    _setStatus('Refreshing weather…');
    final results = await Future.wait(
      _config.weatherLocations.map((location) async {
        try {
          return (data: await _weather.fetch(location), error: null as Object?);
        } catch (error) {
          return (data: null as WeatherData?, error: error);
        }
      }),
    );
    final data = results
        .map((value) => value.data)
        .whereType<WeatherData>()
        .toList();
    final errors = results
        .map((value) => value.error)
        .whereType<Object>()
        .toList();
    final succeeded = data.isNotEmpty;
    if (!_finishLane(OperationLane.weather, token, succeeded: succeeded)) {
      return;
    }
    if (succeeded) _weatherData = data;
    _setStatus(
      errors.isEmpty
          ? 'Weather updated for ${data.length} location(s)'
          : data.isEmpty
          ? 'Weather refresh failed: ${errors.first}'
          : 'Weather updated for ${data.length}; ${errors.length} failed',
    );
  }

  Future<void> refreshStocks() async {
    final token = _beginLane(OperationLane.stocks);
    if (token == null) return;
    if (_config.stockSymbols.isEmpty) {
      _finishLane(OperationLane.stocks, token, succeeded: false);
      return _setStatus('Add a market symbol in Settings');
    }
    _setStatus('Refreshing markets…');
    final data = <StockQuote>[];
    final errors = <Object>[];
    for (final symbol in _config.stockSymbols) {
      try {
        data.add(await _stocks.fetch(symbol));
      } catch (error) {
        errors.add(error);
      }
    }
    if (!_finishLane(OperationLane.stocks, token, succeeded: data.isNotEmpty)) {
      return;
    }
    if (data.isNotEmpty) _stockData = data;
    _setStatus(
      errors.isEmpty
          ? 'Markets updated: ${data.length} symbols'
          : data.isEmpty
          ? 'Market refresh failed: ${errors.first}'
          : 'Markets updated for ${data.length}; ${errors.length} failed',
    );
  }

  Future<void> refreshNews() async {
    final token = _beginLane(OperationLane.news);
    if (token == null) return;
    _setStatus('Refreshing headlines…');
    try {
      final data = await _news.fetch(_config.newsKeywords);
      if (!_finishLane(OperationLane.news, token, succeeded: true)) return;
      _newsData = data;
      _setStatus('Headlines updated: ${data.length} matched');
    } catch (error) {
      if (_finishLane(OperationLane.news, token, succeeded: false)) {
        _setStatus('News refresh failed: $error');
      }
    }
  }

  Future<void> refreshCalendar() async {
    final token = _beginLane(OperationLane.calendar);
    if (token == null) return;
    final active = session;
    if (active == null) {
      _finishLane(OperationLane.calendar, token, succeeded: false);
      return _setStatus('Sign in before refreshing calendars');
    }
    _setStatus('Refreshing calendar…');
    try {
      final events = await _calendar.fetch(
        provider: active.provider,
        providerToken: active.providerToken,
      );
      Object? reminderError;
      try {
        await _notifications
            .scheduleCalendar(events, _config.reminderSettings)
            .timeout(const Duration(seconds: 20));
      } catch (error) {
        reminderError = error;
      }
      if (!_finishLane(OperationLane.calendar, token, succeeded: true)) return;
      _calendarEvents = events;
      _agenda = CalendarService.agenda(events);
      _setStatus(
        reminderError == null
            ? 'Calendar updated: ${events.length} events'
            : 'Calendar updated; local reminders unavailable: $reminderError',
      );
      if (_config.reminderSettings.cloudEmailEnabled &&
          session?.userId == active.userId) {
        unawaited(_syncCloudReminders(active.accessToken));
      }
    } catch (error) {
      if (_finishLane(OperationLane.calendar, token, succeeded: false)) {
        _setStatus('Calendar refresh failed: $error');
      }
    }
  }

  Future<void> hydrateOnboarding() async {
    if (!_config.supabaseSyncEnabled ||
        !_machine.isSignedIn ||
        !_remoteConfig.configured) {
      return;
    }
    final token = _beginLane(OperationLane.onboardingHydration);
    if (token == null) return;
    try {
      final remote = await _remoteConfig.fetchOnboarding().timeout(
        const Duration(seconds: 20),
      );
      if (!_machine.acceptsLaneToken(
        OperationLane.onboardingHydration,
        token,
      )) {
        return;
      }
      if (remote == null) {
        if (_finishLane(
          OperationLane.onboardingHydration,
          token,
          succeeded: true,
        )) {
          _mirrorOnboarding(_config.onboarding);
        }
        return;
      }
      final merged = _mergeOnboarding(_config.onboarding, remote);
      final candidate = _machine.copy();
      final preview = candidate.dispatch(OnboardingReconciled(merged.step));
      if (!preview.committed) {
        _finishLane(OperationLane.onboardingHydration, token, succeeded: true);
        return;
      }
      final next = _config.copyWith(onboarding: merged);
      await _configStore.save(next);
      if (!_finishLane(
        OperationLane.onboardingHydration,
        token,
        succeeded: true,
      )) {
        return;
      }
      if (!_dispatch(OnboardingReconciled(merged.step)).committed) return;
      _config = next;
      notifyListeners();
    } catch (error) {
      if (_finishLane(
        OperationLane.onboardingHydration,
        token,
        succeeded: false,
      )) {
        _setStatus('Onboarding sync failed: $error');
      }
    }
  }

  Future<void> onboardingNext() =>
      _transitionOnboarding(const OnboardingNext());
  Future<void> onboardingPrevious() =>
      _transitionOnboarding(const OnboardingPrevious());
  Future<void> onboardingSkip() =>
      _transitionOnboarding(const OnboardingSkipToReady());
  Future<void> onboardingFinish() =>
      _transitionOnboarding(const OnboardingFinish());

  Future<void> _transitionOnboarding(AppEvent event) async {
    final candidate = _machine.copy();
    final preview = candidate.dispatch(event);
    if (!preview.committed) return _reject(preview);
    final next = _config.copyWith(
      onboarding: OnboardingConfig.fromStep(candidate.onboarding),
    );
    try {
      await _configStore.save(next);
    } catch (error) {
      return _setStatus('Onboarding save failed: $error');
    }
    if (!_dispatch(event).committed) {
      return _setStatus('Onboarding changed while it was being persisted');
    }
    _config = next;
    notifyListeners();
    if (_config.supabaseSyncEnabled && _machine.isSignedIn) {
      _mirrorOnboarding(next.onboarding);
    }
  }

  Future<void> updateConfig(AppConfig next) async {
    final sanitized = next.copyWith(onboarding: _config.onboarding).sanitized();
    try {
      await _configStore.save(sanitized);
      _config = sanitized;
      notifyListeners();
      _setStatus('Settings saved');
      if (_config.supabaseSyncEnabled && _machine.isSignedIn) {
        _mirrorConfig(_config);
      }
    } catch (error) {
      _setStatus('Settings save failed: $error');
    }
  }

  Future<void> addTask(String title) async {
    final cleaned = title.trim();
    if (cleaned.isEmpty) return;
    final task = DailyTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: cleaned.length <= 160 ? cleaned : cleaned.substring(0, 160),
    );
    await updateConfig(_config.copyWith(tasks: [..._config.tasks, task]));
  }

  Future<void> toggleTask(String id) async => updateConfig(
    _config.copyWith(
      tasks: _config.tasks
          .map(
            (task) => task.id == id
                ? task.copyWith(completed: !task.completed)
                : task,
          )
          .toList(),
    ),
  );

  Future<void> removeTask(String id) async => updateConfig(
    _config.copyWith(
      tasks: _config.tasks.where((task) => task.id != id).toList(),
    ),
  );

  void startFocus() {
    if (!_focusMachine.dispatch(
      FocusStarted(Duration(minutes: _config.focusMinutes)),
    )) {
      return;
    }
    _focusTimer?.cancel();
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_focusMachine.snapshot.phase != FocusPhase.running) return;
      _focusMachine.dispatch(const FocusTicked(Duration(seconds: 1)));
      if (_focusMachine.snapshot.phase == FocusPhase.completed) {
        _focusTimer?.cancel();
        _setStatus('Focus session complete');
        unawaited(_announceFocusCompletion());
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void pauseFocus() {
    if (_focusMachine.dispatch(const FocusPaused())) notifyListeners();
  }

  void resumeFocus() {
    if (_focusMachine.dispatch(const FocusResumed())) notifyListeners();
  }

  void resetFocus() {
    _focusTimer?.cancel();
    if (_focusMachine.dispatch(const FocusReset())) notifyListeners();
  }

  Future<void> testNotification() async {
    final token = _beginLane(OperationLane.desktopNotification);
    if (token == null) return;
    try {
      final allowed = await _notifications.requestPermission().timeout(
        const Duration(seconds: 20),
      );
      if (!allowed) throw StateError('Notification permission was not granted');
      await _notifications.showTest().timeout(const Duration(seconds: 20));
      if (_finishLane(
        OperationLane.desktopNotification,
        token,
        succeeded: true,
      )) {
        _setStatus('Test reminder sent');
      }
    } catch (error) {
      if (_finishLane(
        OperationLane.desktopNotification,
        token,
        succeeded: false,
      )) {
        _setStatus('Test reminder failed: $error');
      }
    }
  }

  Future<void> testCloudNotification() async {
    final token = _beginLane(OperationLane.cloudNotification);
    if (token == null) return;
    final active = session;
    if (active == null) {
      _finishLane(OperationLane.cloudNotification, token, succeeded: false);
      return _setStatus('Sign in before testing cloud reminders');
    }
    try {
      await _cloudReminders.sendTest(active.accessToken);
      if (_finishLane(
        OperationLane.cloudNotification,
        token,
        succeeded: true,
      )) {
        _setStatus('Cloud reminder queued');
      }
    } catch (error) {
      if (_finishLane(
        OperationLane.cloudNotification,
        token,
        succeeded: false,
      )) {
        _setStatus('Cloud reminder failed: $error');
      }
    }
  }

  Future<void> openUri(Uri uri) async {
    if (!{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      return _setStatus('Only valid HTTP and HTTPS links can be opened');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _setStatus('Could not open ${uri.host}');
    }
  }

  Future<void> _syncCloudReminders(String accessToken) async {
    final token = _beginLane(OperationLane.cloudReminderSync);
    if (token == null) return;
    try {
      final result = await _cloudReminders.sync(
        supabaseAccessToken: accessToken,
        events: _calendarEvents,
        settings: _config.reminderSettings,
      );
      if (_finishLane(
        OperationLane.cloudReminderSync,
        token,
        succeeded: true,
      )) {
        _cloudReminderPending = result.pending;
        _setStatus(
          'Calendar and cloud reminders updated: ${result.pending} pending',
        );
      }
    } catch (error) {
      if (_finishLane(
        OperationLane.cloudReminderSync,
        token,
        succeeded: false,
      )) {
        _setStatus('Calendar updated; cloud reminder sync failed: $error');
      }
    }
  }

  void _mirrorOnboarding(OnboardingConfig onboarding) {
    unawaited(
      _runMirror(
        () => _remoteConfig.saveOnboarding(onboarding),
        'Saved locally; onboarding cloud mirror failed',
      ),
    );
  }

  void _mirrorConfig(AppConfig config) {
    unawaited(
      _runMirror(
        () => _remoteConfig.saveConfig(config),
        'Saved locally; settings cloud mirror failed',
      ),
    );
  }

  Future<void> _runMirror(
    Future<void> Function() operation,
    String failureMessage,
  ) async {
    try {
      await operation().timeout(const Duration(seconds: 20));
    } catch (error) {
      if (!_disposed) _setStatus('$failureMessage: $error');
    }
  }

  Future<void> _announceFocusCompletion() async {
    try {
      await _notifications.showTest().timeout(const Duration(seconds: 20));
    } catch (error) {
      if (!_disposed) {
        _setStatus('Focus complete; notification unavailable: $error');
      }
    }
  }

  OperationToken? _beginLane(OperationLane lane) {
    final outcome = _dispatch(LaneRequested(lane));
    if (outcome.token == null) _reject(outcome);
    return outcome.token;
  }

  bool _finishLane(
    OperationLane lane,
    OperationToken token, {
    required bool succeeded,
  }) => _dispatch(
    succeeded ? LaneSucceeded(lane, token) : LaneFailed(lane, token),
  ).committed;

  TransitionOutcome _dispatch(AppEvent event) {
    final outcome = _machine.dispatch(event);
    notifyListeners();
    return outcome;
  }

  void _reject(TransitionOutcome outcome) {
    if (outcome.reason case final reason?) _setStatus(reason.message);
  }

  void _setStatus(String value) {
    _status = value;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    _reactiveState?.publish(
      projectReactiveSnapshot(machine: _machine, status: _status),
    );
    super.notifyListeners();
  }

  OnboardingConfig _mergeOnboarding(
    OnboardingConfig local,
    OnboardingConfig remote,
  ) {
    if (remote.completed && !local.completed) return remote;
    final localTime = local.updatedAt;
    final remoteTime = remote.updatedAt;
    if (remoteTime != null &&
        (localTime == null || remoteTime.isAfter(localTime))) {
      return remote;
    }
    return local;
  }

  @override
  void dispose() {
    _disposed = true;
    _loginTimer?.cancel();
    _focusTimer?.cancel();
    final subscription = _authSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    final reactiveState = _reactiveState;
    if (reactiveState != null) unawaited(reactiveState.close());
    unawaited(_bluetooth.close());
    super.dispose();
  }
}
