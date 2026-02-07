import SwiftUI

struct ContentView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all
        case open
        case completed
        case today
        case upcoming
        case overdue

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .all:
                return "filter.all"
            case .open:
                return "filter.open"
            case .completed:
                return "filter.completed"
            case .today:
                return "filter.today"
            case .upcoming:
                return "filter.upcoming"
            case .overdue:
                return "filter.overdue"
            }
        }
    }

    private enum SortOption: String, CaseIterable, Identifiable {
        case manual
        case dueDate
        case priority
        case createdAt

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .manual:
                return "sort.manual"
            case .dueDate:
                return "sort.duedate"
            case .priority:
                return "sort.priority"
            case .createdAt:
                return "sort.created"
            }
        }
    }

    private struct LanguageOption: Identifiable {
        let id: String
        let nameKey: LocalizedStringKey
    }

    @FocusState private var quickInputFocused: Bool
    @AppStorage("appLanguage") private var appLanguage = Locale.current.language.languageCode?.identifier == "zh" ? "zh-Hans" : "en"
    @StateObject private var viewModel = TodoListViewModel()
    @State private var quickInputText = ""
    @State private var quickInputHint = ""
    @State private var newTitle = ""
    @State private var newPriority: TodoItem.Priority = .medium
    @State private var newDueDateEnabled = false
    @State private var newDueDate = Date()
    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var sortOption: SortOption = .manual
    @State private var editingItem: TodoItem?
    @State private var inlineEditingItemID: TodoItem.ID?
    @State private var editTitle = ""
    @State private var editPriority: TodoItem.Priority = .medium
    @State private var editDueDateEnabled = false
    @State private var editDueDate = Date()
    @State private var itemPendingDelete: TodoItem?
    @State private var showingDeleteConfirmation = false

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

    private let languageOptions: [LanguageOption] = [
        LanguageOption(id: "zh-Hans", nameKey: "language.chinese"),
        LanguageOption(id: "en", nameKey: "language.english"),
    ]

    private var emptyStateText: (titleKey: LocalizedStringKey, systemImage: String) {
        let normalizedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSearchText.isEmpty {
            return ("empty.search", "magnifyingglass")
        }
        if viewModel.items.isEmpty {
            return ("empty.none", "checkmark.circle")
        }
        return ("empty.view", "line.3.horizontal.decrease.circle")
    }

    private var selectedLocale: Locale {
        Locale(identifier: appLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            quickAddSection

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("newtodo.placeholder", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 12) {
                        Picker("priority.label", selection: $newPriority) {
                            ForEach(TodoItem.Priority.allCases) { priority in
                                Text(priority.displayNameKey).tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("duedate.label", isOn: $newDueDateEnabled)
                        if newDueDateEnabled {
                            DatePicker("", selection: $newDueDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                }
                Button("add.button") {
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
                Picker("filter.label", selection: $filter) {
                    ForEach(Filter.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("sort.label", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Spacer()
            }

            if sortOption != .manual {
                Text("reorder.notice")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if filteredItems.isEmpty {
                if #available(macOS 14.0, *) {
                    ContentUnavailableView(emptyStateText.titleKey, systemImage: emptyStateText.systemImage)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: emptyStateText.systemImage)
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(emptyStateText.titleKey)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List {
                    Section(sectionTitleKey) {
                        ForEach(filteredItems) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Button {
                                    viewModel.toggleCompletion(for: item)
                                } label: {
                                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(item.title)
                                        .strikethrough(item.isCompleted, color: .secondary)
                                        .foregroundStyle(item.isCompleted ? .secondary : .primary)

                                    HStack(spacing: 6) {
                                        tagLabel(
                                            item.priority.displayNameKey,
                                            foreground: priorityColor(item.priority)
                                        )
                                        if let dueDate = item.dueDate {
                                            tagLabel(dueDate, style: .date)
                                        }
                                    }
                                }
                                Spacer()
                                Button("edit.button") {
                                    beginEditing(item)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 8)
                            .contextMenu {
                                let markKey: LocalizedStringKey = item.isCompleted ? "mark.open" : "mark.done"
                                Button("edit.button") {
                                    beginEditing(item)
                                }
                                Button(markKey) {
                                    viewModel.toggleCompletion(for: item)
                                }
                            }
                        }
                        .onDelete(perform: viewModel.deleteItems)
                        .onMove(perform: viewModel.moveItems)
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
        .onAppear {
            clearQuickInput()
        }
        .onExitCommand {
            clearQuickInput()
        }
        .onChange(of: appLanguage) { _, _ in
            clearQuickInput()
        }
        .environment(\.locale, selectedLocale)
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("quickadd.placeholder", text: $quickInputText)
                    .textFieldStyle(.roundedBorder)
                    .focused($quickInputFocused)
                    .onSubmit {
                        submitQuickInput()
                    }

                Button("quickadd.button") {
                    submitQuickInput()
                }
                .keyboardShortcut(.return, modifiers: [])
                .help("quickadd.help")
            }

            Text(quickInputHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("quickadd.focus") {
                    quickInputFocused = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("quickadd.clear") {
                    clearQuickInput()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            Text("app.title")
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
            Picker("language.title", selection: $appLanguage) {
                ForEach(languageOptions) { option in
                    Text(option.nameKey).tag(option.id)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }

    private func submitQuickInput() {
        let feedback = viewModel.addQuickItem(rawText: quickInputText)
        guard feedback.created else {
            quickInputHint = String(localized: "quickadd.hint.missingtitle", locale: selectedLocale)
            return
        }

        let tokenSeparator = String(localized: "quickadd.token.separator", locale: selectedLocale)
        quickInputHint = feedback.recognizedTokens.isEmpty
            ? String(localized: "quickadd.hint.unrecognized", locale: selectedLocale)
            : String(
                format: String(localized: "quickadd.hint.recognized", locale: selectedLocale),
                feedback.recognizedTokens.joined(separator: tokenSeparator)
            )

        quickInputText = ""
        quickInputFocused = true
    }

    private func clearQuickInput() {
        quickInputText = ""
        quickInputHint = String(localized: "quickadd.hint.example", locale: selectedLocale)
    }

    private func prepareEditing(_ item: TodoItem) {
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

    private func beginEditingSheet(_ item: TodoItem) {
        prepareEditing(item)
        editingItem = item
    }

    private func beginEditing(_ item: TodoItem) {
        beginEditingSheet(item)
    }

    @ViewBuilder
    private func editSheet(for item: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("edit.title")
                .font(.title2)
            TextField("edit.field.title", text: $editTitle)
                .textFieldStyle(.roundedBorder)
            Picker("priority.label", selection: $editPriority) {
                ForEach(TodoItem.Priority.allCases) { priority in
                    Text(priority.displayNameKey).tag(priority)
                }
            }
            Toggle("duedate.label", isOn: $editDueDateEnabled)
            if editDueDateEnabled {
                DatePicker("", selection: $editDueDate, displayedComponents: .date)
                    .labelsHidden()
            }
            HStack {
                Button("edit.cancel") {
                    editingItem = nil
                }
                Spacer()
                Button("edit.save") {
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

    private func priorityColor(_ priority: TodoItem.Priority) -> Color {
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .gray
        }
    }

    private var sectionTitleKey: LocalizedStringKey {
        switch filter {
        case .all:
            return "section.allTodos"
        case .open:
            return "section.open"
        case .completed:
            return "section.completed"
        case .today:
            return "section.dueToday"
        case .upcoming:
            return "section.upcoming"
        case .overdue:
            return "section.overdue"
        }
    }

    private func tagLabel(
        _ text: LocalizedStringKey,
        foreground: Color = .secondary
    ) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }

    private func tagLabel(
        _ date: Date,
        style: Text.DateStyle,
        foreground: Color = .secondary
    ) -> some View {
        Text(date, style: style)
            .font(.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }
}

#Preview {
    ContentView()
}
