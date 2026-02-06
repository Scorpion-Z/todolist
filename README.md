# todolist

A minimal macOS SwiftUI todo list app.

## Requirements
- macOS 14 or newer with Xcode 15 or newer (SwiftData-backed storage).

## Data storage & migration
- The app now uses SwiftData for persistence, with indexed fields on completion status, due date, and creation time to keep future smart lists fast.
- On first launch after upgrading, the app migrates any legacy `todo_items` JSON stored in `UserDefaults` into SwiftData, then clears the old key to avoid repeated imports.

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

## Scheme notes
The shared scheme lives at `Todolist.xcodeproj/xcshareddata/xcschemes/Todolist.xcscheme` so it can be picked up by Xcode and CI.
