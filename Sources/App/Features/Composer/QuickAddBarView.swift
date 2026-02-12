import SwiftUI

struct QuickAddBarView: View {
    @ObservedObject var store: TaskStore
    let activeSelection: AppShellViewModel.SidebarSelection

    @Binding var selectedTaskID: TodoItem.ID?
    let focusRequestID: Int

    @Environment(\.colorScheme) private var colorScheme
    @State private var quickInput = ""
    @FocusState private var quickInputFocused: Bool

    var body: some View {
        let canSubmit = !quickInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .foregroundStyle(palette.primaryText)
                .accessibilityHidden(true)

            TextField("quickadd.placeholder", text: $quickInput)
                .textFieldStyle(.plain)
                .focused($quickInputFocused)
                .onSubmit(submitQuickInput)
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0)

            Button("quickadd.button") {
                guard canSubmit else { return }
                submitQuickInput()
            }
            .buttonStyle(.plain)
            .foregroundStyle(canSubmit ? palette.primaryText : palette.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(palette.rowDefaultBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(palette.separatorBorder, lineWidth: 1)
            )
            .frame(minWidth: ToDoWebMetrics.quickAddActionMinWidth, alignment: .trailing)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
        }
        .padding(.horizontal, ToDoWebMetrics.quickAddHorizontalPadding)
        .padding(.vertical, ToDoWebMetrics.quickAddVerticalPadding)
        .frame(maxWidth: .infinity, minHeight: ToDoWebMetrics.quickAddHeight)
        .background(palette.quickAddBackground)
        .clipShape(RoundedRectangle(cornerRadius: ToDoWebMetrics.quickAddCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ToDoWebMetrics.quickAddCornerRadius, style: .continuous)
                .stroke(quickInputFocused ? palette.quickAddFocusBorder : palette.quickAddBorder, lineWidth: 1)
        )
        .onChange(of: focusRequestID) { _, _ in
            quickInputFocused = true
        }
    }

    private var palette: ToDoWebColors.Palette {
        ToDoWebColors.palette(for: colorScheme)
    }

    private var preferredMyDayDate: Date? {
        if case .smartList(.myDay) = activeSelection {
            return Date()
        }
        return nil
    }

    private var targetListID: UUID? {
        switch activeSelection {
        case .customList(let id):
            return id
        case .smartList:
            return TodoListEntity.defaultTasksListID
        }
    }

    private func submitQuickInput() {
        let result = store.createQuickTask(
            rawText: quickInput,
            preferredMyDayDate: preferredMyDayDate,
            inListID: targetListID
        )

        guard result.created else { return }

        selectedTaskID = result.createdTaskID

        quickInput = ""
        quickInputFocused = true
    }
}
