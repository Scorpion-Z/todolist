import Foundation
import Combine

@MainActor
final class AppShellViewModel: ObservableObject {
    enum SidebarSelection: Hashable {
        case smartList(SmartListID)
        case tag(String)
        case overview
        case settings
    }

    @Published var selection: SidebarSelection
    @Published var selectedTaskID: TodoItem.ID?
    @Published var query: TaskQuery
    @Published var useGlobalSearch: Bool
    @Published var searchInput: String

    private var cancellables = Set<AnyCancellable>()

    init(
        selection: SidebarSelection = .smartList(.myDay),
        selectedTaskID: TodoItem.ID? = nil,
        query: TaskQuery = TaskQuery(),
        useGlobalSearch: Bool = false
    ) {
        self.selection = selection
        self.selectedTaskID = selectedTaskID
        self.query = query
        self.useGlobalSearch = useGlobalSearch
        self.searchInput = query.searchText

        bindSearchDebounce()
    }

    var activeList: SmartListID {
        switch selection {
        case .smartList(let list):
            return list
        case .tag:
            return .all
        case .overview, .settings:
            return .all
        }
    }

    var activeTagName: String? {
        switch selection {
        case .tag(let name):
            return name
        default:
            return nil
        }
    }

    var showingTaskArea: Bool {
        switch selection {
        case .smartList, .tag:
            return true
        case .overview, .settings:
            return false
        }
    }

    func select(_ selection: SidebarSelection) {
        self.selection = selection
        if case .overview = selection {
            selectedTaskID = nil
            return
        }
        if case .settings = selection {
            selectedTaskID = nil
        }
    }

    func clearSearch() {
        searchInput = ""
        query.searchText = ""
    }

    func deleteSelectedTask(from store: TaskStore) {
        guard let selectedTaskID else { return }
        store.deleteTasks(ids: [selectedTaskID])
        self.selectedTaskID = nil
    }

    func toggleSelectedTaskCompletion(using store: TaskStore) {
        guard let selectedTaskID else { return }
        store.toggleCompletion(id: selectedTaskID)
    }

    func toggleSelectedTaskImportant(using store: TaskStore) {
        guard let selectedTaskID else { return }
        store.toggleImportant(id: selectedTaskID)
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
