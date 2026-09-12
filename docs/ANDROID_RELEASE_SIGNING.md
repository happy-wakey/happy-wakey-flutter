# Android release signing and developer verification

The durable Android identity is `com.happywakey.happy_wakey`. Changing it
creates a different Android application and a different Google developer
verification record.

The authenticated fleet inventory on 2026-09-05 showed this package registered
with one verified certificate fingerprint. That provider record alone does not
prove the fingerprint belongs to the intended production upload key, nor does
it prove current store installation or physical-device acceptance. This change
does not create or retain a production signing key.

## Owner-controlled activation

An authorized owner must identify the registered fingerprint, select or
generate the production upload key, store and back it up through the approved
encrypted secret lifecycle, and confirm its public SHA-256 certificate
fingerprint against Google's current record. Never place private key material
or passwords in Git, issues, pull requests, Linear, workflow logs, or chat.

Create a protected GitHub environment named `mobile-release`, require owner
approval, and configure:

- `HAPPY_WAKEY_ANDROID_KEYSTORE_BASE64`
- `HAPPY_WAKEY_ANDROID_KEYSTORE_PASSWORD`
- `HAPPY_WAKEY_ANDROID_KEY_ALIAS`
- `HAPPY_WAKEY_ANDROID_KEY_PASSWORD`

## Release path

Dispatch `Mobile release candidate` on the exact reviewed ref with a semantic
version and monotonically increasing positive Android build number. The job
first enforces formatting, static analysis, and the complete test suite on that
exact source. It then materializes the upload key only on the ephemeral runner,
builds an obfuscated AAB, verifies its signature, retains bounded provenance/
checksum/symbol evidence, and destroys the materialized key in an always-run
step.

Any Gradle release task fails before building unless all four
`HAPPY_WAKEY_ANDROID_*` signing values are present and the keystore path
identifies a real file. Development and test tasks do not require signing
material, and release builds never fall back to the Android debug certificate.

The retained AAB is a release candidate, not store or device evidence. Record
Google fingerprint read-back, exact artifact upload/install, and physical
device acceptance separately before declaring production readiness.
