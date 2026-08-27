# AGENTS.md — happy-wakey/happy-wakey-flutter

## Parent / root agent contract

This file is **this repository's** agent contract. The fleet-wide parent lives at:

- GitHub: https://github.com/oresoftware/my-ai/AGENTS.md
- Disk: `~/codes/oresoftware/my-ai/AGENTS.md`
- Installed by `~/codes/oresoftware/my-ai/setup-final.sh` (not `.md`) as a symlink onto `~/codes/AGENTS.md`

When this file and the parent disagree: follow **this file** for Flutter tools,
desktop destinations, BLE, and URL safety; follow the parent for org-wide
git/Linear/GitHub/k8s/shared-auth/opto-sync/ores-otel/zed-pkg conventions.

The mapping is 1:1:1:1 — GitHub org : Linear project : GitHub org project
(usually `https://github.com/orgs/<org>/projects/1`) : Slack channel in
`oresoftware-workspace.slack.com`. Linear workspace: https://linear.app/denman
Primary GitHub user: `ORESoftware`. Secondary: `the1mills`.

## This repository

- GitHub org: [`happy-wakey`](https://github.com/happy-wakey)
- Repository: [`happy-wakey/happy-wakey-flutter`](https://github.com/happy-wakey/happy-wakey-flutter)
- Local checkout: `~/codes/happy-wakey/happy-wakey-flutter`
- Linear project: https://linear.app/denman/project/githubcomhappy-wakey-f3b3dba8b195
- GitHub org project: https://github.com/orgs/happy-wakey/projects/1
- Sibling test org: `github.com/happy-wakey-test`
- Kind: Flutter client for mobile, desktop, and web. Desktop destinations must
  stay in parity with `happy-wakey/happy-wakey-desktop-app.rs`.
- Canonical Qt desktop app: `happy-wakey/happy-wakey-desktop-app.rs` (not the
  legacy `happy-wakey.rs` duplicate).
- e2e contract: `happy-wakey/happy-wakey-e2e` (`contracts/desktop-parity.json`)
  plus `happy-wakey-test/desktop-feature-parity-e2e`.

## Safety

- Do not ship a default platform IP or any baked-in public numeric host.
- Platform, shared-auth, and gateway URLs fail closed when unset. HTTPS only
  except loopback HTTP. Reject numeric IP hosts except loopback.
- Bookmarks persist `https` (or loopback `http`) only. Drop `javascript:`,
  `file:`, and other schemes.
- BLE preview commands are credential-free JSON bounded at 512 bytes. Never put
  tokens, subject, or owner_id on the radio.
- Dart defines are client-visible. Do not treat Finnhub/NewsAPI keys as secrets.
- Git: merge, never rebase/stash/reset unless a human explicitly authorizes.

## Code style and coding patterns

remember to modularize the rust, typescript and dart - not everything belongs in main.rs, main.ts and main.dart; also follow functional coding principles - fewer side-effects (use pure functions more), more immutability (immutable variables); but for stateful apps like the client or stateful servers like websockets or tcp connections, sometimes classes and oop make more sense than functional programming perse, but we can still adhere to functional programming more than usual. Favor exhaustive pattern matching and use formal methods checking too. Favor composability and re-use , so basically create more utility functions and routines for shared use. You can follow a medium level of D.R.Y. (don't repeat yourself) - in other words you can repeat yourself at medium amount (not too much not too little). Some chaining is totally fine, so either method-chaining (immutable sometimes although with classes can be mutable too for performance), and chaining via the pipe operator is ok in languages like gleamlang.

Functional programming is mostly the following:

+ explicit inputs
+ explicit outputs
+ immutable values
+ pure transformations
+ typed errors
+ explicit state transitions
+ composition
+ effects pushed outward
+ illegal states excluded by types

## Required validation

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```
