import SwiftUI

struct QuickAddBarView: View {
    @ObservedObject var store: TaskStore
    let activeSelection: AppShellViewModel.SidebarSelection

    @Binding var selectedTaskID: TodoItem.ID?
    let focusRequestID: Int

    @State private var quickInput = ""
    @State private var hintText = ""
    @State private var showingTemplatePicker = false
    @FocusState private var quickInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundStyle(AppTheme.accentStrong)
                    .accessibilityHidden(true)

                TextField("quickadd.placeholder", text: $quickInput)
                    .textFieldStyle(.plain)
                    .focused($quickInputFocused)
                    .onSubmit(submitQuickInput)

                Button("quickadd.button") {
                    submitQuickInput()
                }
                .buttonStyle(.bordered)
                .disabled(quickInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Menu {
                    Button("template.manager.title") {
                        showingTemplatePicker = true
                    }
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel(Text("template.manager.title"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.glassSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.strokeSubtle, lineWidth: 1)
            )

            if !hintText.isEmpty {
                Text(hintText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .onAppear {
            hintText = String(localized: "quickadd.hint.example")
        }
        .onChange(of: focusRequestID) { _, _ in
            quickInputFocused = true
        }
        .sheet(isPresented: $showingTemplatePicker) {
            TemplatePickerView { titles in
                store.addTemplateItems(
                    titles,
                    preferredMyDayDate: preferredMyDayDate,
                    inListID: targetListID
                )
                selectedTaskID = store.items.last?.id
            }
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

        guard result.created else {
            hintText = String(localized: "quickadd.hint.missingtitle")
            return
        }

        selectedTaskID = result.createdTaskID

        let separator = String(localized: "quickadd.token.separator")
        hintText = result.recognizedTokens.isEmpty
            ? String(localized: "quickadd.hint.unrecognized")
            : String(
                format: String(localized: "quickadd.hint.recognized"),
                result.recognizedTokens.joined(separator: separator)
            )

        quickInput = ""
        quickInputFocused = true
    }
}
