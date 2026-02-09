#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

: "${CLANG_MODULE_CACHE_PATH:=/tmp/clang-module-cache}"
: "${SWIFT_MODULECACHE_PATH:=/tmp/swift-module-cache}"

CLANG_MODULE_CACHE_PATH="$CLANG_MODULE_CACHE_PATH" \
SWIFT_MODULECACHE_PATH="$SWIFT_MODULECACHE_PATH" \
xcrun swiftc -emit-executable \
  Sources/App/Models/Tag.swift \
  Sources/App/Models/Subtask.swift \
  Sources/App/Models/TodoItem.swift \
  Sources/App/Parsing/QuickAddParser.swift \
  Sources/App/ViewModels/ListQueryEngine.swift \
  Sources/App/ViewModels/TaskStore.swift \
  Sources/App/ViewModels/TodoListViewModel.swift \
  Scripts/phase2_regression.swift \
  -o /tmp/phase2_regression_bin

/tmp/phase2_regression_bin
