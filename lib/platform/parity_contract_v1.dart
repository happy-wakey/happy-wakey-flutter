/// Shared feature-parity contract with
/// `happy-wakey/happy-wakey-desktop-app.rs` and the canonical e2e manifest.
/// Native Qt/Flutter, BLE, notification, and lifecycle behavior belongs only
/// in [AppPlatformAdapter]; product state and destinations remain portable.
const int crossPlatformParityContractVersion = 1;
const String rustDesktopCounterpart =
    'happy-wakey/happy-wakey-desktop-app.rs';
const String e2eParityContract =
    'happy-wakey/happy-wakey-e2e/contracts/desktop-parity.json';
enum AppSurface { mobile, flutterDesktop, rustDesktop }
enum AppCapability {
  authentication, home, calendar, weather, markets, news, planner, focus,
  devices, safeBrowserNavigation, settings, reminders, blePreviewCommands,
  deepLinks, secureStorage, offlineCache, backgroundSync, notifications,
  telemetry, accessibility, applicationUpdates,
}
const Set<AppCapability> requiredParityCapabilities = <AppCapability>{
  AppCapability.authentication, AppCapability.home, AppCapability.calendar,
  AppCapability.weather, AppCapability.markets, AppCapability.news,
  AppCapability.planner, AppCapability.focus, AppCapability.devices,
  AppCapability.safeBrowserNavigation, AppCapability.settings,
  AppCapability.reminders, AppCapability.blePreviewCommands,
  AppCapability.deepLinks, AppCapability.secureStorage,
  AppCapability.offlineCache, AppCapability.backgroundSync,
  AppCapability.notifications, AppCapability.telemetry,
  AppCapability.accessibility, AppCapability.applicationUpdates,
};
abstract class AppPlatformAdapter {
  const AppPlatformAdapter();
  AppSurface get surface;
  bool supports(AppCapability capability);
}
void verifyRequiredParityCapabilities(AppPlatformAdapter adapter) {
  final missing = requiredParityCapabilities
      .where((capability) => !adapter.supports(capability)).toList();
  if (missing.isNotEmpty) {
    throw StateError('Happy Wakey parity gate failed for ${adapter.surface}: $missing');
  }
}
