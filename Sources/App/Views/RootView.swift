import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = TodoListViewModel()

    var body: some View {
        TabView {
            ContentView(viewModel: viewModel)
                .tabItem {
                    Label("nav.home", systemImage: "checklist")
                }

            AnalyticsView(viewModel: viewModel)
                .tabItem {
                    Label("nav.analytics", systemImage: "chart.bar.xaxis")
                }
        }
    }
}

#Preview {
    RootView()
}
