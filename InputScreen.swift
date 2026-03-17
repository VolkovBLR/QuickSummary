import SwiftUI

struct InputScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: AppViewModel
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section("Ввод текста / Text input") {
                        ExpandableInputEditor(
                            text: $viewModel.inputText,
                            isFocused: $isEditorFocused
                        )

                        Button("Сфотографировать документ / Scan document") {
                            isEditorFocused = false
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
                            isEditorFocused = false
                            Task {
                                await viewModel.summarize(context: viewContext)
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                if isEditorFocused {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditorFocused = false
                        }
                }
            }
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


struct ExpandableInputEditor: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @State private var isExpanded = false

    private var shouldShowExpandButton: Bool {
        text.count > 250 || text.components(separatedBy: .newlines).count > 6
    }

    private var editorHeight: CGFloat {
        isExpanded ? 360 : 180
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $text)
                .focused($isFocused)
                .frame(height: editorHeight)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            if shouldShowExpandButton {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded
                              ? "arrow.up.left.and.arrow.down.right"
                              : "arrow.down.right.and.arrow.up.left")
                        Text(isExpanded ? "Свернуть поле" : "Развернуть поле")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
