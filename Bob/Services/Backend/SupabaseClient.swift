import Foundation

enum SupabaseError: LocalizedError {
    case notConfigured
    case invalidResponse
    case httpError(code: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured. Fill SUPABASE_URL and SUPABASE_ANON_KEY in Info.plist."
        case .invalidResponse:
            return "Invalid server response."
        case .httpError(let code, let body):
            return "Supabase request failed (\(code)): \(body)"
        }
    }
}

struct SupabaseClient {
    private let session: URLSession
    private let baseURL: URL
    private let anonKey: String

    init(session: URLSession = .shared) throws {
        guard let url = SupabaseConfig.url, let key = SupabaseConfig.anonKey else {
            throw SupabaseError.notConfigured
        }
        self.session = session
        self.baseURL = url
        self.anonKey = key
    }

    func healthCheck() async throws {
        _ = try await request(path: "/rest/v1/", method: "GET")
    }

    @discardableResult
    func request(path: String, method: String, body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            throw SupabaseError.httpError(code: http.statusCode, body: body)
        }
        return data
    }
}

