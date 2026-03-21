#!/bin/bash
# lint-strings.sh — Lint .xcstrings catalogs for missing/empty translations.
# Exit 0 = all good, exit 1 = errors found.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CATALOGS=$(find "$REPO_ROOT" -name '*.xcstrings' -not -path '*/.*' -not -path '*/DerivedData/*')

if [ -z "$CATALOGS" ]; then
  echo "No .xcstrings files found."
  exit 0
fi

python3 - "$CATALOGS" <<'PYTHON_SCRIPT'
import json
import sys
import os

# ============================================================================
# Constants
# ============================================================================

COLOR_RED = "\033[31m"
COLOR_YELLOW = "\033[33m"
COLOR_GREEN = "\033[32m"
COLOR_BOLD = "\033[1m"
COLOR_RESET = "\033[0m"

# ============================================================================
# Lint Logic
# ============================================================================

def lint_catalog(path):
    """Lint a single .xcstrings file. Returns (errors, warnings) counts."""
    rel_path = os.path.relpath(path)
    with open(path, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    source_lang = catalog.get("sourceLanguage", "en")
    strings = catalog.get("strings", {})

    if not strings:
        return 0, 0

    # Auto-discover all non-source languages present across all keys.
    all_languages = set()
    for key, entry in strings.items():
        localizations = entry.get("localizations", {})
        for lang in localizations:
            if lang != source_lang:
                all_languages.add(lang)

    if not all_languages:
        # No non-source languages found — nothing to check.
        return 0, 0

    sorted_languages = sorted(all_languages)
    errors = 0
    warnings = 0

    for key, entry in sorted(strings.items()):
        localizations = entry.get("localizations", {})

        for lang in sorted_languages:
            if lang not in localizations:
                print(
                    f"{COLOR_RED}ERROR{COLOR_RESET}  "
                    f"{COLOR_BOLD}{rel_path}{COLOR_RESET}: "
                    f"key {COLOR_BOLD}\"{key}\"{COLOR_RESET} "
                    f"missing [{lang}] translation"
                )
                errors += 1
                continue

            lang_entry = localizations[lang]
            string_unit = lang_entry.get("stringUnit", {})
            value = string_unit.get("value", "")
            state = string_unit.get("state", "")

            if value == "":
                print(
                    f"{COLOR_RED}ERROR{COLOR_RESET}  "
                    f"{COLOR_BOLD}{rel_path}{COLOR_RESET}: "
                    f"key {COLOR_BOLD}\"{key}\"{COLOR_RESET} "
                    f"has empty [{lang}] translation"
                )
                errors += 1

            if state == "needs_review":
                print(
                    f"{COLOR_YELLOW}WARN {COLOR_RESET}  "
                    f"{COLOR_BOLD}{rel_path}{COLOR_RESET}: "
                    f"key {COLOR_BOLD}\"{key}\"{COLOR_RESET} "
                    f"[{lang}] state is needs_review"
                )
                warnings += 1

    return errors, warnings


# ============================================================================
# Main
# ============================================================================

def main():
    paths = sys.argv[1].split()
    total_errors = 0
    total_warnings = 0

    for path in paths:
        path = path.strip()
        if not path:
            continue
        errors, warnings = lint_catalog(path)
        total_errors += errors
        total_warnings += warnings

    # Summary
    print()
    if total_errors == 0 and total_warnings == 0:
        print(f"{COLOR_GREEN}String catalogs OK — no issues found.{COLOR_RESET}")
    else:
        parts = []
        if total_errors > 0:
            parts.append(f"{COLOR_RED}{total_errors} error(s){COLOR_RESET}")
        if total_warnings > 0:
            parts.append(f"{COLOR_YELLOW}{total_warnings} warning(s){COLOR_RESET}")
        print(f"String catalog lint: {', '.join(parts)}")

    if total_errors > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
PYTHON_SCRIPT
