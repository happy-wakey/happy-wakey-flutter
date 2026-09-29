# Android release signing gate

Production Android artifacts must never fall back to debug signing.

## Required behavior

- `release`/AAB builds require an explicitly configured production signing identity and fail before packaging when it is unavailable.
- Debug/profile builds may continue to use development signing without changing developer ergonomics.
- Keystore bytes, passwords, aliases, signing fingerprints, and CI credentials remain outside source and logs; protected CI/environment secrets provide them at build time.
- A static repository check must reject `release` build types that reference the debug signing config or silently inherit it.
- The protected release workflow must build an AAB, inspect its signing certificate fingerprint, and compare it to the expected protected production fingerprint before upload/promotion.
- Internal-track/canary promotion is required before any production-release claim.

## Evidence

Exact-head evidence should distinguish repository policy, successful unsigned/debug developer builds, production-signed bundle creation, certificate verification, and store/internal-track acceptance. Zero-step CI or missing protected signing material is non-evidence, not a pass.

Tracking: #10.