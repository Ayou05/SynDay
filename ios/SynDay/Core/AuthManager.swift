import Foundation
import SwiftUI

@Observable
final class AuthManager {
    static let shared = AuthManager()

    enum AuthState: Equatable {
        case unknown      // 启动时未确定
        case unauthenticated
        case authenticated
    }

    var state: AuthState = .unknown
    var currentUser: User?
    var isLoading = false
    var error: String?

    private init() {}

    /// 启动时调用：检查本地是否有有效 token
    func bootstrap() async {
        if await SupabaseAuth.shared.restoreSessionIfNeeded() {
            // 有 token，调后端验证是否还有效
            do {
                let time: ServerTime = try await APIClient.shared.request("/v1/time")
                state = .authenticated
                _ = time
            } catch let error as APIClient.APIError where error.status == 401 {
                _ = error
                KeychainStore.clearAll()
                state = .unauthenticated
            } catch {
                // 网络错误，保守起见保持已登录，避免离线被踢
                state = .authenticated
            }
        } else {
            state = .unauthenticated
        }
    }

    func sendOTP(email: String) async throws {
        try await SupabaseAuth.shared.sendOTP(email: email)
    }

    func verifyOTP(email: String, code: String) async throws {
        let session = try await SupabaseAuth.shared.verifyOTP(email: email, code: code)
        currentUser = User(id: session.user.id, email: session.user.email,
                           nickname: session.user.userMetadata?.displayName ?? "")
        state = .authenticated
    }

    func signOut() {
        KeychainStore.clearAll()
        currentUser = nil
        state = .unauthenticated
    }
}

struct User: Identifiable {
    let id: String
    let email: String
    var nickname: String
    var avatarUrl: URL?
}
