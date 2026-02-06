import SwiftData
import SwiftUI

struct ContentView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case open = "Open"
        case completed = "Completed"

        var id: String { rawValue }
    }

    @StateObject private var viewModel: TodoListViewModel
    @State private var newTitle = ""
    @State private var newPriority: TodoItem.Priority = .medium
    @State private var newDueDateEnabled = false
    @State private var newDueDate = Date()
    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var editingItem: TodoItem?
    @State private var editTitle = ""
    @State private var editPriority: TodoItem.Priority = .medium
    @State private var editDueDateEnabled = false
    @State private var editDueDate = Date()

    init(repository: TodoRepository) {
        _viewModel = StateObject(wrappedValue: TodoListViewModel(repository: repository))
    }

    private var filteredItems: [TodoItem] {
        viewModel.items.filter { item in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .open:
                matchesFilter = !item.isCompleted
            case .completed:
                matchesFilter = item.isCompleted
            }

            guard matchesFilter else { return false }
            guard !searchText.isEmpty else { return true }
            return item.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("New todo", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 12) {
                        Picker("Priority", selection: $newPriority) {
                            ForEach(TodoItem.Priority.allCases) { priority in
                                Text(priority.displayName).tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Due date", isOn: $newDueDateEnabled)
                        if newDueDateEnabled {
                            DatePicker("", selection: $newDueDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                }
                Button("Add") {
                    viewModel.addItem(
                        title: newTitle,
                        priority: newPriority,
                        dueDate: newDueDateEnabled ? newDueDate : nil
                    )
                    newTitle = ""
                    newPriority = .medium
                    newDueDateEnabled = false
                }
                .keyboardShortcut(.defaultAction)
            }

            HStack {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                Spacer()
            }

            if filteredItems.isEmpty {
                if #available(macOS 14.0, *) {
                    ContentUnavailableView("No todos", systemImage: "checkmark.circle")
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No todos")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List {
                    ForEach(filteredItems) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                viewModel.toggleCompletion(for: item)
                            } label: {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .strikethrough(item.isCompleted, color: .secondary)
                                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                                HStack(spacing: 8) {
                                    Text(item.priority.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let dueDate = item.dueDate {
                                        Text(dueDate, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            Button("Edit") {
                                beginEditing(item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 6)
                        .contextMenu {
                            Button("Edit") {
                                beginEditing(item)
                            }
                            Button(item.isCompleted ? "Mark Open" : "Mark Done") {
                                viewModel.toggleCompletion(for: item)
                            }
                        }
                    }
                    .onDelete(perform: viewModel.deleteItems)
                    .onMove(perform: viewModel.moveItems)
                }
                .listStyle(.inset)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 420)
        .searchable(text: $searchText)
        .sheet(item: $editingItem) { item in
            editSheet(for: item)
        }
    }

    private func beginEditing(_ item: TodoItem) {
        editingItem = item
        editTitle = item.title
        editPriority = item.priority
        if let dueDate = item.dueDate {
            editDueDateEnabled = true
            editDueDate = dueDate
        } else {
            editDueDateEnabled = false
            editDueDate = Date()
        }
    }

    @ViewBuilder
    private func editSheet(for item: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Todo")
                .font(.title2)
            TextField("Title", text: $editTitle)
                .textFieldStyle(.roundedBorder)
            Picker("Priority", selection: $editPriority) {
                ForEach(TodoItem.Priority.allCases) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            Toggle("Due date", isOn: $editDueDateEnabled)
            if editDueDateEnabled {
                DatePicker("", selection: $editDueDate, displayedComponents: .date)
                    .labelsHidden()
            }
            HStack {
                Button("Cancel") {
                    editingItem = nil
                }
                Spacer()
                Button("Save") {
                    viewModel.updateItem(
                        item,
                        title: editTitle,
                        priority: editPriority,
                        dueDate: editDueDateEnabled ? editDueDate : nil
                    )
                    editingItem = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
    }
}

#Preview {
    let schema = Schema([TodoEntity.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    ContentView(repository: SwiftDataTodoRepository(modelContext: container.mainContext))
}
