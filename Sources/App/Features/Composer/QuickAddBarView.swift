import SwiftUI

struct QuickAddBarView: View {
    @ObservedObject var store: TaskStore
    let activeList: SmartListID

    @Binding var selectedTaskID: TodoItem.ID?
    @Binding var focusRequestToken: Int

    @State private var quickInput = ""
    @State private var hintText = ""
    @State private var showingTemplatePicker = false
    @FocusState private var quickInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(AppTheme.secondaryText)

                    TextField("quickadd.placeholder", text: $quickInput)
                        .textFieldStyle(.plain)
                        .focused($quickInputFocused)
                        .onSubmit(submitQuickInput)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AppTheme.surface1)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.strokeSubtle, lineWidth: 1)
                )

                Button("quickadd.button") {
                    submitQuickInput()
                }
                .buttonStyle(.borderedProminent)
                .disabled(quickInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Menu {
                    Button("template.manager.title") {
                        showingTemplatePicker = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
            }

            if !hintText.isEmpty {
                Text(hintText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(12)
        .background(AppTheme.surface0)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.strokeSubtle, lineWidth: 1)
        )
        .onAppear {
            hintText = String(localized: "quickadd.hint.example")
        }
        .onChange(of: focusRequestToken) { _, _ in
            quickInputFocused = true
        }
        .sheet(isPresented: $showingTemplatePicker) {
            TemplatePickerView { titles in
                let myDayDate = activeList == .myDay ? Date() : nil
                store.addTemplateItems(titles, preferredMyDayDate: myDayDate)
                selectedTaskID = store.items.last?.id
            }
        }
    }

    private func submitQuickInput() {
        let preferredMyDayDate = activeList == .myDay ? Date() : nil
        let result = store.createQuickTask(rawText: quickInput, preferredMyDayDate: preferredMyDayDate)

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
