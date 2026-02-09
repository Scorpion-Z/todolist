import SwiftUI

struct AppShellView: View {
    @ObservedObject var store: TaskStore

    @StateObject private var shell = AppShellViewModel()
    @State private var quickAddFocusToken = 0
    @FocusState private var searchFocused: Bool
    @AppStorage("appLanguagePreference") private var appLanguagePreference = "system"

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
                TextField("search.placeholder", text: Binding(
                    get: { shell.query.searchText },
                    set: { shell.query.searchText = $0 }
                ))
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
                if !shell.query.searchText.isEmpty {
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
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.surface0)
        .navigationTitle("settings.title")
    }
}

struct RootView: View {
    @StateObject private var store = TaskStore()

    var body: some View {
        AppShellView(store: store)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
