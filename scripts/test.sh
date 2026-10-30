#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/checks
swiftc -parse-as-library \
    Sources/NextayClip/AppSettings.swift \
    Sources/NextayClip/ClipboardStore.swift \
    Tests/NextayClipTests/ClipboardStoreTests.swift \
    -o .build/checks/ClipboardStoreTests
.build/checks/ClipboardStoreTests
