#!/bin/bash
# Downloads the llama.cpp XCFramework for local development.
# Run once after cloning, or when upgrading llama.cpp version.

set -euo pipefail

# Read from LlamaRuntime rather than duplicated here: the app reports that number to decide which
# models it can load, so a copy that drifted would have it download models it cannot open.
# b8215 could not load the Qwen3.5 GGUFs -- their multi-token-prediction block is an extra layer
# whose tensors that build does not recognise, and loading died on "missing tensor
# 'blk.24.ssm_conv1d.weight'". MTP support landed in b9180.
RUNTIME_SWIFT="$(dirname "$0")/../Shared/LlamaRuntime.swift"
BUILD_NUMBER="$(sed -n 's/.*static let buildNumber = \([0-9][0-9]*\).*/\1/p' "$RUNTIME_SWIFT")"
[ -n "$BUILD_NUMBER" ] || { echo "ERROR: no buildNumber in $RUNTIME_SWIFT" >&2; exit 1; }
LLAMA_VERSION="b${BUILD_NUMBER}"
XCFRAMEWORK_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_VERSION}/llama-${LLAMA_VERSION}-xcframework.zip"
DEST_DIR="$(dirname "$0")/../Packages/LlamaCpp"
XCFRAMEWORK_PATH="${DEST_DIR}/llama.xcframework"

if [ -d "$XCFRAMEWORK_PATH" ]; then
  echo "llama.xcframework already exists at ${XCFRAMEWORK_PATH}"
  echo "To re-download, remove it first: rm -rf ${XCFRAMEWORK_PATH}"
  exit 0
fi

echo "Downloading llama.cpp ${LLAMA_VERSION} XCFramework..."
TMPFILE=$(mktemp /tmp/llama-xcframework-XXXXXX.zip)
trap 'rm -f "$TMPFILE"' EXIT

curl -L -o "$TMPFILE" "$XCFRAMEWORK_URL"

echo "Extracting..."
unzip -q -o "$TMPFILE" -d "$DEST_DIR"

# The zip extracts to build-apple/llama.xcframework
if [ -d "${DEST_DIR}/build-apple/llama.xcframework" ]; then
  mv "${DEST_DIR}/build-apple/llama.xcframework" "$XCFRAMEWORK_PATH"
  rm -rf "${DEST_DIR}/build-apple"
fi

if [ ! -d "$XCFRAMEWORK_PATH" ]; then
  echo "ERROR: xcframework not found at ${XCFRAMEWORK_PATH} after extraction"
  echo "Contents of ${DEST_DIR}:"
  ls -la "$DEST_DIR"
  exit 1
fi

echo "Done. XCFramework at: ${XCFRAMEWORK_PATH}"
