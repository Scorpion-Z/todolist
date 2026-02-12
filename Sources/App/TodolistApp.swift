import SwiftUI

@main
struct TodolistApp: App {
    var body: some Scene {
        Window("app.title", id: "main") {
            RootView()
        }
        .commands {
            TodolistCommands()
            CommandGroup(replacing: .newItem) { }
        }
    }
}
