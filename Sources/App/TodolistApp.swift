import SwiftUI

@main
struct TodolistApp: App {
    var body: some Scene {
        Window("app.title", id: "main") {
            RootView()
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            TodolistCommands()
            CommandGroup(replacing: .newItem) { }
        }
    }
}
