import SwiftUI

struct AnalyticsView: View {
    @ObservedObject var viewModel: TodoListViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("analytics.title")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                StatsView(viewModel: viewModel)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        AnalyticsView(viewModel: TodoListViewModel())
    }
}
