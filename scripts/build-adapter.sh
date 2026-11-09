#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake not found. Install it with: brew install cmake"
  exit 1
fi
cmake -S Vendor/mediaremote-adapter -B Vendor/mediaremote-adapter/build
cmake --build Vendor/mediaremote-adapter/build
