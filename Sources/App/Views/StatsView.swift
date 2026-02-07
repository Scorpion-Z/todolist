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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryCards
            trendSection
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            StatCard(title: "今日完成率", value: todayCompletionRate)
            StatCard(title: "逾期", value: overdueCount)
            StatCard(title: "总任务", value: totalCount)
        }
    }

    @ViewBuilder
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("7日完成趋势")
                    .font(.headline)
                Spacer()
                Text("今日完成数 \(todayCompletedCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if #available(macOS 13.0, *) {
                Chart(sevenDayTrend) { stat in
                    BarMark(
                        x: .value("日期", stat.date, unit: .day),
                        y: .value("完成数", stat.completedCount)
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
}

private struct StatCard: View {
    enum DisplayValue {
        case count(Int)
        case percent(Double)
    }

    let title: String
    let displayValue: DisplayValue

    init(title: String, value: Int) {
        self.title = title
        self.displayValue = .count(value)
    }

    init(title: String, value: Double) {
        self.title = title
        self.displayValue = .percent(value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
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
