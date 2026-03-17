internal import CoreData
import SwiftUI

struct RootTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        TabView {
            InputScreen(viewModel: viewModel)
                .tabItem { Label("Ввод", systemImage: "square.and.pencil") }

            ResultScreen(viewModel: viewModel)
                .tabItem { Label("Результат", systemImage: "text.alignleft") }

            HistoryScreen(viewModel: viewModel)
                .tabItem { Label("История", systemImage: "clock.arrow.circlepath") }
        }
        .environment(\.managedObjectContext, viewContext)
    }
}
