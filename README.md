# todolist

A minimal macOS SwiftUI todo list app.

## Requirements
- macOS with Xcode 15 or newer.

## Run in Xcode
1. Open `Todolist.xcodeproj` in Xcode.
2. Select the `Todolist` scheme (it is shared in the repo).
3. Choose the **My Mac** run destination.
4. Click **Run**.

## Build from the command line
```bash
xcodebuild -project Todolist.xcodeproj \
  -scheme Todolist \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

## Phase 2 regression checks
Run the second-phase logic regression suite (smart-list semantics, My Day behavior, quick add parser, merge strategy):

```bash
./Scripts/run_phase2_regression.sh
```

## Scheme notes
The shared scheme lives at `Todolist.xcodeproj/xcshareddata/xcschemes/Todolist.xcscheme` so it can be picked up by Xcode and CI.
