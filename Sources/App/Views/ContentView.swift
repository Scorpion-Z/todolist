import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
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

    private enum CompletionFilter: String, CaseIterable, Identifiable {
        case all
        case open
        case completed

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .all:
                return "filter.all"
            case .open:
                return "filter.open"
            case .completed:
                return "filter.completed"
            }
        }
    }

    private enum TimeFilter: String, CaseIterable, Identifiable {
        case anytime
        case today
        case thisWeek
        case overdue

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .anytime:
                return "filter.anytime"
            case .today:
                return "filter.today"
            case .thisWeek:
                return "filter.thisWeek"
            case .overdue:
                return "filter.overdue"
            }
        }
    }

    private enum PriorityFilter: String, CaseIterable, Identifiable {
        case all
        case low
        case medium
        case high

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .all:
                return "filter.all"
            case .low:
                return "priority.low"
            case .medium:
                return "priority.medium"
            case .high:
                return "priority.high"
            }
        }
    }

    private enum LayoutMode: String, CaseIterable, Identifiable {
        case list
        case calendar

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .list:
                return "view.list"
            case .calendar:
                return "view.calendar"
            }
        }
    }

    private enum QuickView: String, CaseIterable, Identifiable {
        case today
        case thisWeek
        case overdue
        case completed

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .today:
                return "filter.today"
            case .thisWeek:
                return "filter.thisWeek"
            case .overdue:
                return "filter.overdue"
            case .completed:
                return "filter.completed"
            }
        }
    }

    private enum AppTab: String, CaseIterable, Identifiable {
        case overview
        case add
        case templates
        case tasks

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .overview:
                return "tab.overview"
            case .add:
                return "tab.add"
            case .templates:
                return "tab.templates"
            case .tasks:
                return "tab.tasks"
            }
        }

        var systemImage: String {
            switch self {
            case .overview:
                return "chart.bar"
            case .add:
                return "plus.circle"
            case .templates:
                return "square.stack"
            case .tasks:
                return "checklist"
            }
        }
    }

    private struct LanguageOption: Identifiable {
        let id: String
        let nameKey: LocalizedStringKey
    }

    private struct TemplateConfig: Identifiable, Codable, Equatable {
        let id: UUID
        var title: String
        var items: [String]
    }

    private struct TemplateSelection: Identifiable, Equatable {
        let id: UUID
        let title: String
        var isSelected: Bool
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
    @State private var completionFilter: CompletionFilter = .all
    @State private var timeFilter: TimeFilter = .anytime
    @State private var priorityFilter: PriorityFilter = .all
    @State private var selectedTagNames: Set<String> = []
    @State private var sortOption: SortOption = .manual
    @AppStorage("layoutMode") private var layoutModeRawValue = LayoutMode.list.rawValue
    @State private var editingItem: TodoItem?
    @State private var inlineEditingItemID: TodoItem.ID?
    @State private var editTitle = ""
    @State private var editPriority: TodoItem.Priority = .medium
    @State private var editDueDateEnabled = false
    @State private var editDueDate = Date()
    @State private var editRepeatRule: TodoItem.RepeatRule = .none
    @State private var editDescription = ""
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
    @State private var exportErrorMessage: String?
    @State private var templates: [TemplateConfig] = []
    @State private var hasLoadedTemplates = false
    @State private var showingTemplateManager = false
    @State private var showingTemplatePreview = false
    @State private var previewTemplate: TemplateConfig?
    @State private var templateSelections: [TemplateSelection] = []
    @AppStorage("templateConfigs") private var storedTemplateConfigs = ""
    @State private var selectedTab: AppTab = .tasks

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasActiveFilters: Bool {
        completionFilter != .all
            || timeFilter != .anytime
            || priorityFilter != .all
            || !selectedTagNames.isEmpty
            || !normalizedSearchText.isEmpty
    }

    private var filteredItems: [TodoItem] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfTomorrow

        let filtered = viewModel.items.filter { item in
            let matchesCompletionFilter: Bool
            switch completionFilter {
            case .all:
                matchesCompletionFilter = true
            case .open:
                matchesCompletionFilter = !item.isCompleted
            case .completed:
                matchesCompletionFilter = item.isCompleted
            }

            guard matchesCompletionFilter else { return false }

            let matchesTimeFilter: Bool
            switch timeFilter {
            case .anytime:
                matchesTimeFilter = true
            case .today:
                guard let dueDate = item.dueDate else { return false }
                matchesTimeFilter = dueDate >= startOfToday && dueDate < startOfTomorrow
            case .thisWeek:
                guard let dueDate = item.dueDate else { return false }
                matchesTimeFilter = dueDate >= startOfToday && dueDate < endOfWeek
            case .overdue:
                guard let dueDate = item.dueDate else { return false }
                matchesTimeFilter = dueDate < startOfToday
            }

            guard matchesTimeFilter else { return false }

            if priorityFilter != .all, priorityFilter.rawValue != item.priority.rawValue {
                return false
            }

            if !selectedTagNames.isEmpty {
                let tagNames = Set(item.tags.map { normalizedTagName($0.name) })
                if tagNames.isDisjoint(with: selectedTagNames) {
                    return false
                }
            }

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

    private var manageTemplateTitle: LocalizedStringKey {
        "template.manager.title"
    }

    private var emptyStateText: (titleKey: LocalizedStringKey, systemImage: String) {
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

    private var layoutMode: LayoutMode {
        get { LayoutMode(rawValue: layoutModeRawValue) ?? .list }
        set { layoutModeRawValue = newValue.rawValue }
    }

    private var layoutModeBinding: Binding<LayoutMode> {
        Binding(
            get: { layoutMode },
            set: { layoutModeRawValue = $0.rawValue }
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                StatsView(viewModel: viewModel)
                quickAddSection
                templateSection

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
                        quickDateFillSection(
                            titleKey: "quickfill.title",
                            setDate: { setQuickDueDate($0) }
                        )
                    }
                    Button("add.button") {
                        viewModel.addItem(
                            title: newTitle,
                            descriptionMarkdown: newDescription,
                            priority: newPriority,
                            dueDate: newDueDateEnabled ? newDueDate : nil
                        )
                        print("Debug: items count \(viewModel.items.count)")
                        newTitle = ""
                        newDescription = ""
                        newPriority = .medium
                        newDueDateEnabled = false
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                }

                quickViewSection

                HStack {
                    Picker("filter.status", selection: $completionFilter) {
                        ForEach(CompletionFilter.allCases) { option in
                            Text(option.titleKey).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("filter.time", selection: $timeFilter) {
                        ForEach(TimeFilter.allCases) { option in
                            Text(option.titleKey).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("filter.priority", selection: $priorityFilter) {
                        ForEach(PriorityFilter.allCases) { option in
                            Text(option.titleKey).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    tagFilterMenu

                    Spacer()

                    Picker("view.mode", selection: layoutModeBinding) {
                        ForEach(LayoutMode.allCases) { option in
                            Text(option.titleKey).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                if (sortOption != .manual || hasActiveFilters) && layoutMode != .calendar {
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
                    if layoutMode == .calendar {
                        CalendarView(
                            items: filteredItems,
                            onDelete: viewModel.deleteItems(withIDs:),
                            onToggleCompletion: viewModel.toggleCompletion(for:),
                            onEdit: beginEditing(_:)
                        )
                    } else {
                        List(selection: $selectedItemID) {
                            Section(sectionTitleKey) {
                                let canReorder = sortOption == .manual && !hasActiveFilters
                                let rows = ForEach(filteredItems) { item in
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
                                                HStack(spacing: 6) {
                                                    ForEach(item.tags) { tag in
                                                        tagLabel(tag)
                                                    }
                                                }
                                            }
                                            if !item.subtasks.isEmpty {
                                                let completedCount = item.subtasks.filter(\.isCompleted).count
                                                tagLabel("\(completedCount)/\(item.subtasks.count)")
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
                                    .tag(item.id)
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
                                .onDelete(perform: deleteItems(at:))
                                if canReorder {
                                    rows.onMove(perform: moveItems(from:to:))
                                } else {
                                    rows
                                }
                            }
                        }
                        .listStyle(.inset)
                    }
                }
            }
            .padding(24)
            .frame(minWidth: 520, minHeight: 420)
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

            Button {
                let trimmed = quickInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    selectedTab = .add
                    quickInputFocused = true
                } else {
                    submitQuickInput()
                }
            } label: {
                Label("quickadd.floating", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .help("quickadd.focus")
            .padding(24)
        }
        .sheet(isPresented: $showingTemplateManager) {
            TemplateManagerView(
                templates: $templates,
                titleKey: manageTemplateTitle
            )
        }
        .sheet(isPresented: $showingTemplatePreview) {
            templatePreviewSheet
        }
        .onAppear(perform: loadTemplatesIfNeeded)
        .onChange(of: templates) { _ in
            persistTemplates()
        }
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

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("template.title")
                    .font(.headline)
                Spacer()
                Button(manageTemplateTitle) {
                    showingTemplateManager = true
                }
                .font(.caption)
            }
            HStack(spacing: 12) {
                ForEach(templates) { template in
                    Button {
                        presentTemplatePreview(template)
                    } label: {
                        Text(template.title)
                    }
                    .buttonStyle(.bordered)
                }
            }
            Text("template.hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var newTodoSection: some View {
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
                quickDateFillSection(
                    titleKey: "quickfill.title",
                    setDate: { setQuickDueDate($0) }
                )
            }
            Button("add.button") {
                let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                viewModel.addItem(
                    title: newTitle,
                    descriptionMarkdown: newDescription,
                    priority: newPriority,
                    dueDate: newDueDateEnabled ? newDueDate : nil
                )
                print("Debug: items count \(viewModel.items.count)")
                newTitle = ""
                newDescription = ""
                newPriority = .medium
                newDueDateEnabled = false
                revealAddedItem()
            }
            .keyboardShortcut(.return, modifiers: [.command])
        }
    }

    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StatsView(viewModel: viewModel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var addTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                quickAddSection
                newTodoSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var templatesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                templateSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tasksTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            quickViewSection

            HStack {
                Picker("filter.status", selection: $completionFilter) {
                    ForEach(CompletionFilter.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("filter.time", selection: $timeFilter) {
                    ForEach(TimeFilter.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("filter.priority", selection: $priorityFilter) {
                    ForEach(PriorityFilter.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.menu)

                tagFilterMenu

                Spacer()

                Picker("view.mode", selection: layoutModeBinding) {
                    ForEach(LayoutMode.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if (sortOption != .manual || hasActiveFilters) && layoutMode != .calendar {
                Text("reorder.notice")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Group {
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
                    if layoutMode == .calendar {
                        CalendarView(
                            items: filteredItems,
                            onDelete: viewModel.deleteItems(withIDs:),
                            onToggleCompletion: viewModel.toggleCompletion(for:),
                            onEdit: beginEditing(_:)
                        )
                    } else {
                        List(selection: $selectedItemID) {
                            Section(sectionTitleKey) {
                                let canReorder = sortOption == .manual && !hasActiveFilters
                                let rows = ForEach(filteredItems) { item in
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
                                                HStack(spacing: 6) {
                                                    ForEach(item.tags) { tag in
                                                        tagLabel(tag)
                                                    }
                                                }
                                            }
                                            if !item.subtasks.isEmpty {
                                                let completedCount = item.subtasks.filter(\.isCompleted).count
                                                tagLabel("\(completedCount)/\(item.subtasks.count)")
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
                                    .tag(item.id)
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
                                .onDelete(perform: deleteItems(at:))
                                if canReorder {
                                    rows.onMove(perform: moveItems(from:to:))
                                } else {
                                    rows
                                }
                            }
                        }
                        .listStyle(.inset)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .searchable(text: $searchText)
        .applySearchFocus($searchFieldFocused)
    }

    private var quickViewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("quickview.title")
                .font(.headline)
            HStack(spacing: 12) {
                ForEach(QuickView.allCases) { quickView in
                    Button(quickView.titleKey) {
                        applyQuickView(quickView)
                    }
                    .buttonStyle(.bordered)
                    .tint(isQuickViewActive(quickView) ? .accentColor : .gray)
                }
            }
        }
    }

    private var tagFilterMenu: some View {
        Menu {
            if viewModel.tags.isEmpty {
                Text("filter.tags.empty")
            } else {
                ForEach(viewModel.tags) { tag in
                    let normalizedName = normalizedTagName(tag.name)
                    Toggle(tag.name, isOn: Binding(
                        get: { selectedTagNames.contains(normalizedName) },
                        set: { isSelected in
                            if isSelected {
                                selectedTagNames.insert(normalizedName)
                            } else {
                                selectedTagNames.remove(normalizedName)
                            }
                        }
                    ))
                }
                if !selectedTagNames.isEmpty {
                    Divider()
                    Button("filter.tags.clear") {
                        selectedTagNames.removeAll()
                    }
                }
            }
        } label: {
            Label(
                selectedTagNames.isEmpty
                    ? String(localized: "filter.tags")
                    : String(format: String(localized: "filter.tags.selected"), selectedTagNames.count),
                systemImage: "tag"
            )
        }
        .menuStyle(.borderlessButton)
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

    private func applyQuickView(_ quickView: QuickView) {
        switch quickView {
        case .today:
            timeFilter = .today
            completionFilter = .open
        case .thisWeek:
            timeFilter = .thisWeek
            completionFilter = .open
        case .overdue:
            timeFilter = .overdue
            completionFilter = .open
        case .completed:
            timeFilter = .anytime
            completionFilter = .completed
        }
    }

    private func isQuickViewActive(_ quickView: QuickView) -> Bool {
        switch quickView {
        case .today:
            return timeFilter == .today && completionFilter == .open
        case .thisWeek:
            return timeFilter == .thisWeek && completionFilter == .open
        case .overdue:
            return timeFilter == .overdue && completionFilter == .open
        case .completed:
            return timeFilter == .anytime && completionFilter == .completed
        }
    }

    private func submitQuickInput() {
        let feedback = viewModel.addQuickItem(rawText: quickInputText)
        guard feedback.created else {
            quickInputHint = String(localized: "quickadd.hint.missingtitle", locale: selectedLocale)
            return
        }
        print("Debug: items count \(viewModel.items.count)")
        revealAddedItem()

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

    private func addSelectedTemplateItems() {
        let selectedItems = templateSelections
            .filter(\.isSelected)
            .map(\.title)
        guard !selectedItems.isEmpty else {
            dismissTemplatePreview()
            return
        }
        viewModel.addTemplateItems(selectedItems)
        revealAddedItem()
        dismissTemplatePreview()
    }

    private func presentTemplatePreview(_ template: TemplateConfig) {
        previewTemplate = template
        templateSelections = template.items.map {
            TemplateSelection(id: UUID(), title: $0, isSelected: true)
        }
        showingTemplatePreview = true
    }

    private func dismissTemplatePreview() {
        showingTemplatePreview = false
        previewTemplate = nil
        templateSelections.removeAll()
    }

    private func selectAllTemplateItems(_ isSelected: Bool) {
        templateSelections = templateSelections.map { selection in
            TemplateSelection(id: selection.id, title: selection.title, isSelected: isSelected)
        }
    }

    private var templatePreviewSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let previewTemplate {
                Text(previewTemplate.title)
                    .font(.headline)
                Text("template.preview.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                List {
                    ForEach($templateSelections) { $selection in
                        Toggle(selection.title, isOn: $selection.isSelected)
                    }
                }
                HStack {
                    Button("template.preview.selectAll") {
                        selectAllTemplateItems(true)
                    }
                    Button("template.preview.clear") {
                        selectAllTemplateItems(false)
                    }
                    Spacer()
                    Button("template.preview.cancel") {
                        dismissTemplatePreview()
                    }
                    Button("template.preview.create") {
                        addSelectedTemplateItems()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(templateSelections.allSatisfy { !$0.isSelected })
                }
            } else {
                Text("template.preview.none")
            }
        }
        .padding()
        .frame(minWidth: 360, minHeight: 360)
        .onDisappear {
            dismissTemplatePreview()
        }
    }

    private func loadTemplatesIfNeeded() {
        guard !hasLoadedTemplates else { return }
        hasLoadedTemplates = true
        if let data = storedTemplateConfigs.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([TemplateConfig].self, from: data),
           !decoded.isEmpty {
            templates = decoded
        } else {
            templates = defaultTemplates(locale: selectedLocale)
            persistTemplates()
        }
    }

    private func persistTemplates() {
        guard let data = try? JSONEncoder().encode(templates),
              let encoded = String(data: data, encoding: .utf8) else {
            return
        }
        storedTemplateConfigs = encoded
    }

    private func defaultTemplates(locale: Locale) -> [TemplateConfig] {
        [
            TemplateConfig(
                id: UUID(),
                title: String(localized: "template.work", locale: locale),
                items: [
                    String(localized: "template.work.item1", locale: locale),
                    String(localized: "template.work.item2", locale: locale),
                    String(localized: "template.work.item3", locale: locale)
                ]
            ),
            TemplateConfig(
                id: UUID(),
                title: String(localized: "template.life", locale: locale),
                items: [
                    String(localized: "template.life.item1", locale: locale),
                    String(localized: "template.life.item2", locale: locale),
                    String(localized: "template.life.item3", locale: locale)
                ]
            ),
            TemplateConfig(
                id: UUID(),
                title: String(localized: "template.shopping", locale: locale),
                items: [
                    String(localized: "template.shopping.item1", locale: locale),
                    String(localized: "template.shopping.item2", locale: locale),
                    String(localized: "template.shopping.item3", locale: locale)
                ]
            )
        ]
    }

    private func setQuickDueDate(_ offsetDays: Int) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let targetDate = calendar.date(byAdding: .day, value: offsetDays, to: startOfToday) else {
            return
        }
        newDueDateEnabled = true
        newDueDate = targetDate
    }

    @ViewBuilder
    private func quickDateFillSection(
        titleKey: LocalizedStringKey,
        setDate: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("quickfill.today") {
                setDate(0)
            }
            Button("quickfill.tomorrow") {
                setDate(1)
            }
            Button("quickfill.nextweek") {
                setDate(7)
            }
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }

    private func clearQuickInput() {
        quickInputText = ""
        quickInputHint = String(localized: "quickadd.hint.example", locale: selectedLocale)
    }

    private func revealAddedItem() {
        completionFilter = .all
        timeFilter = .anytime
        priorityFilter = .all
        selectedTagNames.removeAll()
        searchText = ""
        selectedTab = .tasks
    }

    private func deleteItems(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            filteredItems.indices.contains(index) ? filteredItems[index].id : nil
        }
        guard !ids.isEmpty else { return }
        viewModel.deleteItems(withIDs: ids)
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        let sourceIDs = source.compactMap { index in
            filteredItems.indices.contains(index) ? filteredItems[index].id : nil
        }
        guard !sourceIDs.isEmpty else { return }
        let sourceIndices = IndexSet(sourceIDs.compactMap { id in
            viewModel.items.firstIndex { $0.id == id }
        })
        guard !sourceIndices.isEmpty else { return }
        let targetIndex: Int
        if destination < filteredItems.count {
            let destinationID = filteredItems[destination].id
            targetIndex = viewModel.items.firstIndex { $0.id == destinationID } ?? viewModel.items.count
        } else {
            targetIndex = viewModel.items.count
        }
        viewModel.moveItems(from: sourceIndices, to: targetIndex)
    }

    private struct TemplateManagerView: View {
        @Environment(\.dismiss) private var dismiss
        @Binding var templates: [TemplateConfig]
        let titleKey: LocalizedStringKey

        @State private var isPresentingEditor = false
        @State private var editingTemplate: TemplateConfig?
        @State private var draftTitle = ""
        @State private var draftItems: [String] = []
        @State private var newItemText = ""

        var body: some View {
            NavigationStack {
                List {
                    if templates.isEmpty {
                        Text("template.manager.empty")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(templates) { template in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.title)
                                        .font(.headline)
                                    Text(template.items.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("template.manager.edit") {
                                    startEditing(template)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteTemplates)
                    }
                }
                .navigationTitle(titleKey)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("template.manager.done") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("template.manager.add") {
                            startNewTemplate()
                        }
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                NavigationStack {
                    Form {
                        Section("template.manager.name.section") {
                            TextField(
                                "template.manager.name.placeholder",
                                text: $draftTitle
                            )
                        }

                        Section("template.manager.items.section") {
                            if draftItems.isEmpty {
                                Text("template.manager.items.empty")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(draftItems.indices, id: \.self) { index in
                                    HStack {
                                        TextField(
                                            "template.manager.item.placeholder",
                                            text: Binding(
                                                get: { draftItems[index] },
                                                set: { draftItems[index] = $0 }
                                            )
                                        )
                                        Button(role: .destructive) {
                                            draftItems.remove(at: index)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }

                            HStack {
                                TextField(
                                    "template.manager.newItem.placeholder",
                                    text: $newItemText
                                )
                                Button("template.manager.newItem.add") {
                                    addDraftItem()
                                }
                                .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }
                    .navigationTitle(editingTemplate == nil
                        ? "template.manager.new.title"
                        : "template.manager.edit.title"
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("template.manager.cancel") {
                                isPresentingEditor = false
                            }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button("template.manager.save") {
                                saveTemplate()
                            }
                            .disabled(!canSaveDraft)
                        }
                    }
                }
            }
        }

        private var canSaveDraft: Bool {
            let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedItems = cleanedDraftItems()
            return !trimmedTitle.isEmpty && !cleanedItems.isEmpty
        }

        private func cleanedDraftItems() -> [String] {
            draftItems
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        private func startNewTemplate() {
            editingTemplate = nil
            draftTitle = ""
            draftItems = []
            newItemText = ""
            isPresentingEditor = true
        }

        private func startEditing(_ template: TemplateConfig) {
            editingTemplate = template
            draftTitle = template.title
            draftItems = template.items
            newItemText = ""
            isPresentingEditor = true
        }

        private func addDraftItem() {
            let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            draftItems.append(trimmed)
            newItemText = ""
        }

        private func saveTemplate() {
            let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedItems = cleanedDraftItems()
            guard !trimmedTitle.isEmpty, !cleanedItems.isEmpty else { return }

            if let editingTemplate {
                if let index = templates.firstIndex(where: { $0.id == editingTemplate.id }) {
                    templates[index].title = trimmedTitle
                    templates[index].items = cleanedItems
                }
            } else {
                let newTemplate = TemplateConfig(id: UUID(), title: trimmedTitle, items: cleanedItems)
                templates.append(newTemplate)
            }

            isPresentingEditor = false
        }

        private func deleteTemplates(at offsets: IndexSet) {
            templates.remove(atOffsets: offsets)
        }
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
        // Localization keys used in edit sheet:
        // edit.title, edit.field.title, markdown.description, markdown.preview, priority.label, duedate.label,
        // quickfill.title, quickfill.today, quickfill.tomorrow, quickfill.nextweek, repeat.label,
        // subtasks.title, subtasks.add.placeholder, subtasks.add.button, tags.title,
        // tags.add.placeholder, tags.add.button, edit.cancel, edit.save.
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
            quickDateFillSection(
                titleKey: "quickfill.title",
                setDate: { offset in
                    let calendar = Calendar.current
                    let startOfToday = calendar.startOfDay(for: Date())
                    guard let targetDate = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                        return
                    }
                    editDueDateEnabled = true
                    editDueDate = targetDate
                }
            )
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
                    HStack {
                        Toggle(isOn: Binding(
                            get: { editTags.contains(where: { $0.id == tag.id }) },
                            set: { isSelected in
                                updateTagSelection(tag: tag, isSelected: isSelected)
                            }
                        )) {
                            tagLabel(tag)
                        }
                        Spacer()
                        Menu {
                            ForEach(Tag.TagColor.allCases) { color in
                                Button {
                                    updateTagColor(tag: tag, color: color)
                                } label: {
                                    Label(color.displayNameKey, systemImage: "circle.fill")
                                        .foregroundStyle(color.tint)
                                }
                            }
                        } label: {
                            Circle()
                                .fill(tag.color.tint)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                        }
                        .menuStyle(.borderlessButton)
                    }
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
        if completionFilter == .completed {
            return "section.completed"
        }
        switch timeFilter {
        case .today:
            return "section.dueToday"
        case .thisWeek:
            return "section.thisWeek"
        case .overdue:
            return "section.overdue"
        case .anytime:
            break
        }
        if completionFilter == .open {
            return "section.open"
        }
        return "section.allTodos"
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

    private func tagLabel(_ tag: Tag) -> some View {
        let tint = tag.color.tint
        return Text(tag.name)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15))
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
            let newTag = Tag(name: trimmed, color: nextTagColor())
            editAvailableTags.append(newTag)
            editTags.append(newTag)
        }
        newTagName = ""
    }

    private func updateTagColor(tag: Tag, color: Tag.TagColor) {
        editAvailableTags = editAvailableTags.map { existingTag in
            guard existingTag.id == tag.id else { return existingTag }
            return Tag(id: existingTag.id, name: existingTag.name, color: color)
        }
        editTags = editTags.map { existingTag in
            guard existingTag.id == tag.id else { return existingTag }
            return Tag(id: existingTag.id, name: existingTag.name, color: color)
        }
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
            let normalized = normalizedTagName(tag.name)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            merged.append(tag)
        }
        return merged.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func normalizedTagName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func nextTagColor() -> Tag.TagColor {
        let palette = Tag.TagColor.allCases
        let usedColors = Set(editAvailableTags.map(\.color))
        if let available = palette.first(where: { !usedColors.contains($0) }) {
            return available
        }
        return palette[editAvailableTags.count % palette.count]
    }
}

#Preview {
    ContentView()
}

private extension View {
    @ViewBuilder
    func applySearchFocus(_ isFocused: FocusState<Bool>.Binding) -> some View {
        if #available(macOS 15.0, *) {
            self.searchFocused(isFocused)
        } else {
            self
        }
    }
}
