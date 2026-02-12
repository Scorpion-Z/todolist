import Foundation
import Combine
import CoreGraphics

@MainActor
final class AppShellViewModel: ObservableObject {
    enum SidebarSelection: Hashable {
        case smartList(SmartListID)
        case customList(UUID)
    }

    enum DetailPresentationMode: Equatable {
        case hidden
        case inline
        case modal
    }

    @Published var selection: SidebarSelection
    @Published var selectedTaskID: TodoItem.ID?
    @Published var isDetailPresented: Bool
    @Published var query: TaskQuery
    @Published var useGlobalSearch: Bool
    @Published var searchInput: String
    @Published var sidebarSearchText: String
    @Published var plannedFilter: PlannedFilter
    @Published var quickAddFocusToken: Int
    @Published var searchFocusToken: Int

    private var cancellables = Set<AnyCancellable>()

    init(
        selection: SidebarSelection = .smartList(.myDay),
        selectedTaskID: TodoItem.ID? = nil,
        query: TaskQuery = TaskQuery(showCompleted: true),
        useGlobalSearch: Bool = false
    ) {
        self.selection = selection
        self.selectedTaskID = selectedTaskID
        self.isDetailPresented = selectedTaskID != nil
        self.query = query
        self.useGlobalSearch = useGlobalSearch
        self.searchInput = query.searchText
        self.sidebarSearchText = ""
        self.plannedFilter = .all
        self.quickAddFocusToken = 0
        self.searchFocusToken = 0

        bindSearchDebounce()
    }

    var activeList: SmartListID {
        switch selection {
        case .smartList(let list):
            return list
        case .customList:
            return .all
        }
    }

    var activeCustomListID: UUID? {
        switch selection {
        case .customList(let id):
            return id
        case .smartList:
            return nil
        }
    }

    func select(_ selection: SidebarSelection) {
        self.selection = selection
        plannedFilter = .all
        closeDetail()
    }

    func selectTask(_ id: TodoItem.ID?) {
        openDetail(for: id)
    }

    func openDetail(for id: TodoItem.ID?) {
        selectedTaskID = id
        isDetailPresented = id != nil
    }

    func closeDetail() {
        selectedTaskID = nil
        isDetailPresented = false
    }

    func creationTargetListID(defaultListID: UUID) -> UUID {
        switch selection {
        case .customList(let id):
            return id
        case .smartList:
            return defaultListID
        }
    }

    func clearSearch() {
        searchInput = ""
        query.searchText = ""
    }

    func requestQuickAddFocus() {
        quickAddFocusToken += 1
    }

    func requestSearchFocus() {
        searchFocusToken += 1
    }

    func detailPresentationMode(for width: CGFloat, inlineThreshold: CGFloat = 1240) -> DetailPresentationMode {
        guard selectedTaskID != nil else { return .hidden }
        return width >= inlineThreshold ? .inline : .modal
    }

    func clampedDetailWidth(
        _ width: CGFloat,
        contentWidth: CGFloat,
        minWidth: CGFloat = ToDoWebMetrics.detailMinWidth,
        maxWidth: CGFloat = ToDoWebMetrics.detailMaxWidth,
        maxRatio: CGFloat = ToDoWebMetrics.detailMaxWidthRatio
    ) -> CGFloat {
        let boundedContentWidth = contentWidth.isFinite ? max(contentWidth, 0) : 0
        let ratioBound = max(minWidth, boundedContentWidth * maxRatio)
        let upperBound = min(maxWidth, ratioBound)
        return min(max(width, minWidth), upperBound)
    }

    func shouldResetDetailWidth(previousMode: DetailPresentationMode, nextMode: DetailPresentationMode) -> Bool {
        previousMode == .inline && nextMode == .modal
    }

    func deleteSelectedTask(from store: TaskStore) {
        guard let selectedTaskID else { return }
        store.deleteTasks(ids: [selectedTaskID])
        closeDetail()
    }

    func toggleSelectedTaskCompletion(using store: TaskStore) {
        guard let selectedTaskID else { return }
        store.toggleCompletion(id: selectedTaskID)
    }

    func toggleSelectedTaskImportant(using store: TaskStore) {
        guard let selectedTaskID else { return }
        store.toggleImportant(id: selectedTaskID)
    }

    func reconcileSelection(validCustomListIDs: Set<UUID>) {
        guard case .customList(let id) = selection else { return }
        guard !validCustomListIDs.contains(id) else { return }
        selection = .smartList(.myDay)
        closeDetail()
    }

    private func bindSearchDebounce() {
        $searchInput
            .removeDuplicates()
            .debounce(for: .milliseconds(220), scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.query.searchText = value
            }
            .store(in: &cancellables)
    }
}
