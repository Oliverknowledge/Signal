import Foundation

enum AnalyzeError: LocalizedError {
    case invalidURL
    case encodingError(Error)
    case networkError(Error)
    case invalidResponse
    case noData
    case decodingError(Error)
    case apiError(statusCode: Int, message: String, details: [ValidationError]?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid HTTP response"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let statusCode, let message, _):
            return "API error (\(statusCode)): \(message)"
        }
    }
}

struct SignalAPIClient {
    private let baseURL: String
    private let session: URLSession

    init(baseURL: String = APIConfig.baseURL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 90
        self.session = URLSession(configuration: config)
    }

    func analyzeContent(request: AnalyzeRequest) async throws -> AnalyzeResponse {
        guard let url = URL(string: "\(baseURL)/api/analyze") else {
            throw AnalyzeError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw AnalyzeError.encodingError(error)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw AnalyzeError.invalidResponse
            }

            if !(200...299).contains(http.statusCode) {
                if let err = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw AnalyzeError.apiError(statusCode: http.statusCode, message: err.message ?? err.error, details: err.details)
                } else {
                    let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw AnalyzeError.apiError(statusCode: http.statusCode, message: msg, details: nil)
                }
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(AnalyzeResponse.self, from: data)
        } catch let e as AnalyzeError {
            throw e
        } catch {
            throw AnalyzeError.networkError(error)
        }
    }
}
