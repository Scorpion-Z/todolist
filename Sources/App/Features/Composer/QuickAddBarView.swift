import SwiftUI

struct QuickAddBarView: View {
    @ObservedObject var store: TaskStore
    let activeSelection: AppShellViewModel.SidebarSelection

    @Binding var selectedTaskID: TodoItem.ID?
    let focusRequestID: Int

    @State private var quickInput = ""
    @FocusState private var quickInputFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .foregroundStyle(Color.white.opacity(0.9))
                .accessibilityHidden(true)

            TextField("quickadd.placeholder", text: $quickInput)
                .textFieldStyle(.plain)
                .focused($quickInputFocused)
                .onSubmit(submitQuickInput)
                .foregroundStyle(Color.white.opacity(0.96))

            Button("quickadd.button") {
                submitQuickInput()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.white.opacity(0.82))
            .disabled(quickInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, ToDoWebMetrics.quickAddHorizontalPadding)
        .padding(.vertical, ToDoWebMetrics.quickAddVerticalPadding)
        .frame(minHeight: ToDoWebMetrics.quickAddHeight)
        .background(ToDoWebColors.quickAddBackground)
        .clipShape(RoundedRectangle(cornerRadius: ToDoWebMetrics.quickAddCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ToDoWebMetrics.quickAddCornerRadius, style: .continuous)
                .stroke(quickInputFocused ? ToDoWebColors.quickAddFocusBorder : ToDoWebColors.quickAddBorder, lineWidth: 1)
        )
        .onChange(of: focusRequestID) { _, _ in
            quickInputFocused = true
        }
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
