import Foundation

struct UploadToken: Decodable {
    let token: String
    let key: String
    let domain: String
    let uploadUrl: String
}

actor ImageUploader {
    static let shared = ImageUploader()

    private let session: URLSession
    private let apiBase: String

    init() {
        self.session = URLSession.shared
        self.apiBase = ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "https://api.synday.catclaw.cloud"
    }

    /// 获取上传凭证，然后直传七牛，返回可直接访问的图片URL
    func uploadImage(data: Data, scene: UploadScene) async throws -> URL {
        let token = try await fetchToken(scene: scene)
        let uploadedKey = try await uploadToQiniu(data: data, token: token)
        guard let url = URL(string: "\(token.domain)/\(uploadedKey)") else {
            throw UploadError.invalidURL
        }
        return url
    }

    /// 获取缩略图URL（七牛实时处理，聊天列表用200px）
    nonisolated func thumbnailURL(_ url: URL, width: Int = 200, height: Int = 200) -> URL {
        let urlString = url.absoluteString
        let processed = "\(urlString)?imageView2/1/w/\(width)/h/\(height)"
        return URL(string: processed) ?? url
    }

    /// 获取预览图URL（聊天详情用800px）
    nonisolated func previewURL(_ url: URL, width: Int = 800) -> URL {
        let urlString = url.absoluteString
        let processed = "\(urlString)?imageView2/2/w/\(width)"
        return URL(string: processed) ?? url
    }

    private func fetchToken(scene: UploadScene) async throws -> UploadToken {
        guard let url = URL(string: "\(apiBase)/v1/upload/token?scene=\(scene.rawValue)") else {
            throw UploadError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = KeychainStore.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UploadError.tokenFailed
        }
        return try JSONDecoder().decode(UploadToken.self, from: data)
    }

    private func uploadToQiniu(data: Data, token: UploadToken) async throws -> String {
        guard let url = URL(string: token.uploadUrl) else {
            throw UploadError.invalidURL
        }
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"token\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(token.token)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"key\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(token.key)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UploadError.uploadFailed
        }

        struct QiniuResponse: Decodable {
            let key: String
        }
        let decoded = try JSONDecoder().decode(QiniuResponse.self, from: responseData)
        return decoded.key
    }
}

enum UploadScene: String {
    case chat
    case avatar
    case album
}

enum UploadError: Error {
    case invalidURL
    case tokenFailed
    case uploadFailed
}
