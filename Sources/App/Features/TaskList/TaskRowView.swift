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
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onToggleCompletion) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(item.isCompleted ? Color.white.opacity(0.95) : Color.white.opacity(0.75))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(item.isCompleted ? "mark.open" : "mark.done"))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(AppTypography.body)
                    .foregroundStyle(item.isCompleted ? Color.white.opacity(0.64) : Color.white.opacity(0.95))
                    .strikethrough(item.isCompleted, color: Color.white.opacity(0.6))

                HStack(spacing: 6) {
                    if let dueDate = item.dueDate {
                        Text(dueDate, style: .date)
                            .font(AppTypography.caption)
                            .foregroundStyle(dueTint(dueDate: dueDate, isCompleted: item.isCompleted))
                    }

                    if isInMyDay {
                        Text("smart.myDay")
                            .font(AppTypography.caption)
                            .foregroundStyle(ToDoWebColors.secondaryText)
                    }

                    if !item.subtasks.isEmpty {
                        let done = item.subtasks.filter(\.isCompleted).count
                        Text("\(done)/\(item.subtasks.count)")
                            .font(AppTypography.caption)
                            .foregroundStyle(ToDoWebColors.secondaryText)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button(action: onToggleImportant) {
                    Image(systemName: item.isImportant ? "star.fill" : "star")
                        .foregroundStyle(item.isImportant ? .yellow : Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.isImportant ? "important.remove" : "important.add"))

                Menu {
                    Button(item.isCompleted ? "mark.open" : "mark.done", action: onToggleCompletion)
                    Button(item.isImportant ? "important.remove" : "important.add", action: onToggleImportant)
                    Button(isInMyDay ? "myday.remove" : "myday.add", action: onToggleMyDay)
                    Divider()
                    Button("delete.button", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.white.opacity(0.6))
                        .frame(width: 22)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel(Text("toolbar.more"))
            }
            .opacity(actionControlsVisible ? 1 : 0)
            .allowsHitTesting(actionControlsVisible)
            .animation(ToDoWebMotion.hoverFade, value: actionControlsVisible)
        }
        .padding(.horizontal, ToDoWebMetrics.taskRowHorizontalPadding)
        .padding(.vertical, ToDoWebMetrics.taskRowVerticalPadding)
        .frame(minHeight: ToDoWebMetrics.taskRowMinHeight)
        .background(rowBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: ToDoWebMetrics.taskRowCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ToDoWebMetrics.taskRowCornerRadius, style: .continuous)
                .stroke(rowBorderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
#if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
#endif
    }

    private var actionControlsVisible: Bool {
        isHovered
    }

    private var rowBackgroundColor: Color {
        if isSelected {
            return ToDoWebColors.rowSelectedBackground
        }
        return isHovered ? ToDoWebColors.rowHoverBackground : ToDoWebColors.rowDefaultBackground
    }

    private var rowBorderColor: Color {
        isSelected ? ToDoWebColors.rowSelectedBorder : ToDoWebColors.rowDefaultBorder
    }

    private func dueTint(dueDate: Date, isCompleted: Bool) -> Color {
        if isCompleted {
            return ToDoWebColors.secondaryText
        }
        if dueDate < Calendar.current.startOfDay(for: Date()) {
            return Color.red.opacity(0.95)
        }
        return ToDoWebColors.secondaryText
    }
}
