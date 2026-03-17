import SwiftUI

struct InputScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Ввод текста / Text input") {
                    TextEditor(text: $viewModel.inputText)
                        .frame(minHeight: 220)

                    Button("Сфотографировать документ / Scan document") {
                        viewModel.isScannerPresented = true
                    }
                }

                Section("Тип контента / Content type") {
                    Picker("Тип контента", selection: $viewModel.selectedContentType) {
                        ForEach(ContentType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }

                Section {
                    Button(viewModel.isLoading ? "Обработка... / Processing..." : "Сократить текст / Summarize") {
                        Task {
                            await viewModel.summarize(context: viewContext)
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationTitle("Главный экран")
            .sheet(isPresented: $viewModel.isScannerPresented) {
                DocumentScannerView(
                    onTextRecognized: { recognizedText in
                        viewModel.inputText = recognizedText
                    },
                    onError: { message in
                        viewModel.errorMessage = message
                    }
                )
            }
            .alert(
                "Ошибка / Error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { _ in viewModel.errorMessage = nil }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
