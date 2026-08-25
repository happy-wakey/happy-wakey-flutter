# Formal application-state verification

`app_state.qnt` is the language-neutral control-state contract shared with the
Rust desktop application. The copy in this repository is byte-identical to the
desktop model. `lib/src/core/app_state.dart` is the independent Flutter/Dart
implementation and `test/core/app_state_test.dart` is its native conformance
and bounded reachable-state gate.

## State ownership

The machine is the sole owner of:

- application readiness (`booting`, `ready`);
- authentication (`signedOut`, `authenticating`, `signedIn`, `failed`);
- onboarding (`welcome`, `account`, `backup`, `essentials`, `ready`,
  `complete`); and
- calendar, weather, stocks, news, Bluetooth device operations, onboarding
  hydration, desktop/local notifications, cloud notifications, and
  cloud-reminder synchronization.

Widgets request typed events and render snapshots. They never mutate control
state directly. Every asynchronous operation that can update modeled state gets
a monotonically increasing token. Its result can commit only while that exact
token is active in the same running lane.

Every input has one explicit disposition:

- `applied`: a candidate state passed every invariant and committed atomically;
- `stale`: an obsolete completion deliberately stuttered; or
- `rejected`: an invalid request failed closed without changing state.

Logout clears every authenticated lane. Consequently, a late OAuth, calendar,
onboarding-hydration, cloud-notification, or cloud-reminder result cannot
resurrect a session or overwrite later state.

## Checked safety properties

`app_state_safety` generates 21 verification conditions covering:

1. finite app, auth, onboarding, lane, token, and generation domains;
2. exact auth phase/token coherence;
3. one current token for every running lane;
4. token/generation coherence and global generation bounds;
5. authentication requirements for protected lanes;
6. absence of running effects before startup completes; and
7. irreversible onboarding completion.

The completion witness makes the final property a state invariant. Once set,
any future transition away from `complete` immediately violates the model.

The Dart test suite separately explores the reachable graph from all twelve
valid persisted auth/onboarding combinations through four transition layers.
For every modeled event, provider, lane, completion token, and reconciliation
step, it checks totality, determinism, stuttering for non-committed outcomes,
and post-transition invariants.

## Reproduce the checks

The checker version is pinned as part of the proof input:

```bash
QUINT_PACKAGE='@informalsystems/quint@0.32.0'

npx --yes --package="$QUINT_PACKAGE" quint typecheck formal/app_state.qnt
npx --yes --package="$QUINT_PACKAGE" quint typecheck formal/app_state_test.qnt
npx --yes --package="$QUINT_PACKAGE" quint test \
  formal/app_state_test.qnt --main=app_state_test --match='.*Test$'
npx --yes --package="$QUINT_PACKAGE" quint run \
  formal/app_state.qnt --main=app_state \
  --max-samples=10000 --max-steps=24 \
  --invariant=app_state_safety
npx --yes --package="$QUINT_PACKAGE" quint verify \
  formal/app_state.qnt --main=app_state \
  --max-steps=4 --invariant=app_state_safety
flutter test test/core/app_state_test.dart
```

The current exact source hashes are:

```text
b47b95f89a8ac5ecaa14a9be2a5087a38d5eb425304b4943a4ce03c6a38625cc  formal/app_state.qnt
caf225d4eddb00a9557d4a1f1dff9133142d190820c7d500f4b48c3564152d9f  formal/app_state_test.qnt
```

CI records fresh SHA-256 provenance for the model, traces, Dart kernel,
controller, and native conformance tests on every run.

## Proof boundary

This is a safety proof for the declared finite abstraction and checked bounds,
plus bounded exhaustive testing of the production transition kernel. It proves
that accepted modeled transitions preserve the declared invariants. It does not
prove that operating systems, OAuth providers, networks, notification services,
filesystems, clocks, native plugins, or hardware cannot fail.

Those systems are environmental inputs. Their outcomes must re-enter through a
token-checked completion and become a controlled success, failure, rejection,
or stale stutter. Service correctness, credential policy, remote durability,
and app-store behavior remain separate acceptance obligations.
