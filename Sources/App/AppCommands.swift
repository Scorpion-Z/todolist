import Foundation
import SwiftUI

extension Notification.Name {
    static let todoCommandNewTask = Notification.Name("todo.command.newTask")
    static let todoCommandToggleCompletion = Notification.Name("todo.command.toggleCompletion")
    static let todoCommandToggleImportant = Notification.Name("todo.command.toggleImportant")
    static let todoCommandDeleteTask = Notification.Name("todo.command.deleteTask")
}

struct TodolistCommands: Commands {
    var body: some Commands {
        CommandMenu("command.menu.task") {
            Button("command.newTask") {
                post(.todoCommandNewTask)
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("command.toggleComplete") {
                post(.todoCommandToggleCompletion)
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button("command.toggleImportant") {
                post(.todoCommandToggleImportant)
            }
            .keyboardShortcut("i", modifiers: .command)

            Button("command.deleteTask") {
                post(.todoCommandDeleteTask)
            }
            .keyboardShortcut(.delete, modifiers: [])
        }
    }

    private func post(_ notification: Notification.Name) {
        NotificationCenter.default.post(name: notification, object: nil)
    }
}
