import SwiftUI

struct OverviewDashboardView: View {
    @ObservedObject var store: TaskStore

    private let columns = [
        GridItem(.adaptive(minimum: 220), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryCards
                growthCards
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
        LazyVGrid(columns: columns, spacing: 12) {
            metricCard("stats.total", value: "\(store.totalCount)")
            metricCard("stats.open", value: "\(store.openCount)")
            metricCard("stats.overdue", value: "\(store.overdueCount())")
            metricCard("stats.today.completed.count", value: "\(store.completedTodayCount())")
        }
    }

    private var growthCards: some View {
        HStack(alignment: .top, spacing: 12) {
            myDayMomentumCard
            weeklyReviewCard
        }
    }

    private var myDayMomentumCard: some View {
        let progress = store.myDayProgress()
        let streak = store.completionStreak()

        return VStack(alignment: .leading, spacing: 10) {
            Text("overview.momentum.title")
                .font(AppTypography.sectionTitle)

            Text(String(format: String(localized: "overview.streak.days"), streak))
                .font(.system(size: 22, weight: .semibold))

            if progress.totalCount == 0 {
                Text("myday.progress.empty")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                Text(
                    String(
                        format: String(localized: "myday.progress.count"),
                        progress.completedCount,
                        progress.totalCount
                    )
                )
                .font(AppTypography.body)

                ProgressView(value: progress.completionRate)
                    .tint(AppTheme.accentStrong)

                Text(
                    String(
                        format: String(localized: "overview.completion.rate"),
                        Int((progress.completionRate * 100).rounded())
                    )
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppTheme.secondaryText)
            }
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

    private var weeklyReviewCard: some View {
        let review = store.weeklyReview()

        return VStack(alignment: .leading, spacing: 10) {
            Text("overview.weekly.title")
                .font(AppTypography.sectionTitle)

            Text("overview.weekly.window")
                .font(AppTypography.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text("\(review.startDate, format: .dateTime.month().day()) - \(review.endDate, format: .dateTime.month().day())")
                .font(AppTypography.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Divider()

            statLine("overview.weekly.created", value: review.createdCount)
            statLine("overview.weekly.completed", value: review.completedCount)
            statLine("overview.weekly.carry", value: review.carriedOverCompletedCount)
            statLine("overview.weekly.important", value: review.importantCompletedCount)
            statLine("overview.weekly.overdue", value: review.overdueResolvedCount)
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
                ForEach(suggestions) { suggestion in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.item.title)
                                .font(AppTypography.body)

                            HStack(spacing: 6) {
                                Text(suggestion.reason.titleKey)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(reasonColor(suggestion.reason))

                                if let dueDate = suggestion.item.dueDate {
                                    Text(dueDate, style: .date)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                        }

                        Spacer()

                        Button("myday.add") {
                            store.addToMyDay(id: suggestion.id)
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

    private func reasonColor(_ reason: MyDaySuggestion.Reason) -> Color {
        switch reason {
        case .overdue:
            return .red
        case .dueToday:
            return .orange
        case .important:
            return .yellow
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

    private func statLine(_ key: LocalizedStringKey, value: Int) -> some View {
        HStack {
            Text(key)
                .font(AppTypography.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Text("\(value)")
                .font(AppTypography.body)
                .fontWeight(.semibold)
        }
    }
}
