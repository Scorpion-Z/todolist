import CloudKit
import Security
import SwiftUI

struct AppShellView: View {
    @ObservedObject var store: TaskStore

    @StateObject private var shell = AppShellViewModel()
    @State private var detailFocusRequestID = 0
    @State private var searchPresented = false
    @State private var contentWidth: CGFloat = 1400
    @State private var detailWidth: CGFloat = ToDoWebMetrics.detailDefaultWidth
    @State private var detailDragBaseWidth: CGFloat?
    @State private var lastDetailMode: AppShellViewModel.DetailPresentationMode = .hidden

    @AppStorage("appLanguagePreference") private var appLanguagePreference = "system"
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false

    @State private var showingSettings = false
    @State private var showingMyDaySuggestions = false

    private var cloudSyncSupported: Bool { RootView.cloudKitSupported }
    private let inlineDetailThreshold: CGFloat = ToDoWebMetrics.inlineDetailThreshold

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, shell: shell)
                .frame(minWidth: ToDoWebMetrics.sidebarMinWidth)
                .navigationSplitViewColumnWidth(
                    min: ToDoWebMetrics.sidebarMinWidth,
                    ideal: ToDoWebMetrics.sidebarIdealWidth,
                    max: ToDoWebMetrics.sidebarMaxWidth
                )
        } detail: {
            contentColumn
                .navigationTitle("")
                .searchable(
                    text: $shell.searchInput,
                    isPresented: $searchPresented,
                    placement: .toolbar,
                    prompt: Text("search.placeholder")
                )
                .toolbar { taskToolbar }
                .onExitCommand {
                    shell.closeDetail()
                }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .frame(minWidth: 920, minHeight: 700)
        .environment(\.locale, selectedLocale)
        .onChange(of: store.lists) { _, lists in
            let validCustomListIDs = Set(lists.filter { !$0.isSystem }.map(\.id))
            Task { @MainActor in
                shell.reconcileSelection(validCustomListIDs: validCustomListIDs)
            }
        }
        .onChange(of: shell.searchFocusToken) { _, _ in
            Task { @MainActor in
                searchPresented = true
            }
        }
        .onChange(of: store.items) { _, items in
            guard let selectedTaskID = shell.selectedTaskID else { return }
            guard !items.contains(where: { $0.id == selectedTaskID }) else { return }
            Task { @MainActor in
                shell.closeDetail()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoCommandFocusQuickAdd)) { _ in
            shell.requestQuickAddFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoCommandFocusSearch)) { _ in
            shell.requestSearchFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoCommandToggleCompletion)) { _ in
            shell.toggleSelectedTaskCompletion(using: store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoCommandToggleImportant)) { _ in
            shell.toggleSelectedTaskImportant(using: store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoCommandDeleteTask)) { _ in
            shell.deleteSelectedTask(from: store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .todoCommandCloseDetail)) { _ in
            shell.closeDetail()
        }
        .sheet(isPresented: compactDetailPresentedBinding) {
            compactDetailSheet
                .frame(minWidth: 420, minHeight: 560)
        }
        .sheet(isPresented: $showingSettings) {
            settingsSheet
                .frame(minWidth: 460, minHeight: 340)
        }
        .sheet(isPresented: $showingMyDaySuggestions) {
            MyDaySuggestionsSheet(
                suggestions: myDaySuggestions,
                onAdd: { id in
                    store.addTaskToMyDay(id: id)
                    shell.openDetail(for: id)
                    detailFocusRequestID += 1
                    showingMyDaySuggestions = false
                }
            )
            .frame(minWidth: 460, minHeight: 360)
        }
    }

    private var contentColumn: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let mode = shell.detailPresentationMode(for: width, inlineThreshold: inlineDetailThreshold)

            ZStack {
                backgroundLayer
                contentLayout(for: mode)
                    .padding(ToDoWebMetrics.contentPadding)
            }
            .onAppear {
                updateContentWidth(width)
                reconcileDetailPresentation(for: width)
            }
            .onChange(of: width) { _, newWidth in
                updateContentWidth(newWidth)
                reconcileDetailPresentation(for: newWidth)
            }
            .onChange(of: shell.selectedTaskID) { _, _ in
                reconcileDetailPresentation(for: width)
            }
        }
        .clipped()
    }

    private var backgroundLayer: some View {
        Group {
            if let image = AppTheme.backgroundImage(for: activeTheme) {
                image
                    .resizable()
                    .scaledToFill()
                    .overlay(AppTheme.backgroundOverlay)
            } else {
                LinearGradient(
                    colors: AppTheme.gradient(for: activeTheme),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(AppTheme.backgroundOverlay)
            }
        }
    }

    @ViewBuilder
    private func contentLayout(for mode: AppShellViewModel.DetailPresentationMode) -> some View {
        switch mode {
        case .inline:
            HStack(spacing: 0) {
                taskPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                detailResizeHandle
                detailPanel
                    .frame(width: detailWidth)
            }
        case .modal, .hidden:
            taskPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var taskPanel: some View {
        VStack(spacing: 0) {
            taskListHeader
                .padding(.horizontal, ToDoWebMetrics.titleHorizontalPadding)
                .padding(.top, ToDoWebMetrics.titleTopPadding)
                .padding(.bottom, ToDoWebMetrics.titleBottomPadding)

            if visibleTasks.isEmpty {
                ContentUnavailableView("task.empty.title", systemImage: "checklist")
                    .foregroundStyle(Color.white.opacity(0.82))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TaskListView(
                    tasks: visibleTasks,
                    smartList: activeSmartList,
                    customListID: shell.activeCustomListID,
                    showCompletedSection: store.appPrefs.showCompletedSection,
                    selectedTaskID: selectedTaskBinding,
                    store: store
                )
                .padding(.horizontal, 4)
            }

            QuickAddBarView(
                store: store,
                activeSelection: shell.selection,
                selectedTaskID: selectedTaskBinding,
                focusRequestID: shell.quickAddFocusToken
            )
            .padding(.horizontal, ToDoWebMetrics.contentPadding)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .background(AppTheme.panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.strokeSubtle, lineWidth: 1)
        )
    }

    private var detailPanel: some View {
        TaskDetailView(
            store: store,
            selectedTaskID: selectedTaskBinding,
            focusRequestID: detailFocusRequestID
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .background(AppTheme.panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.strokeSubtle, lineWidth: 1)
        )
    }

    private var compactDetailSheet: some View {
        NavigationStack {
            TaskDetailView(
                store: store,
                selectedTaskID: selectedTaskBinding,
                focusRequestID: detailFocusRequestID
            )
            .navigationTitle("detail.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("command.closeDetail") {
                        shell.closeDetail()
                    }
                }
            }
        }
    }

    private var taskListHeader: some View {
        VStack(alignment: .leading, spacing: ToDoWebMetrics.titleSpacing) {
            Text(currentSectionTitle)
                .font(.system(size: ToDoWebMetrics.titleFontSize, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))

            if case .smartList(.myDay) = shell.selection {
                Text(Date(), format: .dateTime.month(.defaultDigits).day(.defaultDigits).weekday(.wide))
                    .font(.system(size: ToDoWebMetrics.subtitleFontSize, weight: .semibold))
                    .foregroundStyle(ToDoWebColors.subtitleText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailResizeHandle: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: ToDoWebMetrics.detailResizeHandleWidth)
            Rectangle()
                .fill(ToDoWebColors.handleLine)
                .frame(width: ToDoWebMetrics.detailResizeLineWidth)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if detailDragBaseWidth == nil {
                        detailDragBaseWidth = detailWidth
                    }
                    let base = detailDragBaseWidth ?? detailWidth
                    let candidate = base - value.translation.width
                    detailWidth = shell.clampedDetailWidth(candidate, contentWidth: contentWidth)
                }
                .onEnded { _ in
                    detailDragBaseWidth = nil
                }
        )
    }

    private var compactDetailPresentedBinding: Binding<Bool> {
        Binding(
            get: {
                shell.detailPresentationMode(for: contentWidth, inlineThreshold: inlineDetailThreshold) == .modal
            },
            set: { presented in
                if !presented {
                    shell.closeDetail()
                }
            }
        )
    }

    private func updateContentWidth(_ width: CGFloat) {
        guard width.isFinite else { return }
        guard abs(contentWidth - width) > 0.5 else { return }
        contentWidth = width
        clampDetailWidth(for: width)
    }

    private func clampDetailWidth(for contentWidth: CGFloat) {
        detailWidth = shell.clampedDetailWidth(detailWidth, contentWidth: contentWidth)
    }

    private func reconcileDetailPresentation(for width: CGFloat) {
        let nextMode = shell.detailPresentationMode(for: width, inlineThreshold: inlineDetailThreshold)
        if shell.shouldResetDetailWidth(previousMode: lastDetailMode, nextMode: nextMode) {
            detailWidth = ToDoWebMetrics.detailDefaultWidth
        }
        if nextMode == .inline {
            clampDetailWidth(for: width)
        }
        lastDetailMode = nextMode
    }

    @ToolbarContentBuilder
    private var taskToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: ToDoWebMetrics.toolbarButtonSpacing) {
                if activeSmartList == .myDay {
                    Button {
                        showingMyDaySuggestions = true
                    } label: {
                        Image(systemName: "lightbulb")
                            .frame(width: ToDoWebMetrics.toolbarButtonSize, height: ToDoWebMetrics.toolbarButtonSize)
                    }
                    .buttonStyle(.plain)
                    .disabled(myDaySuggestions.isEmpty)
                    .accessibilityLabel(Text("myday.suggestions.button"))
                }

                Menu {
                    if shell.selectedTaskID != nil {
                        Button("command.toggleComplete") {
                            shell.toggleSelectedTaskCompletion(using: store)
                        }
                        Button("command.toggleImportant") {
                            shell.toggleSelectedTaskImportant(using: store)
                        }
                        Button("delete.button", role: .destructive) {
                            shell.deleteSelectedTask(from: store)
                        }
                        Divider()
                    }

                    Toggle("task.filter.showcompleted", isOn: Binding(
                        get: { store.appPrefs.showCompletedSection },
                        set: { value in
                            store.setShowCompletedSection(value)
                        }
                    ))

                    Divider()

                    Button("settings.title") {
                        showingSettings = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: ToDoWebMetrics.toolbarButtonSize, height: ToDoWebMetrics.toolbarButtonSize)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel(Text("toolbar.more"))
            }
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

    private var selectedTaskBinding: Binding<TodoItem.ID?> {
        Binding(
            get: { shell.selectedTaskID },
            set: { shell.openDetail(for: $0) }
        )
    }

    private var myDaySuggestions: [MyDaySuggestion] {
        store.myDaySuggestions(limit: 8)
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

    private var activeTheme: ListThemeStyle {
        switch shell.selection {
        case .customList(let id):
            return store.lists.first(where: { $0.id == id })?.theme ?? .graphite
        case .smartList(let list):
            switch list {
            case .myDay:
                return .ocean
            case .planned:
                return .forest
            case .important:
                return .sunrise
            case .completed:
                return .violet
            case .all, .inbox:
                return .graphite
            }
        }
    }
}

private struct MyDaySuggestionsSheet: View {
    let suggestions: [MyDaySuggestion]
    let onAdd: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if suggestions.isEmpty {
                    Text("myday.suggestions.empty")
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    ForEach(suggestions) { suggestion in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.item.title)
                                    .font(AppTypography.sectionTitle)
                                    .lineLimit(1)

                                Text(suggestion.reason.titleKey)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer()

                            Button("myday.suggestions.add") {
                                onAdd(suggestion.item.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("myday.suggestions.title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("template.manager.done") {
                        dismiss()
                    }
                }
            }
        }
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
