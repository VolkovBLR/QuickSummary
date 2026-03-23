import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import PDFKit
import Vision

struct InputScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: AppViewModel
    @FocusState private var isEditorFocused: Bool
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showFileImporter = false
    @State private var showGallery = false


    var body: some View {
        NavigationStack {
            Form {
                Section("Ввод текста") {
                    ExpandableInputEditor(
                        text: $viewModel.inputText,
                        isFocused: $isEditorFocused
                    )

                    Menu {
                        Button {
                            isEditorFocused = false
                            viewModel.isScannerPresented = true
                        } label: {
                            Label("Сфотографировать", systemImage: "camera")
                        }
                        
                        Button {
                            isEditorFocused = false
                            showGallery = true
                        } label: {
                            Label("Из галереи", systemImage: "photo")
                        }
                        
                        Button {
                            isEditorFocused = false
                            showFileImporter = true
                        } label: {
                            Label("Из файлов", systemImage: "folder")
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("Добавить документ")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                    }
                    .photosPicker(
                        isPresented: $showGallery,
                        selection: $selectedPhotoItem,
                        matching: .images
                    )
                }

                Section("Тип контента") {
                    Picker("Тип контента", selection: $viewModel.selectedContentType) {
                        ForEach(ContentType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                }

                Section {
                    Button(viewModel.isLoading ? "Обработка..." : "Сократить текст") {
                        isEditorFocused = false
                        Task {
                            await viewModel.summarize(context: viewContext)
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationTitle("Главный экран")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isEditorFocused = false
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                handlePhotoImport(newItem: newItem)
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
                "Ошибка",
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
    
    private func handleFileImport(result: Result<[URL], Error>) {
        guard let url = try? result.get().first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        if url.pathExtension.lowercased() == "pdf" {
            if let pdf = PDFDocument(url: url) {
                var fullText = ""
                for i in 0..<pdf.pageCount {
                    if let page = pdf.page(at: i), let pageText = page.string {
                        fullText += pageText + "\n"
                    }
                }
                viewModel.inputText = fullText
            }
        } else {
            if let image = UIImage(contentsOfFile: url.path), let cgImage = image.cgImage {
                recognizeText(from: cgImage)
            }
        }
    }
    
    private func handlePhotoImport(newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        Task {
            if let data = try? await newItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let cgImage = image.cgImage {
                recognizeText(from: cgImage)
            }
        }
    }
    
    private func recognizeText(from cgImage: CGImage) {
        let request = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            DispatchQueue.main.async {
                self.viewModel.inputText = text
            }
        }
        request.recognitionLanguages = ["ru-RU", "en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
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
            ZStack(alignment: .topTrailing) {
                TextEditor(text: $text)
                    .focused($isFocused)
                    .frame(height: editorHeight)
                    .padding(.trailing, 30)
                    .padding(.leading, 8)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding(12)
                    }
                }
            }

            if shouldShowExpandButton {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
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
