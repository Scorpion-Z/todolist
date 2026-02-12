import SwiftUI

struct TaskDetailView: View {
    @ObservedObject var store: TaskStore
    @Binding var selectedTaskID: TodoItem.ID?
    let focusRequestID: Int

    @State private var draft = Draft.empty
    @State private var loadedItemID: UUID?
    @State private var newSubtaskTitle = ""
    @State private var newTagTitle = ""
    @State private var isDraftDirty = false
    @State private var autosaveTask: Task<Void, Never>?
    @State private var isApplyingStoreUpdate = false
    @FocusState private var titleFieldFocused: Bool

    private static let autosaveDelayNanoseconds: UInt64 = 350_000_000

    var body: some View {
        Group {
            if let item = store.item(withID: selectedTaskID) {
                detailEditor(for: item)
            } else {
                detailPlaceholder
            }
        }
        .background(AppTheme.surface0)
        .onAppear(perform: syncDraftFromSelection)
        .onChange(of: selectedTaskID) { _, _ in
            flushDraftIfNeeded(reason: "selectionChanged")
            syncDraftFromSelection()
        }
        .onDisappear {
            flushDraftIfNeeded(reason: "disappear")
            cancelAutosave()
        }
        .onChange(of: focusRequestID) { _, _ in
            guard selectedTaskID != nil else { return }
            titleFieldFocused = true
        }
    }

    private func detailEditor(for item: TodoItem) -> some View {
        Form {
            Section {
                HStack {
                    Text("detail.title")
                        .font(AppTypography.sectionTitle)
                    Spacer()
                    Button("detail.revert") {
                        flushDraftIfNeeded(reason: "revert")
                        loadDraft(from: item)
                    }
                    .buttonStyle(.bordered)
                }

                TextField("edit.field.title", text: binding(\.title))
                    .font(AppTypography.title)
                    .textFieldStyle(.roundedBorder)
                    .focused($titleFieldFocused)

                HStack(spacing: 10) {
                    Toggle("smart.important", isOn: binding(\.isImportant))
                        .toggleStyle(.button)
                    Toggle("smart.myDay", isOn: binding(\.isInMyDay))
                        .toggleStyle(.button)
                }

                Picker("priority.label", selection: binding(\.priority)) {
                    ForEach(TodoItem.Priority.allCases) { priority in
                        Text(priority.displayNameKey).tag(priority)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(
                    "duedate.label",
                    isOn: Binding(
                        get: { draft.dueDate != nil },
                        set: { enabled in
                            if enabled {
                                draft.dueDate = draft.dueDate ?? Date()
                            } else {
                                draft.dueDate = nil
                            }
                            scheduleAutosave()
                        }
                    )
                )

                if draft.dueDate != nil {
                    DatePicker(
                        "duedate.label",
                        selection: Binding(
                            get: { draft.dueDate ?? Date() },
                            set: {
                                draft.dueDate = $0
                                scheduleAutosave()
                            }
                        ),
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                }

                Picker("repeat.label", selection: binding(\.repeatRule)) {
                    ForEach(TodoItem.RepeatRule.allCases) { rule in
                        Text(rule.displayNameKey).tag(rule)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("markdown.description") {
                    TextEditor(text: binding(\.descriptionMarkdown))
                        .frame(minHeight: 140)
            }

            Section("subtasks.title") {
                    if draft.subtasks.isEmpty {
                        Text("subtasks.empty")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        ForEach($draft.subtasks) { $subtask in
                            HStack {
                                Toggle(subtask.title, isOn: $subtask.isCompleted)
                                    .onChange(of: subtask.isCompleted) { _, _ in
                                        scheduleAutosave()
                                    }
                                Spacer()
                                Button(role: .destructive) {
                                    draft.subtasks.removeAll { $0.id == subtask.id }
                                    scheduleAutosave()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        TextField("subtasks.add.placeholder", text: $newSubtaskTitle)
                            .textFieldStyle(.roundedBorder)
                        Button("subtasks.add.button") {
                            let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            draft.subtasks.append(Subtask(title: trimmed))
                            newSubtaskTitle = ""
                            scheduleAutosave()
                        }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
            }

            Section("tags.title") {
                    if draft.availableTags.isEmpty {
                        Text("filter.tags.empty")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        FlowTagLayout(tags: draft.availableTags, selectedTagIDs: Set(draft.tags.map(\.id))) { tag, selected in
                            toggleTag(tag: tag, selected: selected)
                        }
                    }

                    HStack {
                        TextField("tags.add.placeholder", text: $newTagTitle)
                            .textFieldStyle(.roundedBorder)
                        Button("tags.add.button") {
                            let trimmed = newTagTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            let candidate = Tag(name: trimmed, color: nextTagColor())

                            if !draft.availableTags.contains(where: { normalizedTagName($0.name) == normalizedTagName(trimmed) }) {
                                draft.availableTags.append(candidate)
                            }

                            if !draft.tags.contains(where: { normalizedTagName($0.name) == normalizedTagName(trimmed) }) {
                                draft.tags.append(candidate)
                            }

                            newTagTitle = ""
                            scheduleAutosave()
                        }
                        .disabled(newTagTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
            }
        }
        .onAppear {
            if loadedItemID != item.id {
                loadDraft(from: item)
            }
        }
    }

    private var detailPlaceholder: some View {
        ContentUnavailableView("detail.empty.title", systemImage: "square.and.pencil")
            .foregroundStyle(AppTheme.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Draft, Value>) -> Binding<Value> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { newValue in
                draft[keyPath: keyPath] = newValue
                scheduleAutosave()
            }
        )
    }

    private func syncDraftFromSelection() {
        guard let item = store.item(withID: selectedTaskID) else {
            cancelAutosave()
            loadedItemID = nil
            draft = .empty
            isDraftDirty = false
            return
        }

        if loadedItemID != item.id {
            loadDraft(from: item)
        }
    }

    private func loadDraft(from item: TodoItem) {
        cancelAutosave()
        loadedItemID = item.id
        draft = Draft(
            title: item.title,
            descriptionMarkdown: item.descriptionMarkdown,
            priority: item.priority,
            dueDate: item.dueDate,
            repeatRule: item.repeatRule,
            isImportant: item.isImportant,
            isInMyDay: item.myDayDate.map { Calendar.current.isDate($0, inSameDayAs: Date()) } ?? false,
            subtasks: item.subtasks,
            tags: item.tags,
            availableTags: mergeTags(store.tags, item.tags)
        )
        isDraftDirty = false
    }

    private func markDraftDirty() {
        guard loadedItemID != nil else { return }
        isDraftDirty = true
    }

    private func scheduleAutosave(delayNanoseconds: UInt64 = Self.autosaveDelayNanoseconds) {
        guard loadedItemID != nil else { return }
        markDraftDirty()
        autosaveTask?.cancel()
        autosaveTask = Task {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                flushDraftIfNeeded(reason: "debounce")
            }
        }
    }

    private func cancelAutosave() {
        autosaveTask?.cancel()
        autosaveTask = nil
    }

    private func flushDraftIfNeeded(reason _: String) {
        cancelAutosave()
        guard !isApplyingStoreUpdate else { return }
        guard let id = loadedItemID, isDraftDirty else { return }

        let pendingDraft = draft
        let title = pendingDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        isApplyingStoreUpdate = true
        Task { @MainActor in
            store.updateTask(id: id) { item in
                item.title = title
                item.descriptionMarkdown = pendingDraft.descriptionMarkdown
                item.priority = pendingDraft.priority
                item.dueDate = pendingDraft.dueDate
                item.repeatRule = pendingDraft.repeatRule
                item.isImportant = pendingDraft.isImportant
                item.myDayDate = pendingDraft.isInMyDay ? Calendar.current.startOfDay(for: Date()) : nil
                item.subtasks = pendingDraft.subtasks
                item.tags = pendingDraft.tags
            }

            if loadedItemID == id {
                isDraftDirty = false
            }
            isApplyingStoreUpdate = false
        }
    }

    private func toggleTag(tag: Tag, selected: Bool) {
        if selected {
            if !draft.tags.contains(where: { $0.id == tag.id }) {
                draft.tags.append(tag)
            }
        } else {
            draft.tags.removeAll { $0.id == tag.id }
        }
        scheduleAutosave()
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
        let used = Set(draft.availableTags.map(\.color))
        if let firstUnused = palette.first(where: { !used.contains($0) }) {
            return firstUnused
        }
        return palette[draft.availableTags.count % palette.count]
    }

    private struct Draft {
        var title: String
        var descriptionMarkdown: String
        var priority: TodoItem.Priority
        var dueDate: Date?
        var repeatRule: TodoItem.RepeatRule
        var isImportant: Bool
        var isInMyDay: Bool
        var subtasks: [Subtask]
        var tags: [Tag]
        var availableTags: [Tag]

        static let empty = Draft(
            title: "",
            descriptionMarkdown: "",
            priority: .medium,
            dueDate: nil,
            repeatRule: .none,
            isImportant: false,
            isInMyDay: false,
            subtasks: [],
            tags: [],
            availableTags: []
        )
    }
}

private struct FlowTagLayout: View {
    let tags: [Tag]
    let selectedTagIDs: Set<UUID>
    let onSelect: (Tag, Bool) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
            ForEach(tags) { tag in
                Toggle(isOn: Binding(
                    get: { selectedTagIDs.contains(tag.id) },
                    set: { onSelect(tag, $0) }
                )) {
                    Text(tag.name)
                        .font(AppTypography.caption)
                        .lineLimit(1)
                }
                .toggleStyle(.button)
                .tint(tag.color.tint)
            }
        }
    }
}
