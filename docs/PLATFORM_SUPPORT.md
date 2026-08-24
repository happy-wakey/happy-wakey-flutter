# Platform support

| Platform | Runner | Navigation | Persistence | OAuth callback | Local notifications | CI compile |
| --- | --- | --- | --- | --- | --- | --- |
| Android | Native Flutter activity | Drawer/adaptive | SharedPreferences | Custom intent URI | Yes | Ubuntu |
| iOS | Native UIKit/Flutter runner | Drawer/adaptive | NSUserDefaults | Custom URL scheme | Yes | macOS, no codesign |
| Linux | Native GTK runner | Rail/adaptive | XDG-backed preferences | Custom scheme support in app-links; desktop registration is a packaging step | Yes, notification-server dependent | Ubuntu |
| macOS | Sandboxed native runner | Rail/adaptive | NSUserDefaults | Custom URL scheme | Yes | macOS |
| Windows | Native Win32 runner | Rail/adaptive | Windows preferences backend | app-links forwarding; protocol registration is an installer step | Yes | Windows |
| Web | PWA/WebAssembly-capable Flutter target | Responsive drawer/rail | Browser local storage | Current origin | Browser permission and service-worker dependent | Ubuntu |

“CI compile” means the source compiles on a native hosted runner. It is not a
claim of store acceptance, signing, packaging, physical-device behavior, or
notification delivery. Those require separately provisioned acceptance runs.

The checked-in mobile URL scheme is `com.happywakey.app`; the Android and Apple
runners are configured directly. Linux desktop files and Windows installer
protocol entries are distribution artifacts and must register the same scheme
when packages are produced.

Android uses inexact calendar alarms and declares reboot rescheduling support.
iOS retains at most 64 pending local notifications; the scheduler intentionally
uses the same bound across platforms. Browser notification support depends on a
secure origin and user permission.
