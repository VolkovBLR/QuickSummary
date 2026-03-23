import Foundation

enum ContentType: String, CaseIterable, Codable, Identifiable {
    case news
    case technical
    case scientific
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .news:
            return "Новости"
        case .technical:
            return "Технический"
        case .scientific:
            return "Научный"
        case .general:
            return "Общий"
        }
    }
}

enum SummaryLength: String, CaseIterable, Codable, Identifiable {
    case short
    case medium
    case long

    var id: String { rawValue }

    var title: String {
        switch self {
        case .short:
            return "Коротко"
        case .medium:
            return "Стандарт"
        case .long:
            return "Подробно"
        }
    }
}

struct ClassifyRequest: Codable {
    let text: String
}

struct ClassifyResponse: Codable {
    let language: String
    let contentType: ContentType

    enum CodingKeys: String, CodingKey {
        case language
        case contentType = "content_type"
    }
}

struct SummarizeRequest: Codable {
    let text: String
    let language: String
    let contentType: ContentType
    let summaryLength: SummaryLength
    let highlightKeyPoints: Bool

    enum CodingKeys: String, CodingKey {
        case text
        case language
        case contentType = "content_type"
        case summaryLength = "summary_length"
        case highlightKeyPoints = "highlight_key_points"
    }
}

struct SummarizeResponse: Codable {
    let language: String
    let contentType: ContentType
    let summaryLength: SummaryLength
    let summary: String
    let keyPoints: [String]
    let modelUsed: String

    enum CodingKeys: String, CodingKey {
        case language
        case contentType = "content_type"
        case summaryLength = "summary_length"
        case summary
        case keyPoints = "key_points"
        case modelUsed = "model_used"
    }
}

struct SummaryResult: Equatable {
    let sourceText: String
    let language: String
    let contentType: ContentType
    let summaryLength: SummaryLength
    let summary: String
    let keyPoints: [String]
    let modelUsed: String
}
