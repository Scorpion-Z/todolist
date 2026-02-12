import CloudKit
import Security
import SwiftUI

struct AppShellView: View {
    @ObservedObject var store: TaskStore

    @StateObject private var shell = AppShellViewModel()
    @State private var quickAddFocusRequestID = 0

    @AppStorage("appLanguagePreference") private var appLanguagePreference = "system"
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false

    @State private var showingSettings = false
    @State private var showingThemePicker = false

    private var cloudSyncSupported: Bool { RootView.cloudKitSupported }

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, shell: shell)
                .frame(minWidth: 260)
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1180, minHeight: 760)
        .environment(\.locale, selectedLocale)
        .onChange(of: store.lists) { _, lists in
            let validCustomListIDs = Set(lists.filter { !$0.isSystem }.map(\.id))
            shell.reconcileSelection(validCustomListIDs: validCustomListIDs)
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoCommandNewTask)) { _ in
            handleNewTaskCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoCommandToggleCompletion)) { _ in
            guard shell.showingTaskArea else { return }
            shell.toggleSelectedTaskCompletion(using: store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoCommandToggleImportant)) { _ in
            guard shell.showingTaskArea else { return }
            shell.toggleSelectedTaskImportant(using: store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoCommandDeleteTask)) { _ in
            guard shell.showingTaskArea else { return }
            shell.deleteSelectedTask(from: store)
        }
        .sheet(isPresented: $showingSettings) {
            settingsSheet
                .frame(minWidth: 460, minHeight: 340)
        }
        .sheet(isPresented: $showingThemePicker) {
            ThemePickerSheet(
                selectedTheme: effectiveTheme,
                onSelect: { style in
                    if let customID = shell.activeCustomListID {
                        store.setListTheme(id: customID, theme: style)
                    }
                }
            )
            .frame(minWidth: 420, minHeight: 240)
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        if shell.showingTaskArea {
            taskContentColumn
                .navigationTitle(currentSectionTitle)
                .searchable(text: $shell.searchInput, placement: .toolbar, prompt: Text("search.placeholder"))
                .toolbar { taskToolbar }
                .background(AppTheme.surface0)
                .onExitCommand {
                    shell.selectTask(nil)
                }
        } else {
            OverviewDashboardView(store: store)
                .navigationTitle(currentSectionTitle)
                .toolbar { overviewToolbar }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if shell.showingTaskArea {
            TaskDetailView(
                store: store,
                selectedTaskID: Binding(
                    get: { shell.selectedTaskID },
                    set: { shell.selectTask($0) }
                )
            )
            .navigationTitle(String(localized: "detail.title"))
        } else {
            ContentUnavailableView("overview.detail.empty", systemImage: "chart.bar")
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var taskContentColumn: some View {
        VStack(spacing: 12) {
            if case .smartList(.myDay) = shell.selection {
                Text(Date(), format: .dateTime.month(.defaultDigits).day(.defaultDigits).weekday(.wide))
                    .font(AppTypography.subtitle)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if case .smartList(.planned) = shell.selection {
                plannedFilterBar
            }

            Group {
                if visibleTasks.isEmpty {
                    ContentUnavailableView("task.empty.title", systemImage: "checklist")
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TaskListView(
                        tasks: visibleTasks,
                        smartList: activeSmartList,
                        customListID: shell.activeCustomListID,
                        showCompletedSection: store.appPrefs.showCompletedSection,
                        selectedTaskID: Binding(
                            get: { shell.selectedTaskID },
                            set: { shell.selectTask($0) }
                        ),
                        store: store
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            QuickAddBarView(
                store: store,
                activeSelection: shell.selection,
                selectedTaskID: Binding(
                    get: { shell.selectedTaskID },
                    set: { shell.selectTask($0) }
                ),
                focusRequestID: quickAddFocusRequestID
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.surface0)
    }

    @ToolbarContentBuilder
    private var taskToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                handleNewTaskCommand()
            } label: {
                Label("command.newTask", systemImage: "plus")
            }
            .accessibilityLabel(Text("command.newTask"))

            Button {
                shell.toggleSelectedTaskCompletion(using: store)
            } label: {
                Label("command.toggleComplete", systemImage: "checkmark.circle")
            }
            .disabled(shell.selectedTaskID == nil)

            Button {
                shell.toggleSelectedTaskImportant(using: store)
            } label: {
                Label("command.toggleImportant", systemImage: "star")
            }
            .disabled(shell.selectedTaskID == nil)

            Button(role: .destructive) {
                shell.deleteSelectedTask(from: store)
            } label: {
                Label("delete.button", systemImage: "trash")
            }
            .disabled(shell.selectedTaskID == nil)
        }

        ToolbarItemGroup {
            Button {
                showingThemePicker = true
            } label: {
                Image(systemName: "swatchpalette")
            }
            .accessibilityLabel(Text("theme.picker.title"))

            Menu {
                Toggle("task.filter.showcompleted", isOn: Binding(
                    get: { store.appPrefs.showCompletedSection },
                    set: { value in
                        store.setShowCompletedSection(value)
                    }
                ))

                Button("settings.title") {
                    showingSettings = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(Text("toolbar.more"))
        }
    }

    @ToolbarContentBuilder
    private var overviewToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                showingSettings = true
            } label: {
                Label("settings.title", systemImage: "gearshape")
            }
        }
    }

    private var plannedFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(PlannedFilter.allCases) { filter in
                Button {
                    shell.plannedFilter = filter
                } label: {
                    Text(filter.titleKey)
                        .font(AppTypography.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(shell.plannedFilter == filter ? AppTheme.accentSoft : AppTheme.surface1)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var effectiveTheme: ListThemeStyle {
        if let customID = shell.activeCustomListID,
           let list = store.lists.first(where: { $0.id == customID }) {
            return list.theme
        }

        switch shell.selection {
        case .overview:
            return .graphite
        case .smartList(.myDay):
            return .ocean
        case .smartList(.planned):
            return .forest
        case .smartList(.important):
            return .sunrise
        case .smartList(.all), .smartList(.inbox):
            return .graphite
        case .smartList(.completed):
            return .violet
        case .customList:
            return .graphite
        }
    }

    private var activeSmartList: SmartListID? {
        if case .smartList(let smart) = shell.selection {
            return smart
        }
        return nil
    }

    private var visibleTasks: [TodoItem] {
        let selection: TaskStoreSelection
        switch shell.selection {
        case .overview:
            return []
        case .smartList(let smart):
            selection = .smartList(smart)
        case .customList(let id):
            selection = .customList(id)
        }

        return store.tasks(
            for: selection,
            query: shell.query,
            useGlobalSearch: shell.useGlobalSearch,
            plannedFilter: shell.plannedFilter
        )
    }

    private var currentSectionTitle: String {
        switch shell.selection {
        case .overview:
            return String(localized: "overview.title")
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
                return String(localized: "smart.tasks")
            }
        case .customList(let id):
            return store.lists.first(where: { $0.id == id })?.title ?? String(localized: "smart.tasks")
        }
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

    private var settingsSheet: some View {
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
                    .disabled(!cloudSyncSupported)
                Text(syncStatusText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                Text(cloudSyncSupported ? String(localized: "settings.sync.hint") : String(localized: "settings.sync.unavailable.hint"))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Section("settings.account.section") {
                Text(store.profile.displayName)
                Text(store.profile.email)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .formStyle(.grouped)
    }

    private var syncStatusText: String {
        if !cloudSyncSupported {
            return String(localized: "settings.sync.unavailable")
        }
        return cloudSyncEnabled ? String(localized: "settings.sync.state.on") : String(localized: "settings.sync.state.off")
    }

    private func handleNewTaskCommand() {
        if !shell.showingTaskArea {
            shell.select(.smartList(.myDay))
        }
        quickAddFocusRequestID += 1
    }
}

private struct ThemePickerSheet: View {
    let selectedTheme: ListThemeStyle
    let onSelect: (ListThemeStyle) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("theme.picker.title")
                .font(AppTypography.sectionTitle)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                ForEach(ListThemeStyle.allCases) { style in
                    Button {
                        onSelect(style)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LinearGradient(colors: AppTheme.gradient(for: style), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 72)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedTheme == style ? AppTheme.accentStrong : AppTheme.strokeSubtle, lineWidth: 2)
                                )
                            Text(style.titleKey)
                                .font(AppTypography.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(16)
    }
}

struct RootView: View {
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false
    @State private var store: TaskStore
    static let cloudKitSupported = detectCloudKitSupport()
    private static let iCloudContainerEntitlement = "com.apple.developer.icloud-container-identifiers"

    init() {
        let requested = UserDefaults.standard.bool(forKey: "cloudSyncEnabled")
        let enabled = RootView.normalizedSyncEnabled(requested)
        _store = State(initialValue: RootView.makeStore(syncEnabled: enabled))
    }

    var body: some View {
        AppShellView(store: store)
            .id(cloudSyncEnabled)
            .onChange(of: cloudSyncEnabled) { _, enabled in
                let normalized = RootView.normalizedSyncEnabled(enabled)
                if normalized != enabled {
                    cloudSyncEnabled = normalized
                }
                let snapshot = store.items
                store = RootView.makeStore(syncEnabled: normalized, preloadItems: snapshot)
            }
    }

    private static func makeStore(syncEnabled: Bool, preloadItems: [TodoItem] = []) -> TaskStore {
        let local = LocalTodoStorage()
        let storage: TodoStorage
        let shouldUseCloud = normalizedSyncEnabled(syncEnabled)

        if shouldUseCloud {
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

    private static func normalizedSyncEnabled(_ requested: Bool) -> Bool {
        guard requested else { return false }
        guard cloudKitSupported else {
            UserDefaults.standard.set(false, forKey: "cloudSyncEnabled")
            print("CloudKit unavailable. Falling back to local storage.")
            return false
        }
        return true
    }

    private static func detectCloudKitSupport() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        guard let rawValue = SecTaskCopyValueForEntitlement(task, iCloudContainerEntitlement as CFString, nil) else {
            return false
        }

        if let containers = rawValue as? [String] {
            return !containers.isEmpty
        }
        if let containers = rawValue as? [Any] {
            return !containers.isEmpty
        }
        if let container = rawValue as? String {
            return !container.isEmpty
        }

        return false
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
