import SwiftUI

struct ProfileView: View {
    @State private var vm = ProfileViewModel()
    @State private var authManager = AuthManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if let settings = vm.settings {
                        ProfileCard(displayName: settings.displayName, streak: vm.streak)
                        DataOverview(todayPercent: vm.todayPercent,
                                     weekCheckinDays: vm.weekCheckinDays,
                                     weekFocusMinutes: vm.weekFocusMinutes)
                        SettingsSection(vm: vm, settings: settings)
                        QuickEntries()
                    } else if vm.isLoading {
                        ProgressView().tint(.forest).padding(.top, Spacing.xxl)
                    } else if let error = vm.error {
                        ErrorBanner(message: error)
                            .padding(.horizontal, Spacing.xl)
                            .padding(.top, Spacing.xxl)
                        PrimaryButton(title: "重试") { Swift.Task { await vm.load() } }
                            .padding(.horizontal, Spacing.xl)
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.canvas)
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await vm.load() }
        }
        .task { await vm.load() }
    }
}

// MARK: - 个人资料卡片
private struct ProfileCard: View {
    let displayName: String
    let streak: Int

    var body: some View {
        HStack(spacing: Spacing.lg) {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.92))
                )
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(displayName.isEmpty ? "未设置昵称" : displayName)
                    .font(.h2)
                    .foregroundStyle(.white)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                    Text("连续打卡 \(streak) 天")
                        .font(.subhead)
                }
                .foregroundStyle(.white.opacity(0.92))
            }
            Spacer()
        }
        .padding(Spacing.xl)
        .background(BrandGradient.profileCard)
        .cornerRadius(CornerRadius.xl)
        .heroElevation()
    }
}

// MARK: - 数据概览三列
private struct DataOverview: View {
    let todayPercent: Int
    let weekCheckinDays: Int
    let weekFocusMinutes: Int

    var body: some View {
        HStack(spacing: 0) {
            dataCell(value: "\(todayPercent)", unit: "%", label: "今日完成")
            Divider().background(Color.hairline).frame(height: 36)
            dataCell(value: "\(weekCheckinDays)", unit: "天", label: "本周有效")
            Divider().background(Color.hairline).frame(height: 36)
            dataCell(value: "\(weekFocusMinutes)", unit: "min", label: "本周专注")
        }
        .padding(Spacing.lg)
        .background(Color.surfaceSoft)
        .cornerRadius(CornerRadius.lg)
        .cardElevation()
    }

    private func dataCell(value: String, unit: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.forest)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
            }
            Text(label)
                .font(.label)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 设置入口
private struct SettingsSection: View {
    @Bindable var vm: ProfileViewModel
    let settings: Settings
    @State private var showUnbindSheet = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            SettingsGroup(title: "通知") {
                NavigationLink(destination: NotificationSettingsView(settings: settings, vm: vm)) {
                    SettingsRow(icon: "bell.fill", title: "通知设置")
                }
            }
            SettingsGroup(title: "学习") {
                NavigationLink(destination: PlanManagementView()) {
                    SettingsRow(icon: "calendar", title: "重复计划")
                }
                Divider().background(Color.hairline).padding(.leading, Spacing.xl + Spacing.md)
                NavigationLink(destination: LeaveDayConfigView(vm: vm)) {
                    SettingsRow(icon: "beach.umbrella.fill", title: "休息日配置")
                }
                Divider().background(Color.hairline).padding(.leading, Spacing.xl + Spacing.md)
                NavigationLink(destination: TimetableEditorView()) {
                    SettingsRow(icon: "list.clipboard.fill", title: "课表管理")
                }
                Divider().background(Color.hairline).padding(.leading, Spacing.xl + Spacing.md)
                NavigationLink(destination: AIPreferenceView(settings: settings, vm: vm)) {
                    SettingsRow(icon: "cpu", title: "AI 语气偏好")
                }
            }
            SettingsGroup(title: "账号") {
                Toggle(isOn: Binding(
                    get: { settings.externalCheckinEnabled },
                    set: { newValue in Swift.Task { try? await vm.updateSettings(updating: settings, externalCheckin: newValue) } }
                )) {
                    SettingsRowContent(icon: "chart.bar.fill", title: "机构打卡模式")
                }
                .tint(.forest)
                Divider().background(Color.hairline).padding(.leading, Spacing.xl + Spacing.md)
                Button(role: .destructive) {
                    // TODO: 解绑伴侣（阶段二）
                } label: {
                    SettingsRowContent(icon: "link.badge.plus", title: "解绑伴侣")
                }
                Divider().background(Color.hairline).padding(.leading, Spacing.xl + Spacing.md)
                Button(role: .destructive) {
                    // TODO: 注销账号
                } label: {
                    SettingsRowContent(icon: "trash", title: "注销账号")
                }
                Divider().background(Color.hairline).padding(.leading, Spacing.xl + Spacing.md)
                Button {
                    AuthManager.shared.signOut()
                } label: {
                    SettingsRowContent(icon: "arrow.uturn.backward", title: "退出登录")
                }
            }
        }
    }
}

// MARK: - 设置通用行
struct SettingsRow: View {
    let icon: String
    let title: String
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.xxs)
                    .fill(Color.forest.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.forest)
            }
            Text(title)
                .font(.body)
                .foregroundStyle(Color.ink)
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.tertiaryText)
            }
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.md)
        .contentShape(Rectangle())
        .frame(minHeight: TouchTarget.minSize)
    }
}

struct SettingsRowContent: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.xxs)
                    .fill(Color.forest.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.forest)
            }
            Text(title)
                .font(.body)
                .foregroundStyle(Color.ink)
        }
        .frame(minHeight: TouchTarget.minSize)
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .padding(.leading, Spacing.md)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.surfaceSoft)
            .cornerRadius(CornerRadius.lg)
            .cardElevation()
        }
    }
}

// MARK: - 快捷入口
private struct QuickEntries: View {
    var body: some View {
        SettingsGroup(title: "复盘与日历") {
            NavigationLink(destination: CalendarView()) {
                SettingsRow(icon: "calendar", title: "月度日历")
            }
            Divider().background(Color.hairline).padding(.leading, Spacing.xl + Spacing.md)
            NavigationLink(destination: ReviewHistoryView()) {
                SettingsRow(icon: "doc.text.magnifyingglass", title: "历史复盘")
            }
        }
    }
}
