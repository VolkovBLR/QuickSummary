import SwiftUI

struct ResultScreen: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Длина summary") {
                    Picker("Длина", selection: $viewModel.selectedLength) {
                        ForEach(SummaryLength.allCases) { length in
                            Text(length.title).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Сокращенный текст") {
                    Text(viewModel.currentResult?.summary ?? "Здесь появится summary")
                }

                Section("Ключевые моменты") {
                    if let points = viewModel.currentResult?.keyPoints, !points.isEmpty {
                        ForEach(points, id: \.self) { point in
                            Text("• \(point)")
                        }
                    } else {
                        Text("Ключевые моменты появятся после обработки")
                    }
                }

                Section("Действия") {
                    Button("Копировать / Copy") {
                        viewModel.copySummary()
                    }
                    .disabled(viewModel.currentResult == nil)

                    Button("Поделиться / Share") {
                        viewModel.isSharePresented = true
                    }
                    .disabled(viewModel.currentResult == nil)
                }

                if let result = viewModel.currentResult {
                    Section("Метаданные") {
                        Text("Язык: \(result.language)")
                        Text("Тип: \(result.contentType.rawValue)")
                        Text("Модель: \(result.modelUsed)")
                    }
                }
            }
            .sheet(isPresented: $viewModel.isSharePresented) {
                ShareSheet(items: [viewModel.currentResult?.summary ?? ""])
            }
        }
    }
}
