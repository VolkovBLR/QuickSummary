internal import CoreData
import SwiftUI

struct RootTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            InputScreen(viewModel: viewModel)
                .tabItem { Label("Ввод", systemImage: "square.and.pencil") }
                .tag(0)
            ResultScreen(viewModel: viewModel)
                .tabItem { Label("Результат", systemImage: "text.alignleft") }
                .tag(1)
            HistoryScreen(viewModel: viewModel)
                .tabItem { Label("История", systemImage: "clock.arrow.circlepath") }
                .tag(2)
        }
        .environment(\.managedObjectContext, viewContext)
    }
}
