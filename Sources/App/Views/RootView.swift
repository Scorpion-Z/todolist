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

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
