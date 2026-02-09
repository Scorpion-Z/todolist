import SwiftUI

struct TaskDetailView: View {
    @ObservedObject var store: TaskStore
    @Binding var selectedTaskID: TodoItem.ID?

    @State private var draft = Draft.empty
    @State private var loadedItemID: UUID?
    @State private var newSubtaskTitle = ""
    @State private var newTagTitle = ""

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
            syncDraftFromSelection()
        }
    }

    private func detailEditor(for item: TodoItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("detail.title")
                        .font(AppTypography.sectionTitle)
                    Spacer()
                    Button("detail.revert") {
                        loadDraft(from: item)
                    }
                    .buttonStyle(.bordered)
                }

                TextField("edit.field.title", text: binding(\.title))
                    .font(AppTypography.title)
                    .textFieldStyle(.roundedBorder)

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
                            saveDraft()
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
                                saveDraft()
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

                VStack(alignment: .leading, spacing: 6) {
                    Text("markdown.description")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    TextEditor(text: binding(\.descriptionMarkdown))
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(AppTheme.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppTheme.strokeSubtle, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("subtasks.title")
                        .font(AppTypography.sectionTitle)

                    if draft.subtasks.isEmpty {
                        Text("subtasks.empty")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        ForEach($draft.subtasks) { $subtask in
                            HStack {
                                Toggle(subtask.title, isOn: $subtask.isCompleted)
                                    .onChange(of: subtask.isCompleted) { _, _ in
                                        saveDraft()
                                    }
                                Spacer()
                                Button(role: .destructive) {
                                    draft.subtasks.removeAll { $0.id == subtask.id }
                                    saveDraft()
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
                            saveDraft()
                        }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("tags.title")
                        .font(AppTypography.sectionTitle)

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
                            saveDraft()
                        }
                        .disabled(newTagTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(16)
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
                saveDraft()
            }
        )
    }

    private func syncDraftFromSelection() {
        guard let item = store.item(withID: selectedTaskID) else {
            loadedItemID = nil
            draft = .empty
            return
        }

        if loadedItemID != item.id {
            loadDraft(from: item)
        }
    }

    private func loadDraft(from item: TodoItem) {
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
    }

    private func saveDraft() {
        guard let id = loadedItemID else { return }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        store.updateTask(id: id) { item in
            item.title = title
            item.descriptionMarkdown = draft.descriptionMarkdown
            item.priority = draft.priority
            item.dueDate = draft.dueDate
            item.repeatRule = draft.repeatRule
            item.isImportant = draft.isImportant
            item.myDayDate = draft.isInMyDay ? Calendar.current.startOfDay(for: Date()) : nil
            item.subtasks = draft.subtasks
            item.tags = draft.tags
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
        saveDraft()
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
