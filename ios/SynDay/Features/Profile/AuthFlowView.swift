import SwiftUI

struct AuthFlowView: View {
    enum Step {
        case home          // 登录首页（邮箱/Apple 按钮）
        case email         // 邮箱输入
        case otp(email: String)  // 验证码
        case nickname(email: String)  // 新用户昵称设置
    }

    @State private var step: Step = .home
    @State private var authManager = AuthManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.canvas.ignoresSafeArea()
                switch step {
                case .home:
                    AuthHomeView(onEmail: { step = .email },
                                 onApple: { /* TODO: Apple 登录 */ })
                case .email:
                    EmailInputView(onContinue: { email in step = .otp(email: email) })
                case .otp(let email):
                    OTPInputView(email: email,
                                 onBack: { step = .email },
                                 onVerified: { session in
                                     // 新用户（无昵称）跳昵称页，老用户直接完成
                                     if (session.user.userMetadata?.displayName?.isEmpty ?? true) {
                                         step = .nickname(email: email)
                                     } else {
                                         authManager.currentUser = User(id: session.user.id, email: session.user.email,
                                                                         nickname: session.user.userMetadata?.displayName ?? "")
                                         authManager.state = .authenticated
                                     }
                                 })
                case .nickname(let email):
                    NicknameSetupView(email: email) { name in
                        authManager.currentUser?.nickname = name
                        authManager.state = .authenticated
                    }
                }
            }
        }
    }
}

// MARK: - 登录首页
private struct AuthHomeView: View {
    let onEmail: () -> Void
    let onApple: () -> Void
    @State private var breath = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.forest.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .scaleEffect(breath ? 1.1 : 0.9)
                    .opacity(breath ? 0.5 : 0.2)

                Circle()
                    .fill(Color.forest.opacity(0.14))
                    .frame(width: 96, height: 96)
                    .scaleEffect(breath ? 1.04 : 0.96)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.forest)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breath = true }
            }

            VStack(spacing: Spacing.xxs) {
                Text("朝夕同序")
                    .font(.h1)
                    .foregroundStyle(Color.ink)
                Text("一起努力，顶峰相见")
                    .font(.body)
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer()
            PrimaryButton(title: "邮箱登录/注册", action: onEmail)
                .padding(.horizontal, Spacing.xl)
            Button(action: onApple) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "apple.logo")
                    Text("Apple 登录")
                }
                .font(.h3)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: TouchTarget.buttonPrimary)
                .background(Color.ink)
                .cornerRadius(CornerRadius.lg)
            }
            .padding(.horizontal, Spacing.xl)
            Text("登录即代表同意《用户协议》和《隐私政策》")
                .font(.caption)
                .foregroundStyle(Color.tertiaryText)
                .padding(.bottom, Spacing.xl)
        }
        .padding()
        .background(BrandGradient.hero)
    }
}

// MARK: - 邮箱输入
private struct EmailInputView: View {
    @State private var email = ""
    @State private var isSending = false
    @State private var error: String?
    @FocusState private var isFocused: Bool
    let onContinue: (String) -> Void

    private var isValid: Bool {
        let regex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.wholeMatch(of: try? NSRegularExpression(pattern: regex)) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("欢迎回来")
                .font(.h1)
                .foregroundStyle(Color.ink)
                .padding(.top, Spacing.xxl)
            Text("请输入邮箱地址")
                .font(.body)
                .foregroundStyle(Color.secondaryText)
            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "envelope")
                        .font(.system(size: 16))
                        .foregroundStyle(isFocused ? Color.forest : Color.tertiaryText)
                    TextField("name@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.body)
                        .focused($isFocused)
                }
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, Spacing.md)
                .background(Color.surfaceSoft)
                .cornerRadius(CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(isFocused ? Color.forest.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
            Spacer()
            if let error {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.subhead)
                }
                .foregroundStyle(Color.error)
            }
            PrimaryButton(title: "继续", isLoading: isSending,
                          isDisabled: !isValid, action: send)
        }
        .padding(.horizontal, Spacing.xl)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = true }
    }

    private func send() {
        Swift.Task {
            isSending = true
            error = nil
            do {
                try await AuthManager.shared.sendOTP(email: email)
                onContinue(email)
            } catch {
                self.error = error.localizedDescription
                Haptics.error()
            }
            isSending = false
        }
    }
}

// MARK: - OTP 验证码
private struct OTPInputView: View {
    let email: String
    let onBack: () -> Void
    let onVerified: (SupabaseAuth.AuthSession) -> Void

    @State private var code = ""
    @State private var isVerifying = false
    @State private var error: String?
    @State private var resendCountdown = 60
    @State private var resendTask: Swift.Task<Void, Never>?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("输入验证码")
                .font(.h1)
                .foregroundStyle(Color.ink)
                .padding(.top, Spacing.xxl)
            Text("验证码已发送至 \(email)")
                .font(.body)
                .foregroundStyle(Color.secondaryText)

            // 六格验证码显示 + 隐藏 TextField
            ZStack {
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isFocused)
                    .opacity(0.01)
                    .onChange(of: code) { _, new in
                        let filtered = String(new.filter(\.isNumber).prefix(6))
                        if filtered != new { code = filtered }
                        if filtered.count == 6 { verify() }
                    }

                HStack(spacing: Spacing.sm) {
                    ForEach(0..<6, id: \.self) { idx in
                        otpCell(idx)
                    }
                }
            }
            .onTapGesture { isFocused = true }

            Spacer()
            if let error {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.subhead)
                }
                .foregroundStyle(Color.error)
            }
            HStack {
                if resendCountdown > 0 {
                    Text("重新发送（\(resendCountdown)s）")
                        .font(.subhead)
                        .foregroundStyle(Color.tertiaryText)
                } else {
                    Button { resend() } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                            Text("重新发送")
                                .font(.subhead)
                        }
                        .foregroundStyle(Color.forest)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .navigationTitle("验证码")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("返回") { onBack() }
            }
        }
        .onAppear {
            isFocused = true
            startCountdown()
        }
        .onDisappear { resendTask?.cancel() }
    }

    private func otpCell(_ idx: Int) -> some View {
        let char = idx < code.count ? String(code[code.index(code.startIndex, offsetBy: idx)]) : ""
        let isCurrent = idx == code.count
        return Text(char)
            .font(.system(size: 24, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.ink)
            .frame(width: 44, height: 56)
            .background(Color.surfaceSoft)
            .cornerRadius(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(isCurrent && isFocused ? Color.forest.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeOut(duration: 0.15), value: code)
    }

    private func verify() {
        guard code.count == 6, !isVerifying else { return }
        Swift.Task {
            isVerifying = true
            error = nil
            do {
                let session = try await SupabaseAuth.shared.verifyOTP(email: email, code: code)
                onVerified(session)
            } catch {
                self.error = error.localizedDescription
                code = ""
                Haptics.error()
            }
            isVerifying = false
        }
    }

    private func resend() {
        Swift.Task {
            try? await AuthManager.shared.sendOTP(email: email)
            startCountdown()
        }
    }

    private func startCountdown() {
        resendCountdown = 60
        resendTask?.cancel()
        resendTask = Swift.Task {
            while resendCountdown > 0 {
                try? await Swift.Task.sleep(for: .seconds(1))
                if Swift.Task.isCancelled { return }
                resendCountdown -= 1
            }
        }
    }
}

// MARK: - 昵称设置
private struct NicknameSetupView: View {
    let email: String
    let onDone: (String) -> Void

    @State private var nickname = ""
    @State private var isSaving = false
    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        let count = nickname.trimmingCharacters(in: .whitespaces).count
        return count >= 2 && count <= 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("设置你的昵称")
                .font(.h1)
                .foregroundStyle(Color.ink)
                .padding(.top, Spacing.xxl)
            Text("好的昵称能让TA更容易认出你")
                .font(.body)
                .foregroundStyle(Color.secondaryText)
            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person")
                        .font(.system(size: 16))
                        .foregroundStyle(isFocused ? Color.forest : Color.tertiaryText)
                    TextField("输入昵称（2-10字）", text: $nickname)
                        .font(.body)
                        .focused($isFocused)
                }
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, Spacing.md)
                .background(Color.surfaceSoft)
                .cornerRadius(CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(isFocused ? Color.forest.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
            Spacer()
            Text("昵称后续可在「我的」页修改")
                .font(.caption)
                .foregroundStyle(Color.tertiaryText)
            PrimaryButton(title: "完成", isLoading: isSaving, isDisabled: !isValid, action: save)
        }
        .padding(.horizontal, Spacing.xl)
        .navigationTitle("昵称")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { isFocused = true }
    }

    private func save() {
        Swift.Task {
            isSaving = true
            // TODO: 调后端 PATCH /v1/users/me 持久化昵称（阶段一先用本地）
            onDone(nickname.trimmingCharacters(in: .whitespaces))
            isSaving = false
        }
    }
}

// MARK: - String 正则辅助
extension String {
    func wholeMatch(of regex: NSRegularExpression?) -> NSTextCheckingResult? {
        guard let regex else { return nil }
        let range = NSRange(self.startIndex..., in: self)
        return regex.firstMatch(in: self, range: range)
    }
}
