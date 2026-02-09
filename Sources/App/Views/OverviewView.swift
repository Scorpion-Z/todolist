import SwiftUI

struct OverviewView: View {
    @ObservedObject var viewModel: TodoListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("概览 / 分析")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("这里集中展示进度统计与趋势分析。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            StatsView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    OverviewView(viewModel: TodoListViewModel())
}
