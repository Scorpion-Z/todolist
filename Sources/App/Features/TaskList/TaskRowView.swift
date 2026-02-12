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

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onToggleCompletion) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(item.isCompleted ? palette.primaryText : palette.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(item.isCompleted ? "mark.open" : "mark.done"))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(AppTypography.body)
                    .foregroundStyle(item.isCompleted ? palette.secondaryText : palette.primaryText)
                    .strikethrough(item.isCompleted, color: palette.secondaryText)

                HStack(spacing: 6) {
                    if let dueDate = item.dueDate {
                        Text(dueDate, style: .date)
                            .font(AppTypography.caption)
                            .foregroundStyle(dueTint(dueDate: dueDate, isCompleted: item.isCompleted))
                    }

                    if isInMyDay {
                        Text("smart.myDay")
                            .font(AppTypography.caption)
                            .foregroundStyle(palette.secondaryText)
                    }

                    if !item.subtasks.isEmpty {
                        let done = item.subtasks.filter(\.isCompleted).count
                        Text("\(done)/\(item.subtasks.count)")
                            .font(AppTypography.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button(action: onToggleImportant) {
                    Image(systemName: item.isImportant ? "star.fill" : "star")
                        .foregroundStyle(item.isImportant ? .yellow : palette.secondaryText)
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
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: 22)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel(Text("toolbar.more"))
            }
            .opacity(actionControlsVisible ? 1 : 0)
            .allowsHitTesting(actionControlsVisible)
            .animation(ToDoWebMotion.hoverBezier, value: actionControlsVisible)
        }
        .padding(.horizontal, ToDoWebMetrics.taskRowHorizontalPadding)
        .padding(.vertical, ToDoWebMetrics.taskRowVerticalPadding)
        .frame(maxWidth: .infinity, minHeight: ToDoWebMetrics.taskRowMinHeight, alignment: .leading)
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
            withAnimation(ToDoWebMotion.hoverBezier) {
                isHovered = hovering
            }
        }
#endif
        .animation(ToDoWebMotion.hoverBezier, value: isSelected)
    }

    private var actionControlsVisible: Bool {
        isHovered
    }

    private var rowBackgroundColor: Color {
        if isSelected {
            return palette.rowSelectedBackground
        }
        return isHovered ? palette.rowHoverBackground : palette.rowDefaultBackground
    }

    private var rowBorderColor: Color {
        isSelected ? palette.rowSelectedBorder : palette.separatorBorder
    }

    private func dueTint(dueDate: Date, isCompleted: Bool) -> Color {
        if isCompleted {
            return palette.secondaryText
        }
        if dueDate < Calendar.current.startOfDay(for: Date()) {
            return palette.overdueTint
        }
        return palette.secondaryText
    }

    private var palette: ToDoWebColors.Palette {
        ToDoWebColors.palette(for: colorScheme)
    }
}
