import CloudKit
import Security
import SwiftUI

struct AppShellView: View {
    @ObservedObject var store: TaskStore

    @StateObject private var shell = AppShellViewModel()
    @FocusState private var searchFocused: Bool
    @AppStorage("appLanguagePreference") private var appLanguagePreference = "system"
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false

    @State private var showingSettings = false
    @State private var showingThemePicker = false

    private var cloudSyncSupported: Bool { RootView.cloudKitSupported }

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, shell: shell)
                .frame(minWidth: 260)
        } detail: {
            ZStack(alignment: .trailing) {
                mainPanel

                if shell.isDetailDrawerPresented {
                    drawerPanel
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: shell.isDetailDrawerPresented)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1180, minHeight: 760)
        .environment(\.locale, selectedLocale)
        .onChange(of: cloudSyncEnabled) { _, enabled in
            let snapshot = store.items
            _ = snapshot
            // RootView handles re-init; keep here for AppStorage state sync.
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

            if case .smartList(.planned) = shell.selection {
                plannedFilterBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }

            searchBar
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

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
            .padding(.horizontal, 14)

            QuickAddBarView(
                store: store,
                activeSelection: shell.selection,
                selectedTaskID: Binding(
                    get: { shell.selectedTaskID },
                    set: { shell.selectTask($0) }
                )
            )
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .background(mainBackground)
        .onExitCommand {
            shell.closeDrawer()
        }
    }

    private var drawerPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("详情")
                    .font(AppTypography.sectionTitle)
                Spacer()
                Button {
                    shell.closeDrawer()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.surface1)

            TaskDetailView(
                store: store,
                selectedTaskID: Binding(
                    get: { shell.selectedTaskID },
                    set: { shell.selectTask($0) }
                )
            )
        }
        .frame(width: 360)
        .background(AppTheme.surface0)
        .overlay(
            Rectangle()
                .fill(AppTheme.strokeSubtle)
                .frame(width: 1),
            alignment: .leading
        )
        .shadow(color: .black.opacity(0.25), radius: 18, x: -2, y: 0)
    }

    private var headerBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentSectionTitle)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.titleColor(for: effectiveTheme))
                    .lineLimit(1)

                if case .smartList(.myDay) = shell.selection {
                    Text(Date(), format: .dateTime.month(.defaultDigits).day(.defaultDigits).weekday(.wide))
                        .font(AppTypography.subtitle)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    showingThemePicker = true
                } label: {
                    Image(systemName: "swatchpalette")
                }
                .buttonStyle(.bordered)

                Menu {
                    Toggle("显示已完成", isOn: Binding(
                        get: { store.appPrefs.showCompletedSection },
                        set: { value in
                            store.setShowCompletedSection(value)
                        }
                    ))

                    Button("设置") {
                        showingSettings = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
            }
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
                        .background(shell.plannedFilter == filter ? AppTheme.accentSoft : AppTheme.glassSurface)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var searchBar: some View {
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
            .background(AppTheme.glassSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.strokeSubtle, lineWidth: 1)
            )

            Button {
                searchFocused = true
            } label: {
                Label("search.focus", systemImage: "scope")
            }
            .buttonStyle(.bordered)

            Button {
                shell.clearSearch()
            } label: {
                Text("search.clear")
            }
            .buttonStyle(.bordered)
            .disabled(shell.searchInput.isEmpty)

            Spacer()
        }
    }

    private var mainBackground: some View {
        let colors = AppTheme.gradient(for: effectiveTheme)
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                AppTheme.surface0.opacity(0.65)
            )
    }

    private var effectiveTheme: ListThemeStyle {
        if let customID = shell.activeCustomListID,
           let list = store.lists.first(where: { $0.id == customID }) {
            return list.theme
        }

        switch shell.selection {
        case .smartList(.myDay): return .ocean
        case .smartList(.planned): return .forest
        case .smartList(.important): return .sunrise
        case .smartList(.all): return .graphite
        case .smartList(.inbox): return .graphite
        case .smartList(.completed): return .violet
        case .customList: return .graphite
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
        case .smartList(let list):
            switch list {
            case .inbox:
                return String(localized: "smart.inbox")
            case .myDay:
                return String(localized: "smart.myDay")
            case .important:
                return String(localized: "smart.flaggedmail")
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
            Section("语言") {
                Picker("界面语言", selection: $appLanguagePreference) {
                    Text("跟随系统").tag("system")
                    Text("中文").tag("zh-Hans")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
            }

            Section("同步") {
                Toggle("启用 iCloud 同步", isOn: $cloudSyncEnabled)
                    .disabled(!cloudSyncSupported)
                Text(syncStatusText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                Text(cloudSyncSupported ? String(localized: "settings.sync.hint") : String(localized: "settings.sync.unavailable.hint"))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Section("账号") {
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
}

private struct ThemePickerSheet: View {
    let selectedTheme: ListThemeStyle
    let onSelect: (ListThemeStyle) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择主题")
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
