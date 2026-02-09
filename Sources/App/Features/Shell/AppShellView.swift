import CloudKit
import SwiftUI

struct AppShellView: View {
    @ObservedObject var store: TaskStore

    @StateObject private var shell = AppShellViewModel()
    @State private var quickAddFocusToken = 0
    @FocusState private var searchFocused: Bool
    @AppStorage("appLanguagePreference") private var appLanguagePreference = "system"
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false

    private let queryEngine = ListQueryEngine()

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, shell: shell)
                .frame(minWidth: 220)
        } content: {
            centerPane
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1180, minHeight: 720)
        .background(AppTheme.surface0)
        .environment(\.locale, selectedLocale)
    }

    private var centerPane: some View {
        Group {
            switch shell.selection {
            case .overview:
                OverviewDashboardView(store: store)
            case .settings:
                settingsView
            case .smartList, .tag:
                taskPane
            }
        }
        .background(AppTheme.surface0)
    }

    private var detailPane: some View {
        Group {
            if shell.showingTaskArea {
                TaskDetailView(store: store, selectedTaskID: $shell.selectedTaskID)
            } else {
                ContentUnavailableView("detail.empty.title", systemImage: "sidebar.right")
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.surface0)
            }
        }
    }

    private var taskPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            taskHeader

            QuickAddBarView(
                store: store,
                activeList: shell.activeList,
                selectedTaskID: $shell.selectedTaskID,
                focusRequestToken: $quickAddFocusToken
            )

            if showingMyDayEnhancements {
                myDayProgressBanner
                myDaySuggestionsPanel
            }

            taskToolbar

            if visibleTasks.isEmpty {
                ContentUnavailableView("task.empty.title", systemImage: "checklist")
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TaskListView(
                    tasks: visibleTasks,
                    smartList: shell.activeList,
                    selectedTaskID: $shell.selectedTaskID,
                    store: store
                )
                .background(AppTheme.surface0)
            }
        }
        .padding(16)
        .background(AppTheme.surface0)
    }

    private var taskHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(currentSectionTitle)
                    .font(.system(size: 24, weight: .bold))
                Text("task.header.subtitle")
                    .font(AppTypography.subtitle)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Button {
                quickAddFocusToken += 1
            } label: {
                Label("newtask.focus", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)

            Button {
                searchFocused = true
            } label: {
                Label("search.focus", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)

            Button {
                shell.toggleSelectedTaskCompletion(using: store)
            } label: {
                Image(systemName: "checkmark.circle")
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(shell.selectedTaskID == nil)

            Button(role: .destructive) {
                shell.deleteSelectedTask(from: store)
            } label: {
                Image(systemName: "trash")
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(shell.selectedTaskID == nil)
        }
    }

    private var taskToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.secondaryText)
                TextField("search.placeholder", text: $shell.searchInput)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.strokeSubtle, lineWidth: 1)
            )

            Menu {
                Toggle("search.scope.global", isOn: $shell.useGlobalSearch)
                Toggle(
                    "task.filter.showcompleted",
                    isOn: Binding(
                        get: { shell.query.showCompleted },
                        set: { shell.query.showCompleted = $0 }
                    )
                )
                if !shell.searchInput.isEmpty {
                    Button("search.clear") {
                        shell.clearSearch()
                    }
                }
            } label: {
                Image(systemName: shell.useGlobalSearch ? "globe" : "scope")
            }
            .menuStyle(.borderlessButton)

            Picker("sort.label", selection: Binding(
                get: { shell.query.sort },
                set: { shell.query.sort = $0 }
            )) {
                ForEach(TaskSortOption.allCases) { option in
                    Text(option.titleKey).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 170)

            Spacer()
        }
    }

    private var showingMyDayEnhancements: Bool {
        shell.selection == .smartList(.myDay)
    }

    private var myDayProgressBanner: some View {
        let progress = store.myDayProgress()

        return VStack(alignment: .leading, spacing: 8) {
            Text("myday.progress.title")
                .font(AppTypography.sectionTitle)

            if progress.totalCount == 0 {
                Text("myday.progress.empty")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Text(
                    String(
                        format: String(localized: "myday.progress.count"),
                        progress.completedCount,
                        progress.totalCount
                    )
                )
                .font(AppTypography.body)

                ProgressView(value: progress.completionRate)
                    .tint(AppTheme.accentStrong)

                if progress.isAllDone {
                    Text("myday.progress.celebrate")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppTheme.accentStrong)
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.strokeSubtle, lineWidth: 1)
        )
    }

    private var myDaySuggestionsPanel: some View {
        let suggestions = store.myDaySuggestions(limit: 5)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("myday.suggestions")
                    .font(AppTypography.sectionTitle)
                Spacer()
            }

            if suggestions.isEmpty {
                Text("myday.suggestions.empty")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                ForEach(suggestions) { suggestion in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(suggestion.item.title)
                                .font(AppTypography.body)

                            HStack(spacing: 6) {
                                Text(suggestion.reason.titleKey)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(reasonColor(suggestion.reason))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.pillBackground)
                                    .clipShape(Capsule())

                                if let dueDate = suggestion.item.dueDate {
                                    Text(dueDate, style: .date)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                        }

                        Spacer()

                        Button("myday.add") {
                            store.addToMyDay(id: suggestion.id)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(AppTheme.surface0)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.strokeSubtle, lineWidth: 1)
                    )
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.strokeSubtle, lineWidth: 1)
        )
    }

    private func reasonColor(_ reason: MyDaySuggestion.Reason) -> Color {
        switch reason {
        case .overdue:
            return .red
        case .dueToday:
            return .orange
        case .important:
            return .yellow
        }
    }

    private var currentSectionTitle: String {
        switch shell.selection {
        case .smartList(let list):
            switch list {
            case .inbox:
                return String(localized: "smart.inbox")
            case .myDay:
                return String(localized: "smart.myDay")
            case .important:
                return String(localized: "smart.important")
            case .planned:
                return String(localized: "smart.planned")
            case .completed:
                return String(localized: "smart.completed")
            case .all:
                return String(localized: "smart.all")
            }
        case .tag(let tag):
            return "#\(tag)"
        case .overview:
            return String(localized: "overview.title")
        case .settings:
            return String(localized: "settings.title")
        }
    }

    private var visibleTasks: [TodoItem] {
        queryEngine.tasks(
            from: store.items,
            list: shell.activeList,
            query: shell.query,
            selectedTag: shell.activeTagName,
            useGlobalSearch: shell.useGlobalSearch
        )
    }

    private var selectedLocale: Locale {
        switch appLanguagePreference {
        case "zh-Hans":
            return Locale(identifier: "zh-Hans")
        case "en":
            return Locale(identifier: "en")
        default:
            return .autoupdatingCurrent
        }
    }

    private var settingsView: some View {
        Form {
            Section("settings.language.section") {
                Picker("settings.language", selection: $appLanguagePreference) {
                    Text("settings.language.system").tag("system")
                    Text("settings.language.zh").tag("zh-Hans")
                    Text("settings.language.en").tag("en")
                }
                .pickerStyle(.segmented)

                Text("settings.language.hint")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Section("settings.sync.section") {
                Toggle("settings.sync.enable", isOn: $cloudSyncEnabled)

                Label(
                    cloudSyncEnabled ? "settings.sync.state.on" : "settings.sync.state.off",
                    systemImage: cloudSyncEnabled ? "icloud.fill" : "icloud.slash"
                )
                .font(AppTypography.caption)
                .foregroundStyle(cloudSyncEnabled ? AppTheme.accentStrong : AppTheme.secondaryText)

                Text("settings.sync.hint")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.surface0)
        .navigationTitle("settings.title")
    }
}

struct RootView: View {
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false
    @State private var store: TaskStore

    init() {
        let enabled = UserDefaults.standard.bool(forKey: "cloudSyncEnabled")
        _store = State(initialValue: RootView.makeStore(syncEnabled: enabled))
    }

    var body: some View {
        AppShellView(store: store)
            .id(cloudSyncEnabled)
            .onChange(of: cloudSyncEnabled) { _, enabled in
                let snapshot = store.items
                store = RootView.makeStore(syncEnabled: enabled, preloadItems: snapshot)
            }
    }

    private static func makeStore(syncEnabled: Bool, preloadItems: [TodoItem] = []) -> TaskStore {
        let local = LocalTodoStorage()
        let storage: TodoStorage

        if syncEnabled {
            let cloud = CloudTodoStorage(container: CKContainer.default())
            storage = ConflictAwareDualStorage(local: local, cloud: cloud)
        } else {
            storage = local
        }

        if !preloadItems.isEmpty {
            Task {
                await storage.persistItems(preloadItems)
            }
        }

        return TaskStore(items: preloadItems, storage: storage)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
