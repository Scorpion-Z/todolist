import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var shell: AppShellViewModel

    @Environment(\.colorScheme) private var colorScheme
    @State private var showingListManagement = false
    @State private var uiSelection: AppShellViewModel.SidebarSelection?
    @State private var pendingSelection: AppShellViewModel.SidebarSelection?

    var body: some View {
        let groupedLists = Array(store.groupedCustomLists(searchText: shell.sidebarSearchText).enumerated())

        VStack(spacing: 0) {
            profileHeader
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            sidebarSearch
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            List(selection: $uiSelection) {
                Section("list.section.smart") {
                    smartRow(title: String(localized: "smart.myDay"), icon: "sun.max", selection: .smartList(.myDay), count: store.taskCount(for: .myDay))
                    smartRow(title: String(localized: "smart.planned"), icon: "calendar", selection: .smartList(.planned), count: store.taskCount(for: .planned))
                    smartRow(title: String(localized: "smart.important"), icon: "flag", selection: .smartList(.important), count: store.taskCount(for: .important), tint: .red)
                    smartRow(title: String(localized: "smart.tasks"), icon: "house", selection: .smartList(.all), count: store.taskCount(for: .all))
                }

                ForEach(groupedLists, id: \.offset) { entry in
                    let section = entry.element
                    if let group = section.group {
                        Section {
                            if !group.isCollapsed {
                                ForEach(section.lists) { list in
                                    customListRow(list)
                                }
                            }
                        } header: {
                            HStack {
                                Text(group.title)
                                    .foregroundStyle(palette.sidebarTextSecondary)
                                Spacer()
                                Button {
                                    store.toggleGroupCollapsed(id: group.id)
                                } label: {
                                    Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                                        .foregroundStyle(palette.sidebarTextSecondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(group.isCollapsed ? "sidebar.expandGroup" : "sidebar.collapseGroup"))
                            }
                        }
                    } else {
                        Section("list.section.myLists") {
                            ForEach(section.lists) { list in
                                customListRow(list)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(palette.sidebarBackground)

            Rectangle()
                .fill(palette.separatorSecondary)
                .frame(height: 1)

            HStack(spacing: 8) {
                Button {
                    showingListManagement = true
                } label: {
                    Label("list.create", systemImage: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.sidebarTextPrimary)
            }
            .padding(.horizontal, 12)
            .frame(height: ToDoWebMetrics.sidebarFooterHeight)
            .background(palette.sidebarBackground)
        }
        .background(palette.sidebarBackground)
        .onAppear {
            uiSelection = shell.selection
            pendingSelection = nil
        }
        .onChange(of: uiSelection) { _, newValue in
            guard let requested = newValue else { return }
            guard requested != shell.selection else {
                pendingSelection = nil
                return
            }

            pendingSelection = requested
            Task { @MainActor in
                guard pendingSelection == requested else { return }
                shell.select(requested)
                pendingSelection = nil
            }
        }
        .onChange(of: shell.selection) { _, newValue in
            pendingSelection = nil
            if uiSelection != newValue {
                uiSelection = newValue
            }
        }
        .sheet(isPresented: $showingListManagement) {
            ListManagementSheet(store: store)
                .frame(minWidth: 460, minHeight: 420)
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: store.profile.avatarSystemImage)
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.accentStrong)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(store.profile.displayName.isEmpty ? String(localized: "profile.defaultName") : store.profile.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.sidebarTextPrimary)
                    .lineLimit(1)
                Text(store.profile.email)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(palette.sidebarTextSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(height: 40)
    }

    private var sidebarSearch: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(palette.sidebarTextSecondary)
            TextField(String(localized: "search.placeholder"), text: $shell.sidebarSearchText)
                .textFieldStyle(.plain)
                .foregroundStyle(palette.sidebarTextPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: ToDoWebMetrics.sidebarSearchHeight)
        .background(palette.sidebarSearchBackground)
        .clipShape(RoundedRectangle(cornerRadius: ToDoWebMetrics.sidebarSearchCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ToDoWebMetrics.sidebarSearchCornerRadius, style: .continuous)
                .stroke(palette.separatorBorder, lineWidth: 1)
        )
    }

    private func smartRow(
        title: String,
        icon: String,
        selection: AppShellViewModel.SidebarSelection,
        count: Int,
        tint: Color? = nil
    ) -> some View {
        let isSelected = uiSelection == selection
        return HStack(spacing: 8) {
            Label {
                Text(title)
                    .foregroundStyle(palette.sidebarTextPrimary)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(tint ?? palette.sidebarTextPrimary)
            }

            Spacer(minLength: 8)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.sidebarTextSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? palette.sidebarSelectionBackground : palette.sidebarRowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? palette.sidebarSelectionBorder : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .frame(minHeight: ToDoWebMetrics.sidebarRowHeight)
        .tag(selection)
    }

    private func customListRow(_ list: TodoListEntity) -> some View {
        let selection = AppShellViewModel.SidebarSelection.customList(list.id)
        let isSelected = uiSelection == selection
        return HStack(spacing: 8) {
            Label {
                Text(list.title)
                    .foregroundStyle(palette.sidebarTextPrimary)
            } icon: {
                Image(systemName: list.icon)
                    .foregroundStyle(AppTheme.color(for: list.theme))
            }

            Spacer(minLength: 8)

            let count = store.taskCount(forCustomListID: list.id)
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.sidebarTextSecondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? palette.sidebarSelectionBackground : palette.sidebarRowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? palette.sidebarSelectionBorder : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .frame(minHeight: ToDoWebMetrics.sidebarRowHeight)
        .tag(selection)
        .contextMenu {
            Section {
                Menu("theme.picker.title") {
                    ForEach(ListThemeStyle.allCases) { style in
                        Button {
                            store.setListTheme(id: list.id, theme: style)
                        } label: {
                            Text(style.titleKey)
                        }
                    }
                }
            }

            Section {
                Button("delete.button", role: .destructive) {
                    store.deleteList(id: list.id)
                }
            }
        }
    }

    private var palette: ToDoWebColors.Palette {
        ToDoWebColors.palette(for: colorScheme)
    }

}

private struct ListManagementSheet: View {
    @ObservedObject var store: TaskStore
    @Environment(\.dismiss) private var dismiss

    @State private var listTitle = ""
    @State private var groupTitle = ""
    @State private var selectedGroupID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("list.management.title")
                .font(AppTypography.sectionTitle)

            Form {
                Section("list.management.newList.section") {
                    TextField("list.management.newList.name", text: $listTitle)
                    Picker("list.management.newList.group", selection: $selectedGroupID) {
                        Text("list.management.newList.none").tag(Optional<UUID>.none)
                        ForEach(store.groups) { group in
                            Text(group.title).tag(Optional(group.id))
                        }
                    }

                    Button("list.management.newList.create") {
                        store.createList(title: listTitle, groupID: selectedGroupID)
                        listTitle = ""
                    }
                    .disabled(listTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("list.management.newGroup.section") {
                    TextField("list.management.newGroup.name", text: $groupTitle)
                    Button("list.management.newGroup.create") {
                        store.createGroup(title: groupTitle)
                        groupTitle = ""
                    }
                    .disabled(groupTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("list.management.existing.section") {
                    ForEach(store.customLists) { list in
                        HStack {
                            Image(systemName: list.icon)
                                .foregroundStyle(AppTheme.color(for: list.theme))
                            Text(list.title)
                            Spacer()
                            Menu {
                                Menu("theme.picker.title") {
                                    ForEach(ListThemeStyle.allCases) { style in
                                        Button {
                                            store.setListTheme(id: list.id, theme: style)
                                        } label: {
                                            Text(style.titleKey)
                                        }
                                    }
                                }

                                Button("delete.button", role: .destructive) {
                                    store.deleteList(id: list.id)
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("template.manager.done") { dismiss() }
            }
        }
        .padding(16)
    }
}
