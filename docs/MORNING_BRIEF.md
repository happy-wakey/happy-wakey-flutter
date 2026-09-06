# Morning brief parity contract

Happy Wakey is a local-first morning command center, not a replacement for
every provider. The parity target is the set of small, high-signal moments that
make fifteen popular planning, communication, and health products useful before
the workday starts:

| Reference product | Signal we borrow | Happy Wakey surface |
| --- | --- | --- |
| Structured | time-blocked day view | Calendar and Daily planner |
| Sunsama | intentional daily planning | Daily planner and focus |
| Motion | agenda pressure and priorities | Calendar agenda and important mail |
| Morgen | multi-calendar command center | Google/Microsoft calendar normalization |
| Notion Calendar | meeting context and join links | Calendar event cards |
| Google Calendar | reliable agenda source | Read-only Google Calendar |
| Microsoft Outlook | work agenda and mail together | Read-only Graph calendar and inbox |
| Gmail | important unread mail triage | Read-only Gmail inbox |
| Slack | work DM attention | Platform direct-message gateway |
| Discord | community DM attention | Platform direct-message gateway |
| Microsoft Teams | work chat attention | Platform direct-message gateway |
| Beeper | unified social conversations | Platform direct-message gateway |
| Apple Health | sleep and activity results | HealthKit read-only adapter |
| Google Health Connect | Android health aggregation | Health Connect read-only adapter |
| Oura | sleep stages and recovery context | Sleep stages and local health metrics |

The goal is not to clone provider UIs. Each provider contributes a bounded,
read-only signal to one calm screen, with a visible source and an explicit
consent boundary. A missing provider, revoked grant, unsupported platform, or
empty result is rendered as an honest empty state.

## Current contract

The `Morning brief` destination presents four summary cards and three detail
sections:

1. Important unread email from Gmail or Microsoft Graph. The client requests
   `gmail.readonly`/`Mail.Read`, fetches at most 20 recent messages, ranks
   unread and provider-important messages, and never marks, moves, deletes, or
   sends mail.
2. Direct messages from the optional Happy Wakey platform gateway. The gateway
   owns provider OAuth and consent for Slack, Discord, Teams, and other
   approved sources. The Flutter client sends only the short-lived Supabase
   bearer to `GET /v1/messages/digest`, flattens the canonical per-platform
   threads, and accepts at most 20 bounded records.
3. Sleep and biometrics from Apple HealthKit or Google Health Connect. Read
   access is requested on demand. Sleep duration/stages, steps, active energy,
   heart rate, resting heart rate, and blood oxygen are aggregated in memory;
   raw health records are discarded and never enter the sync document.

All three refreshes have independent operation lanes. A provider failure cannot
erase a successful calendar, weather, market, or health result, and logout
clears all account-backed mail and message data. Links are opened only after
the HTTP(S)-only URL guard.

## Transport contract

Provider adapters are deliberately independent from the web/API transport
choice. The Rust web/API pair exposes the same authenticated operation through
the four fleet avenues described in
[`happy-wakey-api-server.rs/docs/four-transports.md`](https://github.com/happy-wakey/happy-wakey-api-server.rs/blob/main/docs/four-transports.md):

| Avenue | Safe use in the morning brief |
| --- | --- |
| Direct database read | Read-only projections needed for a critical page path |
| Stateless HTTPS | Default for bounded reads and every mutation |
| Stateful TLS/TCP | Chatty internal calls where connection setup dominates |
| NATS/JetStream | Async fan-in or work that does not block first paint |

Every avenue carries the same versioned envelope and re-checks the bearer at
the operation boundary. The Flutter direct-message adapter currently uses the
stateless gateway endpoint; moving that fan-in behind the API server does not
change the client contract.

## Deliberate non-goals

- No automatic social-provider scraping or collection of provider passwords.
- No health writes, background health uploads, or raw biometric persistence.
- No unbounded provider response, body, preview, or URL is admitted to the UI.
- No claim that a CI compile is equivalent to store review or a physical-device
  permission test; those remain release acceptance work.
