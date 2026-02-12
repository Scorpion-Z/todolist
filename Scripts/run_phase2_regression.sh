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
  Sources/App/Resources/AppAppearancePreference.swift \
  Sources/App/Resources/ToDoWebStyle.swift \
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
  "settings.appearance.section"
  "settings.appearance.label"
  "settings.appearance.system"
  "settings.appearance.light"
  "settings.appearance.dark"
  "settings.appearance.lightBackground.toggle"
  "settings.appearance.hint"
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

if rg -n 'WindowGroup' Sources/App/TodolistApp.swift >/dev/null; then
  echo "TodolistApp should use a single Window scene instead of WindowGroup."
  exit 1
fi

if rg -n '\.inspector\s*\(' Sources/App/Features/Shell/AppShellView.swift >/dev/null; then
  echo "AppShellView should not use inspector for the task detail panel."
  exit 1
fi

if ! rg -n 'todoCommandFocusQuickAdd|todoCommandFocusSearch' Sources/App/AppCommands.swift >/dev/null; then
  echo "AppCommands should expose focus notifications for quick add and search."
  exit 1
fi

if rg -n 'frame\(minWidth:\s*560\)|frame\(minWidth:\s*340' Sources/App/Features/Shell/AppShellView.swift >/dev/null; then
  echo "AppShellView should not enforce old conflicting minWidth constraints for task/detail panes."
  exit 1
fi

if rg -n 'template\\.manager\\.title' Sources/App/Features/Shell/AppShellView.swift Sources/App/Features/Composer/QuickAddBarView.swift >/dev/null; then
  echo "Main flow should not expose template manager entry points."
  exit 1
fi

if rg -n 'Picker\("priority\.label"' Sources/App/Features/TaskDetail/TaskDetailView.swift >/dev/null; then
  echo "TaskDetailView main flow should not expose priority picker."
  exit 1
fi

if ! rg -n 'detailPresentationMode\(for width:' Sources/App/ViewModels/AppShellViewModel.swift >/dev/null; then
  echo "AppShellViewModel should provide detailPresentationMode width decision API."
  exit 1
fi

if ! rg -n 'clampedDetailWidth\(' Sources/App/ViewModels/AppShellViewModel.swift >/dev/null; then
  echo "AppShellViewModel should provide detail width clamp API."
  exit 1
fi

if [[ ! -f Sources/App/Resources/ToDoWebStyle.swift ]]; then
  echo "ToDoWebStyle.swift should exist as the single source of visual tokens."
  exit 1
fi

if [[ ! -f Sources/App/Resources/AppAppearancePreference.swift ]]; then
  echo "AppAppearancePreference.swift should exist for appearance mode mapping."
  exit 1
fi

for file in \
  Sources/App/Features/Shell/AppShellView.swift \
  Sources/App/Features/Shell/SidebarView.swift \
  Sources/App/Features/TaskList/TaskRowView.swift \
  Sources/App/Features/Composer/QuickAddBarView.swift \
  Sources/App/Features/TaskDetail/TaskDetailView.swift; do
  if ! rg -n 'ToDoWebMetrics|ToDoWebColors|ToDoWebMotion' "$file" >/dev/null; then
    echo "$file should consume ToDoWebStyle tokens instead of hardcoded visual constants."
    exit 1
  fi
done

if ! rg -n 'hoverBezier\s*:.*timingCurve\(' Sources/App/Resources/ToDoWebStyle.swift >/dev/null; then
  echo "ToDoWebStyle should define hoverBezier using timingCurve."
  exit 1
fi

if ! rg -n 'scaleFactor\(for contentWidth:' Sources/App/Resources/ToDoWebStyle.swift >/dev/null; then
  echo "ToDoWebStyle should provide scaleFactor(for:) for adaptive proportional layout."
  exit 1
fi

if ! rg -n 'toolbarIconHitArea' Sources/App/Features/Shell/AppShellView.swift >/dev/null; then
  echo "AppShellView should use toolbarIconHitArea token for toolbar icon hit targets."
  exit 1
fi

if rg -n 'Divider\(' Sources/App/Features/Shell/AppShellView.swift Sources/App/Features/Shell/SidebarView.swift >/dev/null; then
  echo "AppShellView/SidebarView should avoid direct Divider() and use explicit separator tokens."
  exit 1
fi

if rg -n '\.easeOut\(' Sources/App/Features/TaskList/TaskRowView.swift >/dev/null; then
  echo "TaskRowView hover behavior should use ToDoWebMotion.hoverBezier, not direct easeOut."
  exit 1
fi

if rg -n '\.clipped\(\)' Sources/App/Features/Shell/AppShellView.swift >/dev/null; then
  echo "AppShellView content column should avoid clipped() to prevent resize-time content truncation."
  exit 1
fi

if ! rg -n '\.preferredColorScheme\(' Sources/App/Features/Shell/AppShellView.swift >/dev/null; then
  echo "RootView should apply preferredColorScheme based on appearance preference."
  exit 1
fi

if ! rg -n '\.listStyle\(\.plain\)' Sources/App/Features/TaskList/TaskListView.swift >/dev/null; then
  echo "TaskListView should use plain list style for stable resize behavior."
  exit 1
fi

if rg -n 'AppTheme\.sidebarBackground' Sources/App/Features/Shell/SidebarView.swift >/dev/null; then
  echo "SidebarView should use palette-driven sidebar colors instead of AppTheme.sidebarBackground."
  exit 1
fi

if ! rg -n 'frame\(maxWidth:\s*\.infinity,\s*minHeight:\s*ToDoWebMetrics\.taskRowMinHeight' Sources/App/Features/TaskList/TaskRowView.swift >/dev/null; then
  echo "TaskRowView should keep maxWidth .infinity to avoid left-clustered narrow rows."
  exit 1
fi

if ! rg -n 'quickAddActionMinWidth' Sources/App/Resources/ToDoWebStyle.swift Sources/App/Features/Composer/QuickAddBarView.swift >/dev/null; then
  echo "QuickAdd action width should be tokenized via quickAddActionMinWidth."
  exit 1
fi

if ! rg -n 'sidebarSelectionBorder' Sources/App/Features/Shell/SidebarView.swift Sources/App/Resources/ToDoWebStyle.swift >/dev/null; then
  echo "Sidebar selected rows should use sidebarSelectionBorder token."
  exit 1
fi

if ! rg -F -n 'stroke(palette.panelBorder' Sources/App/Features/Shell/AppShellView.swift >/dev/null; then
  echo "AppShellView main panels should use panelBorder token."
  exit 1
fi
