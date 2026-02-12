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
  Sources/App/ViewModels/AppShellViewModel.swift \
  Sources/App/ViewModels/TodoStorage.swift \
  Sources/App/ViewModels/TaskStore.swift \
  Scripts/phase2_regression.swift \
  -o /tmp/phase2_regression_bin

/tmp/phase2_regression_bin

extract_keys() {
  sed -n 's/^"\\([^"]\\+\\)".*/\\1/p' "$1" | sort -u
}

EN_KEYS="$(mktemp)"
ZH_KEYS="$(mktemp)"
trap 'rm -f "$EN_KEYS" "$ZH_KEYS"' EXIT

extract_keys Sources/App/Resources/en.lproj/Localizable.strings > "$EN_KEYS"
extract_keys Sources/App/Resources/zh-Hans.lproj/Localizable.strings > "$ZH_KEYS"

MISSING_IN_ZH="$(comm -23 "$EN_KEYS" "$ZH_KEYS" || true)"
MISSING_IN_EN="$(comm -13 "$EN_KEYS" "$ZH_KEYS" || true)"

if [[ -n "$MISSING_IN_ZH" || -n "$MISSING_IN_EN" ]]; then
  if [[ -n "$MISSING_IN_ZH" ]]; then
    echo "Missing keys in zh-Hans:"
    echo "$MISSING_IN_ZH"
  fi
  if [[ -n "$MISSING_IN_EN" ]]; then
    echo "Missing keys in en:"
    echo "$MISSING_IN_EN"
  fi
  exit 1
fi

REQUIRED_LOCALIZATION_KEYS=(
  "repeat.none"
  "repeat.daily"
  "repeat.weekly"
  "repeat.monthly"
)

check_required_keys() {
  local file="$1"
  local locale="$2"
  local missing=()
  for key in "${REQUIRED_LOCALIZATION_KEYS[@]}"; do
    if ! rg -q "^\"${key}\"\\s*=" "$file"; then
      missing+=("$key")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    echo "Missing required localization keys in ${locale}:"
    printf '%s\n' "${missing[@]}"
    exit 1
  fi
}

check_required_keys Sources/App/Resources/en.lproj/Localizable.strings "en"
check_required_keys Sources/App/Resources/zh-Hans.lproj/Localizable.strings "zh-Hans"

if rg -n 'pillLabel\("smart\.(myDay|important)"' Sources/App/Features/TaskList/TaskRowView.swift >/dev/null; then
  echo "TaskRowView should use LocalizedStringKey for smart.* pills, not String literals."
  exit 1
fi
