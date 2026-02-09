import SwiftUI

struct CalendarView: View {
    let items: [TodoItem]
    let onDelete: ([TodoItem.ID]) -> Void
    let onToggleCompletion: (TodoItem) -> Void
    let onEdit: (TodoItem) -> Void

    private var groupedItems: [(key: Date?, items: [TodoItem])] {
        let calendar = Calendar.current
        let sortedItems = items.sorted(by: compareItems)
        let grouped = Dictionary(grouping: sortedItems) { item -> Date? in
            guard let dueDate = item.dueDate else { return nil }
            return calendar.startOfDay(for: dueDate)
        }

        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case let (left?, right?):
                return left < right
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (nil, nil):
                return false
            }
        }

        return sortedKeys.compactMap { key in
            guard let items = grouped[key] else { return nil }
            return (key: key, items: items.sorted(by: compareItems))
        }
    }

    var body: some View {
        List {
            ForEach(groupedItems, id: \.key) { section in
                Section(sectionTitle(for: section.key)) {
                    ForEach(section.items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                onToggleCompletion(item)
                            } label: {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title)
                                    .strikethrough(item.isCompleted, color: .secondary)
                                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                                HStack(spacing: 6) {
                                    tagLabel(
                                        item.priority.displayNameKey,
                                        foreground: priorityColor(item.priority)
                                    )
                                    if let dueDate = item.dueDate {
                                        tagLabel(dueDate, style: .date)
                                    }
                                }
                            }
                            Spacer()
                            Button("edit.button") {
                                onEdit(item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 8)
                        .contextMenu {
                            let markKey: LocalizedStringKey = item.isCompleted ? "mark.open" : "mark.done"
                            Button("edit.button") {
                                onEdit(item)
                            }
                            Button(markKey) {
                                onToggleCompletion(item)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { section.items[$0].id }
                        onDelete(ids)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func sectionTitle(for date: Date?) -> LocalizedStringKey {
        guard let date else { return "calendar.section.noduedate" }
        return LocalizedStringKey(date.formatted(date: .complete, time: .omitted))
    }

    private func compareItems(_ lhs: TodoItem, _ rhs: TodoItem) -> Bool {
        let lhsDue = lhs.dueDate ?? .distantFuture
        let rhsDue = rhs.dueDate ?? .distantFuture
        if lhsDue != rhsDue {
            return lhsDue < rhsDue
        }
        if lhs.priority != rhs.priority {
            return priorityRank(lhs.priority) > priorityRank(rhs.priority)
        }
        return lhs.createdAt < rhs.createdAt
    }

    private func priorityRank(_ priority: TodoItem.Priority) -> Int {
        switch priority {
        case .high:
            return 3
        case .medium:
            return 2
        case .low:
            return 1
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

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView(
            items: [],
            onDelete: { _ in },
            onToggleCompletion: { _ in },
            onEdit: { _ in }
        )
    }
}
