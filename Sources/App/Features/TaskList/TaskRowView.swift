import SwiftUI

struct TaskRowView: View {
    let item: TodoItem
    let isSelected: Bool
    let isInMyDay: Bool
    let onSelect: () -> Void
    let onToggleCompletion: () -> Void
    let onToggleImportant: () -> Void
    let onToggleMyDay: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggleCompletion) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(item.isCompleted ? AppTheme.accentStrong : AppTheme.secondaryText)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(AppTypography.body)
                    .foregroundStyle(item.isCompleted ? AppTheme.secondaryText : .primary)
                    .strikethrough(item.isCompleted, color: AppTheme.secondaryText)

                HStack(spacing: 6) {
                    if item.isImportant {
                        pillLabel("smart.important", tint: .yellow)
                    }

                    if let dueDate = item.dueDate {
                        pillLabel(dueDate, style: .date, tint: dueTint(dueDate: dueDate, isCompleted: item.isCompleted))
                    }

                    pillLabel(item.priority.displayNameKey, tint: priorityTint(item.priority))

                    if isInMyDay {
                        pillLabel("smart.myDay", tint: AppTheme.accentStrong)
                    }

                    if !item.subtasks.isEmpty {
                        let done = item.subtasks.filter(\.isCompleted).count
                        pillLabel("\(done)/\(item.subtasks.count)", tint: AppTheme.secondaryText)
                    }
                }
            }

            Spacer(minLength: 8)

            Button(action: onToggleImportant) {
                Image(systemName: item.isImportant ? "star.fill" : "star")
                    .foregroundStyle(item.isImportant ? .yellow : AppTheme.secondaryText)
            }
            .buttonStyle(.plain)

            Menu {
                Button(item.isCompleted ? "mark.open" : "mark.done", action: onToggleCompletion)
                Button(item.isImportant ? "important.remove" : "important.add", action: onToggleImportant)
                Button(isInMyDay ? "myday.remove" : "myday.add", action: onToggleMyDay)
                Divider()
                Button("delete.button", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 22)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? AppTheme.selectionBackground : AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? AppTheme.focusRing : AppTheme.strokeSubtle, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private func priorityTint(_ priority: TodoItem.Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return AppTheme.secondaryText
        }
    }

    private func dueTint(dueDate: Date, isCompleted: Bool) -> Color {
        if isCompleted {
            return AppTheme.secondaryText
        }
        if dueDate < Calendar.current.startOfDay(for: Date()) {
            return .red
        }
        return AppTheme.secondaryText
    }

    private func pillLabel(_ key: LocalizedStringKey, tint: Color) -> some View {
        Text(key)
            .font(AppTypography.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(AppTheme.pillBackground)
            .clipShape(Capsule())
    }

    private func pillLabel(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(AppTypography.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(AppTheme.pillBackground)
            .clipShape(Capsule())
    }

    private func pillLabel(_ date: Date, style: Text.DateStyle, tint: Color) -> some View {
        Text(date, style: style)
            .font(AppTypography.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(AppTheme.pillBackground)
            .clipShape(Capsule())
    }
}
