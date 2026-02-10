import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var shell: AppShellViewModel
    private let queryEngine = ListQueryEngine()

    var body: some View {
        List(selection: selectionBinding) {
            Section("list.section.smart") {
                smartListRow(.myDay)
                smartListRow(.important)
                smartListRow(.planned)
                smartListRow(.completed)
                smartListRow(.all)
            }

            Section("list.section.tags") {
                if store.tags.isEmpty {
                    Text("filter.tags.empty")
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    ForEach(store.tags) { tag in
                        Label {
                            Text(tag.name)
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(tag.color.tint)
                        }
                        .tag(AppShellViewModel.SidebarSelection.tag(tag.name))
                    }
                }
            }

            Section("list.section.insights") {
                Label("overview.title", systemImage: "chart.bar.xaxis")
                    .tag(AppShellViewModel.SidebarSelection.overview)
            }

            Section("list.section.settings") {
                Label("settings.title", systemImage: "gearshape")
                    .tag(AppShellViewModel.SidebarSelection.settings)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(AppTheme.sidebarBackground)
    }

    private func smartListRow(_ list: SmartListID) -> some View {
        HStack(spacing: 8) {
            Label(list.titleKey, systemImage: list.systemImage)

            Spacer(minLength: 8)

            let total = count(for: list)
            if total > 0 {
                Text("\(total)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
            .tag(AppShellViewModel.SidebarSelection.smartList(list))
    }

    private var selectionBinding: Binding<AppShellViewModel.SidebarSelection?> {
        Binding(
            get: { shell.selection },
            set: { newValue in
                guard let newValue else { return }
                shell.select(newValue)
            }
        )
    }

    private func count(for list: SmartListID) -> Int {
        queryEngine.tasks(
            from: store.items,
            list: list,
            query: TaskQuery(searchText: "", sort: .manual, tagFilter: [], showCompleted: true),
            selectedTag: nil,
            useGlobalSearch: false
        ).count
    }
}
