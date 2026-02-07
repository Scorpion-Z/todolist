import SwiftUI

struct CardListView: View {
    let items: [TodoItem]
    let selectedItemID: TodoItem.ID?
    let onToggleCompletion: (TodoItem) -> Void
    let onEdit: (TodoItem) -> Void
    let onDelete: (TodoItem) -> Void
    let onSelect: (TodoItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 240), spacing: 16, alignment: .top),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    card(for: item)
                        .onTapGesture {
                            onSelect(item)
                        }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func card(for item: TodoItem) -> some View {
        let isSelected = selectedItemID == item.id

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    onToggleCompletion(item)
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.plain)

                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isCompleted, color: .secondary)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                Spacer()
            }

            HStack(spacing: 6) {
                tagLabel(item.priority.displayNameKey, foreground: priorityColor(item.priority))
                if let dueDate = item.dueDate {
                    tagLabel(dueDate, style: .date)
                }
            }

            HStack {
                Spacer()
                Button("edit.button") {
                    onEdit(item)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .contextMenu {
            let markKey: LocalizedStringKey = item.isCompleted ? "mark.open" : "mark.done"
            Button("edit.button") {
                onEdit(item)
            }
            Button(markKey) {
                onToggleCompletion(item)
            }
            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Text("delete.button")
            }
        }
    }

    private func priorityColor(_ priority: TodoItem.Priority) -> Color {
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .gray
        }
    }

    private func tagLabel(
        _ text: LocalizedStringKey,
        foreground: Color = .secondary
    ) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }

    private func tagLabel(
        _ date: Date,
        style: Text.DateStyle,
        foreground: Color = .secondary
    ) -> some View {
        Text(date, style: style)
            .font(.caption)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }
}

#Preview {
    CardListView(
        items: [
            TodoItem(title: "Review PR", priority: .high, dueDate: .now.addingTimeInterval(3600)),
            TodoItem(title: "Design mockups", priority: .medium, dueDate: nil),
        ],
        selectedItemID: nil,
        onToggleCompletion: { _ in },
        onEdit: { _ in },
        onDelete: { _ in },
        onSelect: { _ in }
    )
    .padding()
}
