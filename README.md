# Happy Wakey for Flutter

[![Validate](https://github.com/happy-wakey/happy-wakey-flutter/actions/workflows/validate.yml/badge.svg)](https://github.com/happy-wakey/happy-wakey-flutter/actions/workflows/validate.yml)
[![Formal methods](https://github.com/happy-wakey/happy-wakey-flutter/actions/workflows/formal-methods.yml/badge.svg)](https://github.com/happy-wakey/happy-wakey-flutter/actions/workflows/formal-methods.yml)

Happy Wakey is a local-first daily command center for phones, tablets,
desktops, and the web. This repository is the Flutter sibling of
[`happy-wakey.rs`](https://github.com/happy-wakey/happy-wakey.rs): it carries
forward the desktop app's calendar, weather, markets, news, links, OAuth,
settings sync, and reminder features while adding an adaptive mobile UI, a
daily planner, a focus timer, browser/PWA support, and visible formal-state
diagnostics.

The app is not merely “written in Flutter.” Android, iOS, Linux, macOS,
Windows, and web runners are checked in, and CI builds every platform family on
its native host.

## What is included

- Google, Apple, and Microsoft identity through optional Supabase OAuth.
- Read-only Google Calendar and Microsoft Graph calendar normalization.
- Today/weekly agenda summaries, meeting load, overlap detection, join links,
  local reminders, and optional shared-auth cloud reminders.
- Live Open-Meteo conditions and five-day forecasts.
- Finnhub watchlist quotes and NewsAPI headlines with bounded, validated
  responses and local keyword enforcement.
- Persistent local preferences, onboarding, bookmarks, planner tasks, and a
  guarded pause/resume focus timer.
- Material 3 layouts that move between a navigation drawer on mobile and a
  navigation rail on larger screens.
- A single private application state machine with fail-closed transitions,
  monotonic operation tokens, stale-callback fencing, and runtime invariants.
- The byte-identical Quint contract shared with the Rust desktop app,
  deterministic conformance traces, randomized traces, bounded model checking,
  and a native Dart reachable-state explorer.

## Run locally

Install Flutter 3.44.2 or a compatible stable release, then:

```bash
flutter pub get
flutter run
```

Choose a platform explicitly with `-d chrome`, `-d macos`, an Android device,
an iOS simulator, or another device reported by `flutter devices`.

Optional integrations are supplied with Dart defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=FINNHUB_API_KEY=LOCAL_DEVELOPMENT_KEY \
  --dart-define=NEWS_API_KEY=LOCAL_DEVELOPMENT_KEY \
  --dart-define=HAPPY_WAKEY_PLATFORM_URL=https://platform.example.com
```

Available service defines are documented in
[`docs/CONFIGURATION.md`](docs/CONFIGURATION.md). A Supabase publishable key is
intended for client use and must be protected with RLS. Other provider API keys
compiled into a mobile, desktop, or web client can be extracted; production
deployments should route those APIs through a rate-limited backend instead of
treating Dart defines as a secret store.

Without any defines, onboarding, planner, focus, bookmarks, persistence, and
Open-Meteo weather remain usable. Optional features fail closed with a visible
status instead of inventing data or entering an implicit state.

## Validate

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter build web --release
flutter build macos --release
flutter build ios --release --no-codesign
flutter build apk --release
```

The complete cross-platform matrix is in
[`validate.yml`](.github/workflows/validate.yml). Formal verification commands,
properties, assumptions, and the proof boundary are in
[`formal/README.md`](formal/README.md).

## Architecture

`AppMachine` is the sole authority for application readiness,
authentication, onboarding, and eight asynchronous operation lanes. Widgets
render snapshots and send typed events. `AppController` performs platform and
network effects, but results can commit only through the machine with their
original operation token.

```text
Widget intent
    │
    ▼
AppController ── event ──▶ AppMachine ── validated disposition
    │                           │
    ├── starts effect only      └── applied / stale / rejected
    │   after acceptance
    ▼
Platform or network result ── token-checked completion ──▶ AppMachine
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for ownership and data-flow
details, and [`docs/PLATFORM_SUPPORT.md`](docs/PLATFORM_SUPPORT.md) for the
per-platform acceptance surface and packaging boundaries.
