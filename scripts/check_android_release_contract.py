#!/usr/bin/env python3
"""Fail closed when Happy Wakey's Android release contract is weakened."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GRADLE = ROOT / "android" / "app" / "build.gradle.kts"
GITIGNORE = ROOT / "android" / ".gitignore"
WORKFLOW = ROOT / ".github" / "workflows" / "mobile-release.yml"
VALIDATE = ROOT / ".github" / "workflows" / "validate.yml"

PACKAGE_ID = "com.happywakey.happy_wakey"
SIGNING_ENV = (
    "HAPPY_WAKEY_ANDROID_KEYSTORE_PATH",
    "HAPPY_WAKEY_ANDROID_KEYSTORE_PASSWORD",
    "HAPPY_WAKEY_ANDROID_KEY_ALIAS",
    "HAPPY_WAKEY_ANDROID_KEY_PASSWORD",
)
WORKFLOW_SECRETS = (
    "HAPPY_WAKEY_ANDROID_KEYSTORE_BASE64",
    "HAPPY_WAKEY_ANDROID_KEYSTORE_PASSWORD",
    "HAPPY_WAKEY_ANDROID_KEY_ALIAS",
    "HAPPY_WAKEY_ANDROID_KEY_PASSWORD",
)


def require(text: str, marker: str, source: Path) -> None:
    if marker not in text:
        raise SystemExit(
            f"{source.relative_to(ROOT)} is missing required marker: {marker}"
        )


def main() -> None:
    gradle = GRADLE.read_text(encoding="utf-8")
    gitignore = GITIGNORE.read_text(encoding="utf-8")
    workflow = WORKFLOW.read_text(encoding="utf-8")
    validate = VALIDATE.read_text(encoding="utf-8")

    require(gradle, f'applicationId = "{PACKAGE_ID}"', GRADLE)
    require(gradle, "releaseTaskRequested", GRADLE)
    require(gradle, "providers.environmentVariable(name)", GRADLE)
    require(gradle, "keystoreFile.isFile", GRADLE)
    require(gradle, 'create("release")', GRADLE)
    require(gradle, 'signingConfigs.getByName("release")', GRADLE)
    for name in SIGNING_ENV:
        require(gradle, name, GRADLE)

    if re.search(r'signingConfigs\.getByName\(["\']debug["\']\)', gradle):
        raise SystemExit("release builds must never use the Android debug signing config")

    for pattern in ("**/*.keystore", "**/*.jks", "**/*.p12", "**/*.pfx"):
        require(gitignore, pattern, GITIGNORE)

    require(workflow, "workflow_dispatch:", WORKFLOW)
    require(workflow, "permissions:\n  contents: read", WORKFLOW)
    require(workflow, "environment: mobile-release", WORKFLOW)
    require(workflow, "needs: [guards, quality]", WORKFLOW)
    require(workflow, "persist-credentials: false", WORKFLOW)
    require(workflow, "dart format --output=none --set-exit-if-changed .", WORKFLOW)
    require(workflow, "flutter analyze --fatal-infos", WORKFLOW)
    require(workflow, "flutter test", WORKFLOW)
    require(workflow, "flutter build appbundle --release --no-pub", WORKFLOW)
    require(workflow, "jarsigner -verify", WORKFLOW)
    require(workflow, "git rev-parse HEAD", WORKFLOW)
    require(workflow, "checksums.sha256", WORKFLOW)
    require(workflow, "if-no-files-found: error", WORKFLOW)
    require(workflow, "if: always()", WORKFLOW)
    for name in WORKFLOW_SECRETS:
        require(workflow, name, WORKFLOW)

    if "pull_request_target:" in workflow:
        raise SystemExit("the release workflow must not run in pull_request_target context")

    unpinned_actions = re.findall(
        r"^\s*-?\s*uses:\s+[^\s@]+@(?![0-9a-f]{40}(?:\s|$))([^\s#]+)",
        workflow,
        re.MULTILINE,
    )
    if unpinned_actions:
        raise SystemExit(
            f"release workflow actions must be pinned to full commits: {unpinned_actions}"
        )

    require(validate, "command: flutter build apk --debug", VALIDATE)
    if "command: flutter build apk --release" in validate:
        raise SystemExit("untrusted validation jobs must not emit debug-signed release APKs")

    print(f"Android release contract is fail-closed for {PACKAGE_ID}.")


if __name__ == "__main__":
    main()
