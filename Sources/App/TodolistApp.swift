import SwiftData
import SwiftUI

@main
struct TodolistApp: App {
    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([TodoEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(repository: SwiftDataTodoRepository(modelContext: sharedModelContainer.mainContext))
        }
        .modelContainer(sharedModelContainer)
    }
}
