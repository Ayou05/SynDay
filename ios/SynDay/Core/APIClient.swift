import Foundation

/// REST API 封装，基于原生 URLSession
/// 所有业务请求走这里，自动带 Authorization: Bearer
actor APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession

    init() {
        self.baseURL = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "https://api.synday.catclaw.cloud")!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    enum HTTPMethod: String {
        case GET, POST, PUT, PATCH, DELETE
    }

    struct APIError: Error, LocalizedError {
        let status: Int
        let message: String
        var errorDescription: String? { message }
    }

    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod = .GET,
        query: [URLQueryItem]? = nil,
        body: Encodable? = nil
    ) async throws -> T {
        let data = try await rawRequest(path, method: method, query: query, body: body)
        do {
            return try JSONDecoder.api.decode(T.self, from: data)
        } catch {
            throw APIError(status: -1, message: "数据解析失败")
        }
    }

    /// 不需要解析响应体的请求（DELETE / 204）
    func requestEmpty(
        _ path: String,
        method: HTTPMethod = .GET,
        query: [URLQueryItem]? = nil,
        body: Encodable? = nil
    ) async throws {
        _ = try await rawRequest(path, method: method, query: query, body: body)
    }

    private func rawRequest(
        _ path: String,
        method: HTTPMethod,
        query: [URLQueryItem]?,
        body: Encodable?
    ) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if let query, !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else {
            throw APIError(status: -1, message: "请求地址错误")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let token = KeychainStore.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.api.encode(body)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(status: -1, message: "网络异常")
        }
        if !(200..<300).contains(http.statusCode) {
            let message: String
            if let decoded = try? JSONDecoder.api.decode([String: String].self, from: data), let err = decoded["error"] {
                message = err
            } else {
                message = http.statusCode == 401 ? "登录已过期，请重新登录" : "服务暂时不可用"
            }
            throw APIError(status: http.statusCode, message: message)
        }
        if data.isEmpty || http.statusCode == 204 { return Data() }
        return data
    }
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension JSONEncoder {
    static let api: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
