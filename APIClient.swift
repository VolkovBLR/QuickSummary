import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    var baseURL = URL(string: "http://127.0.0.1:8000")!

    func classify(text: String) async throws -> ClassifyResponse {
        let requestBody = ClassifyRequest(text: text)
        let url = baseURL.appendingPathComponent("classify")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ClassifyResponse.self, from: data)
    }

    func summarize(_ payload: SummarizeRequest) async throws -> SummarizeResponse {
        let url = baseURL.appendingPathComponent("summarize")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(SummarizeResponse.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= http.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Server error"
            throw NSError(
                domain: "APIClient",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}
