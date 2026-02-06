import SwiftUI

struct ContentView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case open = "Open"
        case completed = "Completed"

        var id: String { rawValue }
    }

    @StateObject private var viewModel = TodoListViewModel()
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
    @State private var expandedCompletedItems: Set<UUID> = []

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
        VStack(alignment: .leading, spacing: 18) {
            if #available(macOS 14.0, *) {
                taskComposer
                    .padding(16)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                taskComposer
            }

            if #available(macOS 14.0, *) {
                HStack {
                    Text("Tasks")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                }
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
                        TodoRowView(
                            item: item,
                            isCompletedExpanded: expandedCompletedItems.contains(item.id),
                            onToggleCompletion: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                    viewModel.toggleCompletion(for: item)
                                }
                            },
                            onToggleCompletedExpansion: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedCompletedItems.contains(item.id) {
                                        expandedCompletedItems.remove(item.id)
                                    } else {
                                        expandedCompletedItems.insert(item.id)
                                    }
                                }
                            },
                            onEdit: { beginEditing(item) }
                        )
                        .padding(.vertical, 6)
                        .contextMenu {
                            Button("Edit") {
                                beginEditing(item)
                            }
                            Button(item.isCompleted ? "Mark Open" : "Mark Done") {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                    viewModel.toggleCompletion(for: item)
                                }
                            }
                        }
                    }
                    .onDelete(perform: viewModel.deleteItems)
                    .onMove(perform: viewModel.moveItems)
                }
                .listStyle(.inset)
                .animation(.default, value: filteredItems)
                .scrollContentBackgroundIfAvailable()
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 420)
        .searchable(text: $searchText)
        .sheet(item: $editingItem) { item in
            editSheet(for: item)
        }
    }

    private var taskComposer: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                if #available(macOS 14.0, *) {
                    Text("Add Todo")
                        .font(.headline)
                }

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

private struct TodoRowView: View {
    let item: TodoItem
    let isCompletedExpanded: Bool
    let onToggleCompletion: () -> Void
    let onToggleCompletedExpansion: () -> Void
    let onEdit: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggleCompletion) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .strikethrough(item.isCompleted, color: .secondary)
                        .foregroundStyle(item.isCompleted ? .tertiary : .primary)

                    PriorityCapsule(priority: item.priority)
                }

                if !item.isCompleted || isCompletedExpanded {
                    HStack(spacing: 8) {
                        if let dueDate = item.dueDate {
                            Text(dueDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                if let dueDateState = DueDateState(dueDate: item.dueDate, isCompleted: item.isCompleted) {
                    DateStateBadge(state: dueDateState)
                }

                if item.isCompleted {
                    Button {
                        onToggleCompletedExpansion()
                    } label: {
                        Image(systemName: isCompletedExpanded ? "chevron.up" : "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }

                Button("Edit", action: onEdit)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .opacity(isHovering ? 1 : 0)
                    .animation(.easeInOut(duration: 0.16), value: isHovering)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct PriorityCapsule: View {
    let priority: TodoItem.Priority

    var body: some View {
        Text(priority.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(priorityStyle.foreground)
            .background(priorityStyle.background, in: Capsule())
    }

    private var priorityStyle: (foreground: Color, background: Color) {
        switch priority {
        case .low:
            return (.green, .green.opacity(0.18))
        case .medium:
            return (.orange, .orange.opacity(0.18))
        case .high:
            return (.red, .red.opacity(0.2))
        }
    }
}

private enum DueDateState {
    case overdue
    case today
    case upcoming

    init?(dueDate: Date?, isCompleted: Bool) {
        guard let dueDate else { return nil }
        guard !isCompleted else { return nil }

        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            self = .today
        } else if dueDate < calendar.startOfDay(for: Date()) {
            self = .overdue
        } else {
            self = .upcoming
        }
    }
}

private struct DateStateBadge: View {
    let state: DueDateState

    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
    }

    private var label: String {
        switch state {
        case .overdue:
            return "Overdue"
        case .today:
            return "Today"
        case .upcoming:
            return "Upcoming"
        }
    }

    private var foreground: Color {
        switch state {
        case .overdue:
            return .red
        case .today:
            return .orange
        case .upcoming:
            return .blue
        }
    }

    private var background: Color {
        switch state {
        case .overdue:
            return .red.opacity(0.15)
        case .today:
            return .orange.opacity(0.15)
        case .upcoming:
            return .blue.opacity(0.15)
        }
    }
}

private extension View {
    @ViewBuilder
    func scrollContentBackgroundIfAvailable() -> some View {
        if #available(macOS 14.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

#Preview {
    ContentView()
}
