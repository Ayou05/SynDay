import Foundation

/// Supabase 邮箱 OTP 认证（纯 REST，不引第三方 SDK）
/// 后端只校验 access token，所以这里拿到 token 直接存 Keychain 给 APIClient 用
final class SupabaseAuth {
    static let shared = SupabaseAuth()

    private let supabaseURL = URL(string: "https://abuhrrrqvpivzdvwkmik.supabase.co")!
    private let publishableKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFidWhycnJxdnBpdnpkdndrbWlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxMjE4NDUsImV4cCI6MjA5NzY5Nzg0NX0.RIwLYJYFcwZxYpQJcCUqYsSDujQVlTEy9V0VObi5RGg"
    private let session: URLSession

    private init() {
        self.session = URLSession.shared
    }

    struct SupabaseUser: Decodable {
        let id: String
        let email: String
        let userMetadata: UserMetadata?

        enum CodingKeys: String, CodingKey {
            case id, email
            case userMetadata = "user_metadata"
        }

        struct UserMetadata: Decodable {
            let displayName: String?
            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
            }
        }
    }

    struct AuthSession: Decodable {
        let accessToken: String
        let refreshToken: String?
        let user: SupabaseUser

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case user
        }
    }

    /// 发送邮箱 OTP 验证码
    func sendOTP(email: String) async throws {
        let url = supabaseURL.appendingPathComponent("auth/v1/otp")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        let body = ["email": email, "create_user": true, "data": ["display_name": ""]] as [String: Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) || http.statusCode == 429 else {
            throw AuthError.otpSendFailed
        }
    }

    /// 验证 OTP，登录/注册统一走这里
    func verifyOTP(email: String, code: String) async throws -> AuthSession {
        let url = supabaseURL.appendingPathComponent("auth/v1/verify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        let body: [String: Any] = [
            "email": email,
            "token": code,
            "type": "email",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.otpInvalid
        }
        let session = try JSONDecoder().decode(AuthSession.self, from: data)
        KeychainStore.saveAccessToken(session.accessToken)
        if let refresh = session.refreshToken {
            KeychainStore.saveRefreshToken(refresh)
        }
        KeychainStore.saveUserID(session.user.id)
        return session
    }

    /// 启动时用已存 token 恢复会话（调后端 /v1/time 验证，成功视为已登录）
    func restoreSessionIfNeeded() async -> Bool {
        guard KeychainStore.accessToken() != nil, KeychainStore.userID() != nil else {
            return false
        }
        return true
    }
}

enum AuthError: Error, LocalizedError {
    case otpSendFailed
    case otpInvalid

    var errorDescription: String? {
        switch self {
        case .otpSendFailed:
            return "验证码发送失败，请稍后重试"
        case .otpInvalid:
            return "验证码错误，请重新输入"
        }
    }
}
