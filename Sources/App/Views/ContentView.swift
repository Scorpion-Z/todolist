import SwiftUI

struct ContentView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case open = "Open"
        case completed = "Completed"
        case today = "Today"
        case upcoming = "Upcoming"
        case overdue = "Overdue"

        var id: String { rawValue }
    }

    private enum SortOption: String, CaseIterable, Identifiable {
        case manual = "Manual"
        case dueDate = "Due Date"
        case priority = "Priority"
        case createdAt = "Created"

        var id: String { rawValue }
    }

    @FocusState private var quickInputFocused: Bool
    @StateObject private var viewModel = TodoListViewModel()
    @State private var quickInputText = ""
    @State private var quickInputHint = "示例：明天 17:00 提交周报 p1"
    @State private var newTitle = ""
    @State private var newPriority: TodoItem.Priority = .medium
    @State private var newDueDateEnabled = false
    @State private var newDueDate = Date()
    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var sortOption: SortOption = .manual
    @State private var editingItem: TodoItem?
    @State private var editTitle = ""
    @State private var editPriority: TodoItem.Priority = .medium
    @State private var editDueDateEnabled = false
    @State private var editDueDate = Date()

    private var filteredItems: [TodoItem] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let normalizedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = viewModel.items.filter { item in
            let matchesCompletionAndDateFilter: Bool
            switch filter {
            case .all:
                matchesCompletionAndDateFilter = true
            case .open:
                matchesCompletionAndDateFilter = !item.isCompleted
            case .completed:
                matchesCompletionAndDateFilter = item.isCompleted
            case .today:
                guard !item.isCompleted, let dueDate = item.dueDate else { return false }
                matchesCompletionAndDateFilter = dueDate >= startOfToday && dueDate < startOfTomorrow
            case .upcoming:
                guard !item.isCompleted, let dueDate = item.dueDate else { return false }
                matchesCompletionAndDateFilter = dueDate >= startOfTomorrow
            case .overdue:
                guard !item.isCompleted, let dueDate = item.dueDate else { return false }
                matchesCompletionAndDateFilter = dueDate < startOfToday
            }

            guard matchesCompletionAndDateFilter else { return false }
            guard !normalizedSearchText.isEmpty else { return true }
            return item.title.localizedCaseInsensitiveContains(normalizedSearchText)
        }

        switch sortOption {
        case .manual:
            return filtered
        case .dueDate:
            return filtered.sorted { lhs, rhs in
                let lhsHasDueDate = lhs.dueDate != nil
                let rhsHasDueDate = rhs.dueDate != nil
                if lhsHasDueDate != rhsHasDueDate {
                    return lhsHasDueDate && !rhsHasDueDate
                }

                let lhsDueDate = lhs.dueDate ?? .distantFuture
                let rhsDueDate = rhs.dueDate ?? .distantFuture
                if lhsDueDate != rhsDueDate {
                    return lhsDueDate < rhsDueDate
                }

                if priorityRank(lhs.priority) != priorityRank(rhs.priority) {
                    return priorityRank(lhs.priority) > priorityRank(rhs.priority)
                }
                return lhs.createdAt < rhs.createdAt
            }
        case .priority:
            return filtered.sorted { lhs, rhs in
                if priorityRank(lhs.priority) != priorityRank(rhs.priority) {
                    return priorityRank(lhs.priority) > priorityRank(rhs.priority)
                }

                let lhsDueDate = lhs.dueDate ?? .distantFuture
                let rhsDueDate = rhs.dueDate ?? .distantFuture
                if lhsDueDate != rhsDueDate {
                    return lhsDueDate < rhsDueDate
                }
                return lhs.createdAt < rhs.createdAt
            }
        case .createdAt:
            return filtered.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return priorityRank(lhs.priority) > priorityRank(rhs.priority)
            }
        }
    }

    private var emptyStateText: (title: String, systemImage: String) {
        let normalizedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSearchText.isEmpty {
            return ("No matching todos", "magnifyingglass")
        }
        if viewModel.items.isEmpty {
            return ("No todos yet", "checkmark.circle")
        }
        return ("This view is empty", "line.3.horizontal.decrease.circle")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            quickAddSection

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
                .pickerStyle(.menu)

                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Spacer()
            }

            if sortOption != .manual {
                Text("Reordering is available only in Manual sort.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if filteredItems.isEmpty {
                if #available(macOS 14.0, *) {
                    ContentUnavailableView(emptyStateText.title, systemImage: emptyStateText.systemImage)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: emptyStateText.systemImage)
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(emptyStateText.title)
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
                    .moveDisabled(sortOption != .manual)
                    .onMove { source, destination in
                        guard sortOption == .manual else { return }
                        viewModel.moveItems(from: source, to: destination)
                    }
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
        .onExitCommand {
            clearQuickInput()
        }
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("快速输入：明天 17:00 提交周报 p1", text: $quickInputText)
                    .textFieldStyle(.roundedBorder)
                    .focused($quickInputFocused)
                    .onSubmit {
                        submitQuickInput()
                    }

                Button("Quick Add") {
                    submitQuickInput()
                }
                .keyboardShortcut(.return, modifiers: [])
                .help("Enter 提交")
            }

            Text(quickInputHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("聚焦快速输入") {
                    quickInputFocused = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("清空") {
                    clearQuickInput()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func submitQuickInput() {
        let feedback = viewModel.addQuickItem(rawText: quickInputText)
        guard feedback.created else {
            quickInputHint = "请输入标题后再提交"
            return
        }

        quickInputHint = feedback.recognizedTokens.isEmpty
            ? "未识别到日期/优先级，已按普通标题创建"
            : "已识别：\(feedback.recognizedTokens.joined(separator: "、"))"

        quickInputText = ""
        quickInputFocused = true
    }

    private func clearQuickInput() {
        quickInputText = ""
        quickInputHint = "示例：明天 17:00 提交周报 p1"
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

    private func priorityRank(_ priority: TodoItem.Priority) -> Int {
        switch priority {
        case .high:
            return 3
        case .medium:
            return 2
        case .low:
            return 1
        }
    }
}

#Preview {
    ContentView()
}
