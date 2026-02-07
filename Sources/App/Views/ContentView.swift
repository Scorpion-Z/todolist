import SwiftUI
import UniformTypeIdentifiers

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

    private enum ViewMode: String, CaseIterable, Identifiable {
        case today
        case week
        case calendar

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .today:
                return "view.today"
            case .week:
                return "view.week"
            case .calendar:
                return "view.calendar"
            }
        }
    }

    private struct LanguageOption: Identifiable {
        let id: String
        let nameKey: LocalizedStringKey
    }

    @FocusState private var quickInputFocused: Bool
    @FocusState private var searchFieldFocused: Bool
    @AppStorage("appLanguage") private var appLanguage = Locale.current.language.languageCode?.identifier == "zh" ? "zh-Hans" : "en"
    @StateObject private var viewModel = TodoListViewModel()
    @State private var quickInputText = ""
    @State private var quickInputHint = ""
    @State private var newTitle = ""
    @State private var newPriority: TodoItem.Priority = .medium
    @State private var newDueDateEnabled = false
    @State private var newDueDate = Date()
    @State private var newDescription = ""
    @State private var searchText = ""
    @State private var filter: Filter = .all
    @State private var sortOption: SortOption = .manual
    @State private var viewMode: ViewMode = .today
    @State private var editingItem: TodoItem?
    @State private var inlineEditingItemID: TodoItem.ID?
    @State private var editTitle = ""
    @State private var editPriority: TodoItem.Priority = .medium
    @State private var editDueDateEnabled = false
    @State private var editDueDate = Date()
    @State private var editRepeatRule: TodoItem.RepeatRule = .none
    @State private var editSubtasks: [Subtask] = []
    @State private var editTags: [Tag] = []
    @State private var editAvailableTags: [Tag] = []
    @State private var newSubtaskTitle = ""
    @State private var newTagName = ""
    @State private var itemPendingDelete: TodoItem?
    @State private var showingDeleteConfirmation = false
    @State private var selectedItemID: TodoItem.ID?
    @State private var draggingItemID: TodoItem.ID?
    @State private var dropTargetItemID: TodoItem.ID?

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

    private var viewModeItems: [TodoItem] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday

        switch viewMode {
        case .today:
            return filteredItems.filter { item in
                guard let dueDate = item.dueDate else { return false }
                return dueDate >= startOfToday && dueDate < startOfTomorrow
            }
        case .week:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
                return filteredItems
            }
            return filteredItems.filter { item in
                guard let dueDate = item.dueDate else { return false }
                return weekInterval.contains(dueDate)
            }
        case .calendar:
            return filteredItems
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
            StatsView(viewModel: viewModel)
            quickAddSection

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("newtodo.placeholder", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                    Text("markdown.description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $newDescription)
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
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
                        descriptionMarkdown: newDescription,
                        priority: newPriority,
                        dueDate: newDueDateEnabled ? newDueDate : nil
                    )
                    newTitle = ""
                    newDescription = ""
                    newPriority = .medium
                    newDueDateEnabled = false
                }
                .keyboardShortcut(.return, modifiers: [.command])
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

                Picker("view.title", selection: $viewStyle) {
                    ForEach(ViewStyle.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                Picker("view.mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            if sortOption != .manual && viewMode != .calendar {
                Text("reorder.notice")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModeItems.isEmpty {
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
                if viewMode == .calendar {
                    CalendarView(
                        items: viewModeItems,
                        onDelete: viewModel.deleteItems(withIDs:),
                        onToggleCompletion: viewModel.toggleCompletion(for:),
                        onEdit: beginEditing(_:)
                    )
                } else {
                    List {
                        Section(sectionTitleKey) {
                            ForEach(viewModeItems) { item in
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
                                        if !item.tags.isEmpty {
                                            ForEach(item.tags) { tag in
                                                tagLabel(tag.name)
                                            }
                                        }
                                        if !item.subtasks.isEmpty {
                                            let completedCount = item.subtasks.filter(\.isCompleted).count
                                            tagLabel("\(completedCount)/\(item.subtasks.count)")
                                        }
                                        ForEach(item.tags, id: \.self) { tag in
                                            tagLabel(tag)
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
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 420)
        .searchable(text: $searchText)
        .searchFocused($searchFieldFocused)
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
        .alert("export.error.title", isPresented: Binding(get: {
            exportErrorMessage != nil
        }, set: { newValue in
            if !newValue {
                exportErrorMessage = nil
            }
        })) {
            Button("export.error.dismiss") {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "")
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

                Button("search.focus") {
                    searchFieldFocused = true
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("edit.button") {
                    if let item = selectedItem {
                        beginEditing(item)
                    }
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(selectedItem == nil)

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
        editDescription = item.descriptionMarkdown
        if let dueDate = item.dueDate {
            editDueDateEnabled = true
            editDueDate = dueDate
        } else {
            editDueDateEnabled = false
            editDueDate = Date()
        }
        editRepeatRule = item.repeatRule
        editSubtasks = item.subtasks
        editTags = item.tags
        editAvailableTags = mergeTags(viewModel.tags, item.tags)
        newSubtaskTitle = ""
        newTagName = ""
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
            Text("markdown.description")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                TextEditor(text: $editDescription)
                    .frame(minHeight: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("markdown.preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(.init(editDescription))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minWidth: 200, maxWidth: 260)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
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
            Picker("repeat.label", selection: $editRepeatRule) {
                ForEach(TodoItem.RepeatRule.allCases) { rule in
                    Text(rule.displayNameKey).tag(rule)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("subtasks.title")
                    .font(.headline)
                ForEach($editSubtasks) { $subtask in
                    HStack {
                        Toggle(subtask.title, isOn: $subtask.isCompleted)
                        Spacer()
                        Button(role: .destructive) {
                            removeSubtask(subtask)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("subtasks.add.placeholder", text: $newSubtaskTitle)
                        .textFieldStyle(.roundedBorder)
                    Button("subtasks.add.button") {
                        addSubtask()
                    }
                    .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("tags.title")
                    .font(.headline)
                ForEach(editAvailableTags) { tag in
                    Toggle(tag.name, isOn: Binding(
                        get: { editTags.contains(where: { $0.id == tag.id }) },
                        set: { isSelected in
                            updateTagSelection(tag: tag, isSelected: isSelected)
                        }
                    ))
                }
                HStack {
                    TextField("tags.add.placeholder", text: $newTagName)
                        .textFieldStyle(.roundedBorder)
                    Button("tags.add.button") {
                        addTag()
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
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
                        descriptionMarkdown: editDescription,
                        priority: editPriority,
                        dueDate: editDueDateEnabled ? editDueDate : nil,
                        subtasks: editSubtasks,
                        tags: editTags,
                        repeatRule: editRepeatRule
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

    private var selectedItem: TodoItem? {
        guard let selectedItemID else { return nil }
        return filteredItems.first { $0.id == selectedItemID }
    }

    private func listRow(for item: TodoItem) -> some View {
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
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItemID = item.id
        }
        .onDrag {
            draggingItemID = item.id
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(
            of: [.text],
            isTargeted: Binding(
                get: { dropTargetItemID == item.id },
                set: { isTargeted in
                    dropTargetItemID = isTargeted ? item.id : (dropTargetItemID == item.id ? nil : dropTargetItemID)
                }
            ),
            perform: { _ in
                dropTargetItemID = nil
                draggingItemID = nil
                return false
            }
        )
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

    private func rowBackground(for item: TodoItem) -> some View {
        let isSelected = selectedItemID == item.id
        let isDragging = draggingItemID == item.id
        let isDropTarget = dropTargetItemID == item.id

        return RoundedRectangle(cornerRadius: 12)
            .fill(isDragging ? Color.accentColor.opacity(0.15) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDropTarget ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isDragging)
            .animation(.easeInOut(duration: 0.2), value: isDropTarget)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var sectionTitleKey: LocalizedStringKey {
        switch viewMode {
        case .today:
            return "view.section.today"
        case .week:
            return "view.section.week"
        case .calendar:
            break
        }

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
        _ text: String,
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

    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        editSubtasks.append(Subtask(title: trimmed))
        newSubtaskTitle = ""
    }

    private func removeSubtask(_ subtask: Subtask) {
        editSubtasks.removeAll { $0.id == subtask.id }
    }

    private func addTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let existingIndex = editAvailableTags.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            let existing = editAvailableTags[existingIndex]
            if !editTags.contains(where: { $0.id == existing.id }) {
                editTags.append(existing)
            }
        } else {
            let newTag = Tag(name: trimmed)
            editAvailableTags.append(newTag)
            editTags.append(newTag)
        }
        newTagName = ""
    }

    private func updateTagSelection(tag: Tag, isSelected: Bool) {
        if isSelected {
            if !editTags.contains(where: { $0.id == tag.id }) {
                editTags.append(tag)
            }
        } else {
            editTags.removeAll { $0.id == tag.id }
        }
    }

    private func mergeTags(_ first: [Tag], _ second: [Tag]) -> [Tag] {
        var seen = Set<String>()
        var merged: [Tag] = []
        for tag in first + second {
            let normalized = tag.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            merged.append(tag)
        }
        return merged.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

#Preview {
    ContentView()
}
