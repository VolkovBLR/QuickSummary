internal import CoreData
import Foundation
import UIKit
internal import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var selectedContentType: ContentType = .general
    @Published var selectedLength: SummaryLength = .medium
    @Published var currentResult: SummaryResult?
    @Published var isScannerPresented = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSharePresented = false

    func summarize(context: NSManagedObjectContext) async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 20 else {
            errorMessage = "Введите не менее 20 символов / Enter at least 20 characters"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let classified = try await APIClient.shared.classify(text: trimmed)

            let request = SummarizeRequest(
                text: trimmed,
                language: classified.language,
                contentType: selectedContentType == .general ? classified.contentType : selectedContentType,
                summaryLength: selectedLength,
                highlightKeyPoints: true
            )

            let response = try await APIClient.shared.summarize(request)

            let result = SummaryResult(
                sourceText: trimmed,
                language: response.language,
                contentType: response.contentType,
                summaryLength: response.summaryLength,
                summary: response.summary,
                keyPoints: response.keyPoints,
                modelUsed: response.modelUsed
            )

            currentResult = result
            save(result: result, context: context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copySummary() {
        guard let summary = currentResult?.summary else { return }
        UIPasteboard.general.string = summary
    }

    func loadHistoryItem(_ item: HistoryRecord) {
        inputText = item.sourceText
        selectedContentType = ContentType(rawValue: item.contentType) ?? .general
        selectedLength = SummaryLength(rawValue: item.summaryLength) ?? .medium

        currentResult = SummaryResult(
            sourceText: item.sourceText,
            language: item.language,
            contentType: ContentType(rawValue: item.contentType) ?? .general,
            summaryLength: SummaryLength(rawValue: item.summaryLength) ?? .medium,
            summary: item.summaryText,
            keyPoints: item.keyPointsList,
            modelUsed: item.modelUsed
        )
    }

    private func save(result: SummaryResult, context: NSManagedObjectContext) {
        let record = HistoryRecord(context: context)
        record.id = UUID()
        record.createdAt = Date()
        record.sourceText = result.sourceText
        record.summaryText = result.summary
        record.keyPointsList = result.keyPoints
        record.language = result.language
        record.contentType = result.contentType.rawValue
        record.summaryLength = result.summaryLength.rawValue
        record.modelUsed = result.modelUsed

        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
