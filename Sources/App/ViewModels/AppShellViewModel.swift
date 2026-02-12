import Foundation
import Combine

@MainActor
final class AppShellViewModel: ObservableObject {
    enum SidebarSelection: Hashable {
        case smartList(SmartListID)
        case customList(UUID)
    }

    @Published var selection: SidebarSelection
    @Published var selectedTaskID: TodoItem.ID?
    @Published var isDetailPresented: Bool
    @Published var query: TaskQuery
    @Published var useGlobalSearch: Bool
    @Published var searchInput: String
    @Published var sidebarSearchText: String
    @Published var plannedFilter: PlannedFilter

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
