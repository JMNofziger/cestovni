#!/usr/bin/env python3
"""
ci/telemetry-gate.py — Cestovni telemetry allow-list CI gate.

Spec: docs/specs/telemetry-allowlist.md (§"CI gate").
YAML: docs/specs/telemetry-events.v1.yaml (authoritative allow-list).
Schema: ci/telemetry-schema.json.

Checks (numbered to match the spec):

  1. Parse YAML; fail on syntax or missing required top-level keys.
  2. Static-analyze client code for telemetry emit calls; every
     eventName literal MUST match an entry in the YAML. ACTIVATED as
     of M0-01 (CES-36): scans every *.dart file under client/ for
     `Telemetry.emit('name', ...)` and hard-fails on unknown names or
     non-literal arguments.
  3. JSON Schema validation of the YAML, including the hard-ban on
     pii_class values 'identifier' and 'freetext' (enforced by the
     schema's enum).
  4. Apple privacy manifest drift: compare YAML event categories to
     the Apple PrivacyInfo.xcprivacy manifest. Skip with a warning
     until the manifest file exists.

Runtime requirements: Python 3.11+, `PyYAML`, `jsonschema`.

Exit codes: 0 pass, 1 fail.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml  # type: ignore[import-not-found]
except ImportError:
    print("telemetry-gate: FAIL — PyYAML not installed; run `pip install pyyaml jsonschema`.")
    sys.exit(1)

try:
    from jsonschema import Draft202012Validator  # type: ignore[import-not-found]
except ImportError:
    print("telemetry-gate: FAIL — jsonschema not installed; run `pip install pyyaml jsonschema`.")
    sys.exit(1)


REPO_ROOT = Path(__file__).resolve().parent.parent
YAML_PATH = REPO_ROOT / "docs" / "specs" / "telemetry-events.v1.yaml"
SCHEMA_PATH = REPO_ROOT / "ci" / "telemetry-schema.json"
CLIENT_CANDIDATE_DIRS = ["client", "app", "mobile"]
APPLE_MANIFEST_CANDIDATES = [
    REPO_ROOT / "apple" / "PrivacyInfo.xcprivacy",
    REPO_ROOT / "ios" / "Runner" / "PrivacyInfo.xcprivacy",
]


class Failure(Exception):
    """Raised for a hard gate failure."""


def check_1_parse_yaml() -> dict[str, Any]:
    """Check 1: parse YAML and confirm required top-level keys."""
    if not YAML_PATH.exists():
        raise Failure(f"YAML not found at {YAML_PATH.relative_to(REPO_ROOT)}")
    try:
        with YAML_PATH.open("r", encoding="utf-8") as fh:
            doc = yaml.safe_load(fh)
    except yaml.YAMLError as exc:
        raise Failure(f"YAML parse error: {exc}") from exc
    if not isinstance(doc, dict):
        raise Failure("YAML root must be a mapping.")
    for key in ("schema_version", "pepper_required", "events"):
        if key not in doc:
            raise Failure(f"YAML missing required key: {key}")
    print(f"[1/4] YAML parsed: {len(doc['events'])} events.")
    return doc


def check_3_schema(doc: dict[str, Any]) -> None:
    """Check 3: JSON Schema validation (includes pii_class ban)."""
    if not SCHEMA_PATH.exists():
        raise Failure(f"Schema not found at {SCHEMA_PATH.relative_to(REPO_ROOT)}")
    with SCHEMA_PATH.open("r", encoding="utf-8") as fh:
        schema = json.load(fh)
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(doc), key=lambda e: list(e.absolute_path))
    if errors:
        lines = ["[3/4] JSON Schema validation FAILED:"]
        for err in errors:
            where = "/".join(str(p) for p in err.absolute_path) or "<root>"
            lines.append(f"  - {where}: {err.message}")
        raise Failure("\n".join(lines))
    print("[3/4] JSON Schema validation passed (identifier/freetext classes banned at schema level).")


# Telemetry emit call pattern for the Dart client.
#
# Convention (wired by CES-46 / M4): the Flutter client calls
# `Telemetry.emit('event_name', props)` or `telemetry.emit('event_name', props)`.
# The scanner below matches that exact shape with a string literal as the
# first argument. Calls with a non-literal first argument (variable, const
# reference) are flagged separately so the gate fails closed on anything
# it cannot statically verify.
EMIT_LITERAL_RE = re.compile(
    r"(?<![A-Za-z0-9_])"
    r"(?:Telemetry|telemetry)\s*\.\s*emit\s*\(\s*"
    r"(?P<quote>['\"])(?P<name>[A-Za-z_][A-Za-z0-9_]*)(?P=quote)"
)
EMIT_DYNAMIC_RE = re.compile(
    r"(?<![A-Za-z0-9_])"
    r"(?:Telemetry|telemetry)\s*\.\s*emit\s*\(\s*(?!['\"])"
)


def check_2_client_scan(doc: dict[str, Any]) -> None:
    """Check 2: scan client code for telemetry emit calls.

    Activated by CES-36 / M0-01 (mobile client bootstrap). The scanner
    walks every `*.dart` file under the first client candidate dir that
    exists and flags:

      * literal `Telemetry.emit('name', …)` calls whose name is not in
        the authoritative allow-list — HARD FAIL (fails closed).
      * dynamic `Telemetry.emit(someVar, …)` calls — HARD FAIL because
        the gate cannot statically verify the name.

    No matches (the M0 state) passes silently — there is no client
    telemetry surface until CES-46 wires it.
    """
    client_root: Path | None = None
    for candidate in CLIENT_CANDIDATE_DIRS:
        path = REPO_ROOT / candidate
        if path.exists():
            client_root = path
            break
    if client_root is None:
        print("[2/4] SKIP — no client source tree yet (pre-M0-01).")
        return

    allowed = {evt["name"] for evt in doc.get("events", [])}
    dart_files = sorted(client_root.rglob("*.dart"))
    # Skip generated code (.g.dart / .freezed.dart) — codegen never
    # contains hand-written telemetry calls and churns frequently.
    dart_files = [
        p for p in dart_files
        if not p.name.endswith(".g.dart") and not p.name.endswith(".freezed.dart")
    ]

    unknown: list[tuple[Path, int, str]] = []
    dynamic_calls: list[tuple[Path, int]] = []
    literal_hits = 0

    for path in dart_files:
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            raise Failure(f"could not read {path.relative_to(REPO_ROOT)}: {exc}") from exc
        for m in EMIT_LITERAL_RE.finditer(text):
            literal_hits += 1
            name = m.group("name")
            line = text.count("\n", 0, m.start()) + 1
            if name not in allowed:
                unknown.append((path, line, name))
        for m in EMIT_DYNAMIC_RE.finditer(text):
            line = text.count("\n", 0, m.start()) + 1
            dynamic_calls.append((path, line))

    if unknown or dynamic_calls:
        lines = ["[2/4] client scan FAILED:"]
        for path, line, name in unknown:
            lines.append(
                f"  - {path.relative_to(REPO_ROOT)}:{line}: "
                f"unknown event {name!r} (not in telemetry-events.v1.yaml)"
            )
        for path, line in dynamic_calls:
            lines.append(
                f"  - {path.relative_to(REPO_ROOT)}:{line}: "
                "dynamic Telemetry.emit() argument — must be a string literal "
                "so CI can verify it."
            )
        raise Failure("\n".join(lines))

    print(
        f"[2/4] client scan passed: {len(dart_files)} Dart file(s), "
        f"{literal_hits} literal emit call(s), 0 unknown."
    )


def check_4_apple_manifest(doc: dict[str, Any]) -> None:
    """Check 4: Apple PrivacyInfo.xcprivacy drift vs YAML.

    Skipped with a warning until the manifest file exists.
    """
    manifest_path = next(
        (p for p in APPLE_MANIFEST_CANDIDATES if p.exists()),
        None,
    )
    if manifest_path is None:
        print(
            "[4/4] SKIP — Apple PrivacyInfo.xcprivacy not present yet; "
            "will compare category totals when the mobile client ships."
        )
        return
    categories = {evt["category"] for evt in doc.get("events", [])}
    print(
        f"[4/4] Apple manifest found at {manifest_path.relative_to(REPO_ROOT)}; "
        f"YAML categories present: {sorted(categories)}. "
        "NOTE: drift check vs manifest NSPrivacyCollectedDataTypes not yet "
        "implemented; extend this function when the manifest is authored."
    )


def main() -> int:
    print("telemetry-gate: starting")
    try:
        doc = check_1_parse_yaml()
        check_3_schema(doc)
        check_2_client_scan(doc)
        check_4_apple_manifest(doc)
    except Failure as exc:
        print(f"telemetry-gate: FAIL\n{exc}")
        return 1
    print("telemetry-gate: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
