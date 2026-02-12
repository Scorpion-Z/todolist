import Foundation
import SwiftUI

extension Notification.Name {
    static let todoCommandFocusQuickAdd = Notification.Name("todo.command.focusQuickAdd")
    static let todoCommandFocusSearch = Notification.Name("todo.command.focusSearch")
    static let todoCommandToggleCompletion = Notification.Name("todo.command.toggleCompletion")
    static let todoCommandToggleImportant = Notification.Name("todo.command.toggleImportant")
    static let todoCommandDeleteTask = Notification.Name("todo.command.deleteTask")
    static let todoCommandCloseDetail = Notification.Name("todo.command.closeDetail")
}

struct TodolistCommands: Commands {
    var body: some Commands {
        CommandMenu("command.menu.task") {
            Button("command.newTask") {
                post(.todoCommandFocusQuickAdd)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("command.focusSearch") {
                post(.todoCommandFocusSearch)
            }
            .keyboardShortcut("f", modifiers: .command)

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

            Divider()

            Button("command.closeDetail") {
                post(.todoCommandCloseDetail)
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
    }

    private func post(_ notification: Notification.Name) {
        NotificationCenter.default.post(name: notification, object: nil)
    }
}
