import SwiftUI

struct TaskDetailView: View {
    @ObservedObject var store: TaskStore
    @Binding var selectedTaskID: TodoItem.ID?
    let focusRequestID: Int

    @State private var draft = Draft.empty
    @State private var loadedItemID: UUID?
    @State private var newSubtaskTitle = ""
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
                VStack(alignment: .leading, spacing: ToDoWebMetrics.detailFieldSpacing) {
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

                    HStack(spacing: ToDoWebMetrics.detailFieldSpacing) {
                        Toggle("smart.important", isOn: binding(\.isImportant))
                            .toggleStyle(.button)
                        Toggle("smart.myDay", isOn: binding(\.isInMyDay))
                            .toggleStyle(.button)
                    }

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
                .padding(.vertical, ToDoWebMetrics.detailSectionSpacing / 2)
            }

            Section("subtasks.title") {
                VStack(alignment: .leading, spacing: ToDoWebMetrics.detailFieldSpacing) {
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
                .padding(.vertical, ToDoWebMetrics.detailSectionSpacing / 2)
            }

            Section("markdown.description") {
                TextEditor(text: binding(\.descriptionMarkdown))
                    .frame(minHeight: 160)
                    .padding(.vertical, ToDoWebMetrics.detailSectionSpacing / 2)
            }
        }
        .formStyle(.grouped)
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
            tags: item.tags
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

        static let empty = Draft(
            title: "",
            descriptionMarkdown: "",
            priority: .medium,
            dueDate: nil,
            repeatRule: .none,
            isImportant: false,
            isInMyDay: false,
            subtasks: [],
            tags: []
        )
    }
}
