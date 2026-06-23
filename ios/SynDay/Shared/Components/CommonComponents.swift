import SwiftUI

// MARK: - 主按钮
struct PrimaryButton: View {
    let title: String
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.h3)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: TouchTarget.buttonPrimary)
            .background(isDisabled ? Color.forest.opacity(0.4) : Color.forest)
            .cornerRadius(CornerRadius.lg)
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.9 : 1.0)
        .heroElevation()
    }
}

// MARK: - 次要按钮
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.h3)
                .foregroundStyle(Color.forest)
                .frame(maxWidth: .infinity)
                .frame(height: TouchTarget.buttonPrimary)
                .background(Color.surfaceSoft)
                .cornerRadius(CornerRadius.lg)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.lg).stroke(Color.hairline, lineWidth: 0.5))
        }
    }
}

// MARK: - 文字按钮
struct TextButton: View {
    let title: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.subhead)
                .foregroundStyle(role == .destructive ? Color.error : Color.forest)
                .frame(height: TouchTarget.buttonSecondary)
        }
    }
}

// MARK: - 标准卡片容器
struct Card<Content: View>: View {
    var background: Color = .surfaceSoft
    var padding: CGFloat = Spacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(background)
            .cornerRadius(CornerRadius.lg)
            .cardElevation()
    }
}

// MARK: - 离线横幅
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("离线模式 · 操作将在恢复网络后同步")
                .font(.caption)
        }
        .foregroundStyle(Color.orange)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(Color.orange.opacity(0.12))
    }
}

// MARK: - 空状态
struct EmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.forest.opacity(0.5))
                .padding(.bottom, Spacing.xs)

            Text(title)
                .font(.h3)
                .foregroundStyle(Color.ink)

            Text(subtitle)
                .font(.subhead)
                .foregroundStyle(Color.tertiaryText)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.top, Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
    }
}

// MARK: - 错误横幅
struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            Text(message)
                .font(.subhead)
                .lineLimit(2)
        }
        .foregroundStyle(Color.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .frame(height: 36)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(CornerRadius.md)
    }
}

// MARK: - Toast
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subhead)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.ink.opacity(0.88))
            .cornerRadius(CornerRadius.md)
            .floatingElevation()
    }
}
