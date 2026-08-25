# Architecture

Happy Wakey uses a functional-core/imperative-shell design. Control state is a
small, total transition system; platform integrations sit outside it.

## Control plane

`lib/src/core/app_state.dart` owns readiness, authentication, onboarding, and
nine effect lanes. Its mutable fields are private. `dispatch` copies the
machine, applies one event to the candidate, validates all invariants, and only
then replaces the live state. Unsupported requests are explicit rejections and
late completions are explicit stale stutters.

`AppController` is the only UI-facing orchestrator. It:

1. asks the machine to begin an operation;
2. starts the external effect only after acceptance;
3. retains the returned generation token;
4. receives success or failure from the environment; and
5. commits data only if the matching completion is still accepted.

This ordering matters. A callback that races with logout or a later request
cannot mutate lists first and discover afterward that it was stale.

The focus timer has a separate, total `FocusMachine`; its permitted edges are
idle → running ↔ paused → completed, with reset from every phase.

## Data plane

- `ConfigStore` persists a sanitized JSON document through
  `shared_preferences` on every Flutter platform.
- `SupabaseConfigService` optionally mirrors only preference and onboarding
  documents protected by the authenticated user ID and backend RLS.
- OAuth sessions stay in Supabase's session storage and are never serialized by
  `AppConfig`.
- `ApiClient` permits HTTPS and loopback HTTP only, applies timeouts, bounds
  response bodies to 2 MiB, bounds error text, and rejects malformed JSON.
- Provider services normalize remote objects into immutable app models before
  they reach widgets.
- Links permit only HTTP and HTTPS and open in the system browser.
- `UniversalHappyWakeyBluetoothService` scans only the Happy Wakey service UUID,
  validates the product service and writable command characteristic after
  connection, and sends only bounded credential-free command envelopes.

## Failure semantics

There is no global “loading” boolean and no untyped error state. Each operation
lane is independently `idle`, `running`, `ready`, or `failed`. One provider can
fail without erasing another lane's valid result. A visible status region
announces the latest controlled outcome.

Optional integrations do not prevent startup. Missing configuration rejects
the affected operation with a bounded explanation. Existing successful data is
retained when a refresh fails.

## Trust boundaries

The client is not a secret vault. Supabase publishable credentials are intended
for public clients and require RLS. Any other Dart define is embedded in the
compiled application; production news/market credentials should be replaced by
a backend proxy with authentication, quotas, and provider-specific policy.

Formal verification covers the state transition abstraction, not plugin or
remote-service correctness. CI therefore couples proof checks with native Dart
tests and native-host compilation for all six platform targets.
