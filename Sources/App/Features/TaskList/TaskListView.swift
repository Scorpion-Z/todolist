import SwiftUI

struct TaskListView: View {
    let tasks: [TodoItem]
    let smartList: SmartListID
    @Binding var selectedTaskID: TodoItem.ID?
    @ObservedObject var store: TaskStore

    private let queryEngine = ListQueryEngine()

    var body: some View {
        List(selection: $selectedTaskID) {
            if smartList == .planned {
                plannedSections
            } else {
                plainSection
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    private var plainSection: some View {
        Section {
            ForEach(tasks) { item in
                row(for: item)
                    .tag(item.id)
                    .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteRows)
        }
    }

    private var plannedSections: some View {
        let grouped = queryEngine.groupedPlannedTasks(tasks)
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
                    if let selectedTaskID, ids.contains(selectedTaskID) {
                        self.selectedTaskID = nil
                    }
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
                selectedTaskID = item.id
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
                if selectedTaskID == item.id {
                    selectedTaskID = nil
                }
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
                if selectedTaskID == item.id {
                    selectedTaskID = nil
                }
                store.deleteTasks(ids: [item.id])
            }
        }
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

    private func deleteRows(_ offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            tasks.indices.contains(index) ? tasks[index].id : nil
        }
        store.deleteTasks(ids: ids)
        if let selectedTaskID, ids.contains(selectedTaskID) {
            self.selectedTaskID = nil
        }
    }
}
