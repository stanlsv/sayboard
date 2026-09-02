#!/bin/bash
# check-model-sizes.sh -- Compares every declared `downloadSizeMB` against the published archive.
#
# The declared constants feed the model card the user reads, so a constant that drifts from what R2
# actually serves misstates the download in the UI. gemma3OneQAT drifted 33 MB this way before this
# check existed.
#
# Usage:
#   ./scripts/check-model-sizes.sh              # compare against the live manifest, exit 1 on drift
#   ./scripts/check-model-sizes.sh --ratios     # also report each speech archive's expansion ratio
#   ./scripts/check-model-sizes.sh --declared   # print "<rawValue>\t<MB>" and exit
#
# Environment variables:
#   MANIFEST_URL -- defaults to https://models.sayboard.app/manifest.json

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST_URL="${MANIFEST_URL:-https://models.sayboard.app/manifest.json}"

MODE="check"
case "${1:-}" in
  --ratios) MODE="ratios" ;;
  --declared) MODE="declared" ;;
  "") ;;
  *) echo "ERROR: unknown argument '$1'" >&2; exit 1 ;;
esac

REPO_ROOT="$REPO_ROOT" MANIFEST_URL="$MANIFEST_URL" MODE="$MODE" python3 - <<'PYTHON_CHECK_SIZES'
import os
import re
import struct
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(os.environ["REPO_ROOT"])
MANIFEST_URL = os.environ["MANIFEST_URL"]
MODE = os.environ["MODE"]

# `megabytesInBytes` is decimal (Shared/ModelVariant.swift), so a declared Int is compared against
# bytes/1e6. The constants are rounded to the nearest MB, which puts an honest one up to half a
# megabyte either side of the archive; 1 MB accepts that and still catches drift a rebuild causes.
TOLERANCE_MB = 1.0
USER_AGENT = "Sayboard-size-check"
# Enough of the archive's tail to hold the end-of-central-directory record and the comment after it.
ZIP_TAIL_BYTES = 66_000
EOCD_SIGNATURE = b"PK\x05\x06"
CENTRAL_HEADER_SIGNATURE = b"PK\x01\x02"
CENTRAL_HEADER_FIXED_SIZE = 46

VARIANT_CASE = re.compile(r'case (?P<name>\w+) = "(?P<id>[\w.\-]+)"')
SIZE_CASE = re.compile(r"case \.(?P<names>[\w, .]+): (?P<mb>\d+)")


def declared_sizes(path, enum_marker, end_marker):
    """Maps each variant's raw value to the `downloadSizeMB` its enum declares."""
    source = (REPO_ROOT / path).read_text(encoding="utf-8")
    enum_section = source.split(enum_marker)[1].split(end_marker)[0]
    raw_values = {m.group("name"): m.group("id") for m in VARIANT_CASE.finditer(enum_section)}

    size_section = source.split("var downloadSizeMB: Int {")[1].split("\n  }")[0]
    sizes = {}
    for match in SIZE_CASE.finditer(size_section):
        for case_name in match.group("names").split(","):
            name = case_name.strip().lstrip(".")
            if name in raw_values:
                sizes[raw_values[name]] = int(match.group("mb"))
    return sizes


def curl(url, extra=()):
    result = subprocess.run(
        ["curl", "-sS", "-A", USER_AGENT, "--max-time", "120", *extra, url],
        capture_output=True,
        check=True,
    )
    return result.stdout


def expanded_bytes(url, total):
    """Sums the uncompressed sizes in the archive's central directory, read over two range requests.

    Returns None when the range is not honoured: Cloudflare serves some objects whole regardless of
    the header, and reading the ratio is never worth downloading a gigabyte to get it.
    """
    want = min(ZIP_TAIL_BYTES, total)
    tail = curl(url, ["-r", f"{total - want}-{total - 1}"])
    if len(tail) != want:
        return None
    start = tail.rfind(EOCD_SIGNATURE)
    if start < 0:
        return None
    cd_size, cd_offset = struct.unpack("<II", tail[start + 12 : start + 20])
    directory = curl(url, ["-r", f"{cd_offset}-{cd_offset + cd_size - 1}"])
    if len(directory) != cd_size:
        return None

    total_uncompressed = 0
    at = 0
    while at + CENTRAL_HEADER_FIXED_SIZE <= len(directory):
        if directory[at : at + 4] != CENTRAL_HEADER_SIGNATURE:
            break
        total_uncompressed += struct.unpack("<I", directory[at + 24 : at + 28])[0]
        name_len, extra_len, comment_len = struct.unpack("<HHH", directory[at + 28 : at + 34])
        at += CENTRAL_HEADER_FIXED_SIZE + name_len + extra_len + comment_len
    return total_uncompressed


speech = declared_sizes("Shared/ModelVariant.swift", "enum ModelVariant", "// MARK: - ModelDownloadState")
text = declared_sizes("Shared/LLMConstants.swift", "enum LLMModelVariant", "// MARK: - LLMAction")

if MODE == "declared":
    for raw_value, mb in {**speech, **text}.items():
        print(f"{raw_value}\t{mb}")
    sys.exit(0)

print(f"==> Fetching manifest from {MANIFEST_URL}")
import json

manifest = json.loads(curl(MANIFEST_URL))
published = {**manifest.get("models", {}), **manifest.get("llmModels", {})}

drifted = []
missing = []
print(f"{'model':46s} {'declared':>9s} {'published':>10s} {'diff':>7s}")
print("-" * 76)
for raw_value, declared_mb in {**speech, **text}.items():
    entry = published.get(raw_value)
    if entry is None:
        missing.append(raw_value)
        print(f"{raw_value:46s} {declared_mb:9d} {'--':>10s}   not in manifest")
        continue
    published_mb = entry["sizeBytes"] / 1e6
    diff = declared_mb - published_mb
    flag = ""
    if abs(diff) > TOLERANCE_MB:
        drifted.append((raw_value, declared_mb, published_mb))
        flag = "  <== DRIFT"
    print(f"{raw_value:46s} {declared_mb:9d} {published_mb:10.1f} {diff:+7.1f}{flag}")

if MODE == "ratios":
    # Both halves. The text archives were assumed to be stored rather than deflated, which would
    # have pinned them at 2.0x; two of the eight are in fact deflated, so the assumption has to be
    # re-checked rather than trusted.
    print()
    print(f"{'model':46s} {'archive MB':>11s} {'expanded MB':>12s} {'peak':>7s}")
    print("-" * 79)
    for raw_value in {**speech, **text}:
        entry = published.get(raw_value)
        if entry is None:
            continue
        archive = entry["sizeBytes"]
        expanded = expanded_bytes(entry["url"], archive)
        if expanded is None:
            print(f"{raw_value:46s} {archive / 1e6:11.1f} {'--':>12s}   range not honoured")
            continue
        print(
            f"{raw_value:46s} {archive / 1e6:11.1f} {expanded / 1e6:12.1f} "
            f"{(archive + expanded) / archive:7.3f}"
        )

print()
if missing:
    print(f"WARN: {len(missing)} declared variant(s) absent from the manifest: {', '.join(missing)}")
if drifted:
    print(f"FAILED: {len(drifted)} declared size(s) drifted from what is published.")
    for raw_value, declared_mb, published_mb in drifted:
        print(f"  {raw_value}: declared {declared_mb} MB, published {published_mb:.1f} MB")
    sys.exit(1)
print(f"OK: all {len(speech) + len(text)} declared sizes match the manifest.")
PYTHON_CHECK_SIZES
