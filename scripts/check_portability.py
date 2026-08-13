#!/usr/bin/env python3
"""Reject source-org fragments from the portable Jira Agentforce package."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {
    ".agent",
    ".apex",
    ".cls",
    ".css",
    ".html",
    ".js",
    ".json",
    ".md",
    ".py",
    ".xml",
    ".yml",
    ".yaml",
}
EXCLUDED_FILES = {
    "docs/portable-jira-agentforce-spec.md",
    "scripts/check_portability.py",
}
FORBIDDEN_PATH_PARTS = {
    ".sfdx",
    "bots",
    "botVersions",
    "externalServiceRegistrations",
    "flows",
    "genAiFunctions",
    "genAiPlannerBundles",
    "genAiPlugins",
}
FORBIDDEN_LITERALS = {
    "hendrixindustries",
    "lokilutions",
    "ITSM Org 2",
    "JiraV21Jira_SM",
    "ARFPC_",
    "rag_feature_config_id:",
    "connection slack:",
    "Danny Smith",
    "Julia Anderson",
    "Scott Hendrix",
    "trailsignup.",
    "712020:",
    "shendrix",
}


def tracked_files() -> list[Path]:
    completed = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [Path(line) for line in completed.stdout.splitlines() if line]


def main() -> int:
    violations: list[str] = []

    for relative_path in tracked_files():
        path_text = relative_path.as_posix()
        absolute_path = ROOT / relative_path
        if not absolute_path.exists():
            continue
        if any(part in FORBIDDEN_PATH_PARTS for part in relative_path.parts):
            violations.append(f"{path_text}: generated or legacy metadata path is tracked")
            continue
        if path_text in EXCLUDED_FILES or relative_path.suffix not in TEXT_SUFFIXES:
            continue

        content = absolute_path.read_text(encoding="utf-8", errors="ignore")
        lowered = content.lower()

        for literal in FORBIDDEN_LITERALS:
            if literal.lower() in lowered:
                violations.append(f"{path_text}: contains source-org fragment {literal!r}")

        for host in re.findall(r"https://([a-z0-9-]+)\.atlassian\.net", content, flags=re.IGNORECASE):
            if host.lower() != "example":
                violations.append(f"{path_text}: contains Jira site URL for {host}.atlassian.net")

        if not relative_path.name.endswith("Test.cls"):
            if re.search(r"\bcustomfield_\d+\b", content, flags=re.IGNORECASE):
                violations.append(f"{path_text}: contains a hardcoded Jira custom field ID")

        if relative_path.name.endswith(".bundle-meta.xml") and "<target>" in content:
            violations.append(f"{path_text}: contains a version-specific Agentforce target")

        if relative_path.suffix == ".agent" and "default_agent_user:" in content:
            violations.append(f"{path_text}: employee agent contains a default_agent_user")

    if violations:
        print("Portability check failed:")
        for violation in sorted(set(violations)):
            print(f"- {violation}")
        return 1

    print("Portability check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
