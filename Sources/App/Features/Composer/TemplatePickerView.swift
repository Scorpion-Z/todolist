import SwiftUI

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("templateConfigs") private var storedTemplateConfigs = ""

    let onInsert: ([String]) -> Void

    @State private var templates: [TemplateConfig] = []
    @State private var hasLoadedTemplates = false
    @State private var isPresentingEditor = false
    @State private var editingTemplate: TemplateConfig?
    @State private var draftTitle = ""
    @State private var draftItemsText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("template.title") {
                    if templates.isEmpty {
                        Text("template.manager.empty")
                            .foregroundStyle(AppTheme.secondaryText)
                    } else {
                        ForEach(templates) { template in
                            Button {
                                onInsert(template.items)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.title)
                                        .font(AppTypography.sectionTitle)
                                    Text(template.items.joined(separator: " · "))
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .lineLimit(2)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("template.manager.edit") {
                                    startEditing(template)
                                }
                                Button("delete.button", role: .destructive) {
                                    deleteTemplate(template)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("template.manager.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("template.manager.done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("template.manager.add") {
                        startCreating()
                    }
                }
            }
            .onAppear(perform: loadTemplatesIfNeeded)
            .onChange(of: templates) { _, _ in
                persistTemplates()
            }
            .sheet(isPresented: $isPresentingEditor) {
                templateEditor
            }
        }
    }

    private var templateEditor: some View {
        NavigationStack {
            Form {
                Section("template.manager.name.section") {
                    TextField("template.manager.name.placeholder", text: $draftTitle)
                }

                Section("template.manager.items.section") {
                    TextEditor(text: $draftItemsText)
                        .frame(minHeight: 140)
                    Text("template.editor.items.hint")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .navigationTitle(editingTemplate == nil ? "template.manager.new.title" : "template.manager.edit.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("template.manager.cancel") {
                        isPresentingEditor = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("template.manager.save") {
                        saveTemplate()
                    }
                    .disabled(!canSaveTemplate)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 320)
    }

    private var canSaveTemplate: Bool {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && !parsedDraftItems.isEmpty
    }

    private var parsedDraftItems: [String] {
        draftItemsText
            .split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func loadTemplatesIfNeeded() {
        guard !hasLoadedTemplates else { return }
        hasLoadedTemplates = true

        if let data = storedTemplateConfigs.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([TemplateConfig].self, from: data),
           !decoded.isEmpty {
            templates = decoded
            return
        }

        templates = defaultTemplates(locale: Locale.autoupdatingCurrent)
    }

    private func persistTemplates() {
        guard let data = try? JSONEncoder().encode(templates),
              let encoded = String(data: data, encoding: .utf8) else {
            return
        }

        storedTemplateConfigs = encoded
    }

    private func startCreating() {
        editingTemplate = nil
        draftTitle = ""
        draftItemsText = ""
        isPresentingEditor = true
    }

    private func startEditing(_ template: TemplateConfig) {
        editingTemplate = template
        draftTitle = template.title
        draftItemsText = template.items.joined(separator: "\n")
        isPresentingEditor = true
    }

    private func saveTemplate() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = parsedDraftItems

        guard !title.isEmpty, !items.isEmpty else { return }

        if let editingTemplate,
           let index = templates.firstIndex(where: { $0.id == editingTemplate.id }) {
            templates[index].title = title
            templates[index].items = items
        } else {
            templates.append(TemplateConfig(id: UUID(), title: title, items: items))
        }

        isPresentingEditor = false
    }

    private func deleteTemplate(_ template: TemplateConfig) {
        templates.removeAll { $0.id == template.id }
    }

    private func defaultTemplates(locale: Locale) -> [TemplateConfig] {
        [
            TemplateConfig(
                id: UUID(),
                title: String(localized: "template.work", locale: locale),
                items: [
                    String(localized: "template.work.item1", locale: locale),
                    String(localized: "template.work.item2", locale: locale),
                    String(localized: "template.work.item3", locale: locale),
                ]
            ),
            TemplateConfig(
                id: UUID(),
                title: String(localized: "template.life", locale: locale),
                items: [
                    String(localized: "template.life.item1", locale: locale),
                    String(localized: "template.life.item2", locale: locale),
                    String(localized: "template.life.item3", locale: locale),
                ]
            ),
            TemplateConfig(
                id: UUID(),
                title: String(localized: "template.shopping", locale: locale),
                items: [
                    String(localized: "template.shopping.item1", locale: locale),
                    String(localized: "template.shopping.item2", locale: locale),
                    String(localized: "template.shopping.item3", locale: locale),
                ]
            ),
        ]
    }
}

struct TemplateConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var items: [String]
}
