internal import CoreData
import SwiftUI

struct HistoryScreen: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HistoryRecord.createdAt, ascending: false)],
        animation: .default
    ) private var history: FetchedResults<HistoryRecord>

    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    ContentUnavailableView(
                        "История пуста",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Сохраненные запросы появятся после первой суммаризации")
                    )
                } else {
                    ForEach(history, id: \.id) { item in
                        Button {
                            viewModel.loadHistoryItem(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.summaryText)
                                    .lineLimit(3)

                                Text(item.createdAt.formatted(date: .numeric, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("\(item.language.uppercased()) • \(item.contentType) • \(item.summaryLength)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Экран истории")
        }
    }

    private func delete(_ item: HistoryRecord) {
        viewContext.delete(item)
        try? viewContext.save()
    }
}
