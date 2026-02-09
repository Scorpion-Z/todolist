import SwiftUI

struct OverviewDashboardView: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryCards
                suggestionsSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.surface0)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("overview.title")
                .font(.system(size: 28, weight: .bold))
            Text("overview.subtitle")
                .font(AppTypography.subtitle)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            metricCard("stats.total", value: "\(store.totalCount)")
            metricCard("stats.open", value: "\(store.openCount)")
            metricCard("stats.overdue", value: "\(store.overdueCount())")
            metricCard("stats.today.completed.count", value: "\(store.completedTodayCount())")
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("myday.suggestions")
                .font(AppTypography.sectionTitle)

            let suggestions = store.myDaySuggestions(limit: 8)
            if suggestions.isEmpty {
                Text("myday.suggestions.empty")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                ForEach(suggestions) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(AppTypography.body)
                            if let dueDate = item.dueDate {
                                Text(dueDate, style: .date)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                        Spacer()
                        Button("myday.add") {
                            store.addToMyDay(id: item.id)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(12)
                    .background(AppTheme.surface1)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.strokeSubtle, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func metricCard(_ titleKey: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey)
                .font(AppTypography.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.strokeSubtle, lineWidth: 1)
        )
    }
}
