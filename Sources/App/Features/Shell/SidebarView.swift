import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var shell: AppShellViewModel

    @State private var showingListManagement = false
    @State private var showingProfileEditor = false

    var body: some View {
        let groupedLists = Array(store.groupedCustomLists(searchText: shell.sidebarSearchText).enumerated())

        VStack(spacing: 0) {
            profileHeader
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)

            sidebarSearch
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            List(selection: selectionBinding) {
                Section {
                    smartRow(title: String(localized: "smart.myDay"), icon: "sun.max", selection: .smartList(.myDay), count: store.taskCount(for: .myDay))
                    smartRow(title: String(localized: "smart.planned"), icon: "calendar", selection: .smartList(.planned), count: store.taskCount(for: .planned))
                    smartRow(title: String(localized: "smart.flaggedmail"), icon: "flag", selection: .smartList(.important), count: store.taskCount(for: .important), tint: .red)
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
                                Spacer()
                                Button {
                                    store.toggleGroupCollapsed(id: group.id)
                                } label: {
                                    Image(systemName: group.isCollapsed ? "chevron.down" : "chevron.up")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        Section("我的列表") {
                            ForEach(section.lists) { list in
                                customListRow(list)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(AppTheme.sidebarBackground)

            Divider()

            HStack {
                Button {
                    showingListManagement = true
                } label: {
                    Label("新建列表", systemImage: "plus")
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showingListManagement = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.sidebarBackground)
        }
        .background(AppTheme.sidebarBackground)
        .sheet(isPresented: $showingListManagement) {
            ListManagementSheet(store: store)
                .frame(minWidth: 460, minHeight: 420)
        }
        .sheet(isPresented: $showingProfileEditor) {
            ProfileEditorSheet(store: store)
                .frame(minWidth: 380, minHeight: 260)
        }
    }

    private var profileHeader: some View {
        Button {
            showingProfileEditor = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: store.profile.avatarSystemImage)
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accentStrong)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.profile.displayName.isEmpty ? "Super KaKa" : store.profile.displayName)
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(1)
                    Text(store.profile.email)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var sidebarSearch: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.secondaryText)
            TextField(String(localized: "search.placeholder"), text: $shell.sidebarSearchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.strokeSubtle, lineWidth: 1)
        )
    }

    private func smartRow(
        title: String,
        icon: String,
        selection: AppShellViewModel.SidebarSelection,
        count: Int,
        tint: Color = .primary
    ) -> some View {
        HStack(spacing: 8) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(tint)
            }

            Spacer(minLength: 8)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .contentShape(Rectangle())
        .tag(selection)
    }

    private func customListRow(_ list: TodoListEntity) -> some View {
        HStack(spacing: 8) {
            Label {
                Text(list.title)
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
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .contentShape(Rectangle())
        .tag(AppShellViewModel.SidebarSelection.customList(list.id))
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
}

private struct ProfileEditorSheet: View {
    @ObservedObject var store: TaskStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var avatar = "person.crop.circle.fill"

    private let avatars = [
        "person.crop.circle.fill",
        "person.fill",
        "person.2.fill",
        "star.circle.fill"
    ]

    var body: some View {
        Form {
            TextField("昵称", text: $name)
            TextField("邮箱", text: $email)

            Picker("头像", selection: $avatar) {
                ForEach(avatars, id: \.self) { icon in
                    Label(icon, systemImage: icon).tag(icon)
                }
            }
            .pickerStyle(.menu)
        }
        .onAppear {
            name = store.profile.displayName
            email = store.profile.email
            avatar = store.profile.avatarSystemImage
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    store.updateProfile(displayName: name, email: email, avatarSystemImage: avatar)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
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
            Text("列表与分组管理")
                .font(AppTypography.sectionTitle)

            Form {
                Section("新建列表") {
                    TextField("列表名称", text: $listTitle)
                    Picker("所属分组", selection: $selectedGroupID) {
                        Text("无分组").tag(Optional<UUID>.none)
                        ForEach(store.groups) { group in
                            Text(group.title).tag(Optional(group.id))
                        }
                    }

                    Button("创建列表") {
                        store.createList(title: listTitle, groupID: selectedGroupID)
                        listTitle = ""
                    }
                    .disabled(listTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("新建分组") {
                    TextField("分组名称", text: $groupTitle)
                    Button("创建分组") {
                        store.createGroup(title: groupTitle)
                        groupTitle = ""
                    }
                    .disabled(groupTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("已有列表") {
                    ForEach(store.customLists) { list in
                        HStack {
                            Image(systemName: list.icon)
                                .foregroundStyle(AppTheme.color(for: list.theme))
                            Text(list.title)
                            Spacer()
                            Menu {
                                Menu("主题") {
                                    ForEach(ListThemeStyle.allCases) { style in
                                        Button {
                                            store.setListTheme(id: list.id, theme: style)
                                        } label: {
                                            Text(style.titleKey)
                                        }
                                    }
                                }

                                Button("删除", role: .destructive) {
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
                Button("完成") { dismiss() }
            }
        }
        .padding(16)
    }
}
