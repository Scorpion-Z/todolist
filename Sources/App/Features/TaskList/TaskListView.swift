import SwiftUI

struct TaskListView: View {
    let tasks: [TodoItem]
    let smartList: SmartListID?
    let customListID: UUID?
    let showCompletedSection: Bool

    @Binding var selectedTaskID: TodoItem.ID?
    @ObservedObject var store: TaskStore
    @State private var uiSelectedTaskID: TodoItem.ID?
    @State private var pendingSelection: TodoItem.ID?

    private let queryEngine = ListQueryEngine()

    private var openTasks: [TodoItem] {
        tasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [TodoItem] {
        tasks.filter(\.isCompleted)
    }

    var body: some View {
        List(selection: $uiSelectedTaskID) {
            if smartList == .planned {
                plannedOpenSections
            } else {
                openTasksSection
            }

            if showCompletedSection && !completedTasks.isEmpty {
                Section("section.completed") {
                    ForEach(completedTasks) { item in
                        row(for: item)
                            .tag(item.id)
                            .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        let ids = offsets.compactMap { completedTasks.indices.contains($0) ? completedTasks[$0].id : nil }
                        store.deleteTasks(ids: ids)
                        clearSelectionIfNeeded(deletedIDs: ids)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onAppear {
            uiSelectedTaskID = selectedTaskID
            pendingSelection = nil
        }
        .onChange(of: uiSelectedTaskID) { _, newValue in
            guard newValue != selectedTaskID else {
                pendingSelection = nil
                return
            }

            pendingSelection = newValue
            Task { @MainActor in
                guard pendingSelection == newValue else { return }
                selectedTaskID = newValue
                pendingSelection = nil
            }
        }
        .onChange(of: selectedTaskID) { _, newValue in
            pendingSelection = nil
            if uiSelectedTaskID != newValue {
                uiSelectedTaskID = newValue
            }
        }
    }

    private var openTasksSection: some View {
        Section {
            ForEach(openTasks) { item in
                row(for: item)
                    .tag(item.id)
                    .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteOpenRows)
            .onMove(perform: moveOpenRows)
        }
    }

    private var plannedOpenSections: some View {
        let grouped = queryEngine.groupedPlannedTasks(openTasks)
        return ForEach(grouped, id: \.date) { section in
            Section(header: sectionHeader(for: section.date)) {
                ForEach(section.items) { item in
                    row(for: item)
                        .tag(item.id)
                        .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .onDelete { offsets in
                    let ids = offsets.compactMap { index in
                        section.items.indices.contains(index) ? section.items[index].id : nil
                    }
                    store.deleteTasks(ids: ids)
                    clearSelectionIfNeeded(deletedIDs: ids)
                }
            }
        }
    }

    private func row(for item: TodoItem) -> some View {
        TaskRowView(
            item: item,
            isSelected: selectedTaskID == item.id,
            isInMyDay: queryEngine.isInMyDay(item, referenceDate: Date()),
            onSelect: {
                uiSelectedTaskID = item.id
            },
            onToggleCompletion: {
                store.toggleCompletion(id: item.id)
            },
            onToggleImportant: {
                store.toggleImportant(id: item.id)
            },
            onToggleMyDay: {
                if queryEngine.isInMyDay(item, referenceDate: Date()) {
                    store.removeFromMyDay(id: item.id)
                } else {
                    store.addToMyDay(id: item.id)
                }
            },
            onDelete: {
                clearSelectionIfNeeded(deletedIDs: [item.id])
                store.deleteTasks(ids: [item.id])
            }
        )
        .contextMenu {
            Button(item.isCompleted ? "mark.open" : "mark.done") {
                store.toggleCompletion(id: item.id)
            }
            Button(item.isImportant ? "important.remove" : "important.add") {
                store.toggleImportant(id: item.id)
            }
            Button(queryEngine.isInMyDay(item, referenceDate: Date()) ? "myday.remove" : "myday.add") {
                if queryEngine.isInMyDay(item, referenceDate: Date()) {
                    store.removeFromMyDay(id: item.id)
                } else {
                    store.addToMyDay(id: item.id)
                }
            }
            Divider()
            Button("delete.button", role: .destructive) {
                clearSelectionIfNeeded(deletedIDs: [item.id])
                store.deleteTasks(ids: [item.id])
            }
        }
    }

    private func moveOpenRows(_ source: IndexSet, _ destination: Int) {
        guard let customListID else { return }
        var ordered = openTasks.map(\.id)
        ordered.move(fromOffsets: source, toOffset: destination)
        store.reorderTasks(inListID: customListID, orderedTaskIDs: ordered)
    }

    private func sectionHeader(for date: Date?) -> some View {
        Group {
            if let date {
                Text(date, format: .dateTime.year().month().day())
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Text("calendar.section.noduedate")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .textCase(nil)
    }

    private func deleteOpenRows(_ offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            openTasks.indices.contains(index) ? openTasks[index].id : nil
        }
        store.deleteTasks(ids: ids)
        clearSelectionIfNeeded(deletedIDs: ids)
    }

    private func clearSelectionIfNeeded(deletedIDs: [UUID]) {
        guard let currentID = uiSelectedTaskID else { return }
        guard deletedIDs.contains(currentID) else { return }
        uiSelectedTaskID = nil
        pendingSelection = nil
        Task { @MainActor in
            selectedTaskID = nil
        }
    }
}
