import Charts
import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: TodoListViewModel

    private var todayCompletedCount: Int {
        viewModel.todayCompletedCount()
    }

    private var todayCompletionRate: Double {
        viewModel.todayCompletionRate()
    }

    private var overdueCount: Int {
        viewModel.overdueCount()
    }

    private var totalCount: Int {
        viewModel.items.count
    }

    private var sevenDayTrend: [TodoListViewModel.DailyCompletionStat] {
        viewModel.sevenDayCompletionTrend()
    }

    private var tagStats: [TodoListViewModel.TagStat] {
        viewModel.tagStats()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryCards
            trendSection
            tagStatsSection
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            StatCard(titleKey: "stats.today.completion.rate", value: todayCompletionRate)
            StatCard(titleKey: "stats.overdue", value: overdueCount)
            StatCard(titleKey: "stats.total", value: totalCount)
        }
    }

    @ViewBuilder
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("stats.trend.title")
                    .font(.headline)
                Spacer()
                (Text("stats.today.completed.count") + Text(" \(todayCompletedCount)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if #available(macOS 13.0, *) {
                Chart(sevenDayTrend) { stat in
                    BarMark(
                        x: .value(String(localized: "stats.chart.date"), stat.date, unit: .day),
                        y: .value(String(localized: "stats.chart.completed"), stat.completedCount)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day(.twoDigits))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 160)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sevenDayTrend) { stat in
                        HStack {
                            Text(stat.date, style: .date)
                            Spacer()
                            Text("\(stat.completedCount)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var tagStatsSection: some View {
        Group {
            if tagStats.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("tag.stats.title")
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(tagStats) { stat in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(stat.tag.color.tint)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stat.tag.name)
                                        .font(.subheadline)
                                    Text(String(format: String(localized: "tag.stats.detail"), stat.completedCount, stat.totalCount))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
    }
}

private struct StatCard: View {
    enum DisplayValue {
        case count(Int)
        case percent(Double)
    }

    let titleKey: LocalizedStringKey
    let displayValue: DisplayValue

    init(titleKey: LocalizedStringKey, value: Int) {
        self.titleKey = titleKey
        self.displayValue = .count(value)
    }

    init(titleKey: LocalizedStringKey, value: Double) {
        self.titleKey = titleKey
        self.displayValue = .percent(value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
            switch displayValue {
            case .count(let value):
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(.semibold)
            case .percent(let value):
                Text(value, format: .percent)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    StatsView(viewModel: TodoListViewModel())
}
