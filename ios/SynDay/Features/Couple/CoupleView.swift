import SwiftUI

struct CoupleView: View {
    @State private var vm = CoupleViewModel()
    @State private var showBindSheet = false
    @State private var showClaimSheet = false
    @State private var showUnbindConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if let error = vm.error {
                        ErrorBanner(message: error)
                    }

                    switch vm.bindingState {
                    case .unknown:
                        ProgressView().tint(.forest).padding(.top, Spacing.xxl)

                    case .unbound:
                        unboundCard

                    case .awaitingClaim(let pairing):
                        awaitingClaimCard(pairing)

                    case .awaitingConfirm(let pairing):
                        awaitingConfirmCard(pairing)

                    case .bound(let partner):
                        boundContent(partner)
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Color.canvas)
            .navigationTitle("情侣")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await vm.load() }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showClaimSheet) {
            ClaimPairingSheet(vm: vm) {
                showClaimSheet = false
            }
        }
        .sheet(isPresented: $showUnbindConfirm) {
            UnbindConfirmSheet {
                showUnbindConfirm = false
                Swift.Task { await vm.unbind() }
            }
        }
    }

    // MARK: - 未绑定
    private var unboundCard: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.forest.opacity(0.5))
                .padding(.bottom, Spacing.xs)
            VStack(spacing: Spacing.xs) {
                Text("还未绑定了你的榜样")
                    .font(.h2)
                    .foregroundStyle(Color.ink)
                Text("一起努力，顶峰相见")
                    .font(.subhead)
                    .foregroundStyle(Color.tertiaryText)
            }
            VStack(spacing: Spacing.md) {
                PrimaryButton(title: "生成星图令牌") {
                    Swift.Task { await vm.createPairing() }
                }
                SecondaryButton(title: "我有令牌，去认领") {
                    showClaimSheet = true
                }
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceSoft)
        .cornerRadius(CornerRadius.xl)
        .cardElevation()
    }

    // MARK: - 等待认领（我生成的令牌）
    private func awaitingClaimCard(_ pairing: PairingToken) -> some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.xs) {
                Text("把星图令牌给 TA")
                    .font(.h3)
                    .foregroundStyle(Color.ink)
                Text("5 分钟内有效")
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
            }

            // 6 位码大号显示
            Text(pairing.code)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.forest)
                .tracking(8)
                .padding(Spacing.lg)
                .background(Color.forest.opacity(0.08))
                .cornerRadius(CornerRadius.lg)

            if let token = pairing.token {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "link")
                        .font(.caption)
                    Text(token)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundStyle(Color.tertiaryText)
                .padding(.horizontal, Spacing.md)
            }

            HStack(spacing: Spacing.sm) {
                Image(systemName: "clock")
                    .font(.caption)
                Text("等待 TA 输码认领…")
                    .font(.subhead)
            }
            .foregroundStyle(Color.secondaryText)

            Button {
                UIPasteboard.general.string = pairing.code
                Haptics.taskCompleted()
            } label: {
                Label("复制邀请码", systemImage: "doc.on.doc")
                    .font(.subhead)
                    .foregroundStyle(Color.forest)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceSoft)
        .cornerRadius(CornerRadius.xl)
        .cardElevation()
    }

    // MARK: - 等待确认
    private func awaitingConfirmCard(_ pairing: PairingToken) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "heart.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.forest)
            VStack(spacing: Spacing.xs) {
                Text("TA 已经认领")
                    .font(.h2)
                    .foregroundStyle(Color.ink)
                Text("确认后正式绑定")
                    .font(.subhead)
                    .foregroundStyle(Color.secondaryText)
            }
            PrimaryButton(title: "确认绑定", isLoading: vm.isBusy) {
                Swift.Task { await vm.confirmPairing() }
            }
            TextButton(title: "取消") {
                vm.generatedPairing = nil
                vm.bindingState = .unbound
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceSoft)
        .cornerRadius(CornerRadius.xl)
        .cardElevation()
    }

    // MARK: - 已绑定
    private func boundContent(_ partner: PartnerOverview) -> some View {
        VStack(spacing: Spacing.lg) {
            // 伴侣概览卡
            partnerOverviewCard(partner)

            // 伴侣专注状态
            if partner.isFocusing {
                partnerFocusingCard(partner)
            }

            // 伴侣今日任务
            if !partner.tasks.isEmpty {
                partnerTasksCard(partner.tasks)
            }
        }
    }

    private func partnerOverviewCard(_ partner: PartnerOverview) -> some View {
        HStack(spacing: Spacing.lg) {
            ZStack {
                Circle().fill(Color.forest.opacity(0.15)).frame(width: 56, height: 56)
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.forest)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(partner.displayName.isEmpty ? "你的榜样" : partner.displayName)
                    .font(.h3)
                    .foregroundStyle(Color.ink)
                HStack(spacing: Spacing.md) {
                    Label("\(partner.completionPercent)%", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(Color.forest)
                    Label("\(partner.currentStreak)天", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                }
            }
            Spacer()
            Button {
                showUnbindConfirm = true
            } label: {
                Image(systemName: "heart.slash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.tertiaryText)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(Spacing.lg)
        .background(Color.surfaceSoft)
        .cornerRadius(CornerRadius.lg)
        .cardElevation()
    }

    private func partnerFocusingCard(_ partner: PartnerOverview) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(Color.forest.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Color.forest)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("TA 正在专注")
                    .font(.body)
                    .foregroundStyle(Color.ink)
                if let mode = partner.focusMode {
                    Text(modeDisplayName(mode))
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            Spacer()
            if let roomID = partner.focusRoomID {
                Button {
                    // 阶段二-4：joinSharedFocus 接通后跳专注页加入
                    NotificationCenter.default.post(name: .joinSharedFocus, object: roomID)
                } label: {
                    Text("加入")
                        .font(.subhead)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.forest)
                        .cornerRadius(CornerRadius.md)
                }
            }
        }
        .padding(Spacing.lg)
        .background(Color.forest.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.lg).stroke(Color.forest.opacity(0.15), lineWidth: 0.5))
        .cornerRadius(CornerRadius.lg)
    }

    private func partnerTasksCard(_ tasks: [Task]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("TA 的今日安排")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
            ForEach(tasks) { task in
                partnerTaskRow(task)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSoft)
        .cornerRadius(CornerRadius.lg)
        .cardElevation()
    }

    private func partnerTaskRow(_ task: Task) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(task.status == .completed ? Color.forest : Color.surfaceStrong)
                .frame(width: 8, height: 8)
            Text(task.title)
                .font(.body)
                .strikethrough(task.status == .completed || task.status == .expired)
                .foregroundStyle(task.status == .pending ? Color.ink : Color.tertiaryText)
                .lineLimit(1)
            Spacer()
            Text(task.plannedTime ?? "全天")
                .font(.caption)
                .foregroundStyle(Color.tertiaryText)
        }
        .padding(.vertical, Spacing.xxs)
    }

    private func modeDisplayName(_ raw: String) -> String {
        switch raw {
        case "solo_countup": return "正计时"
        case "solo_countdown": return "倒计时"
        case "shared_countup": return "共享正计时"
        case "shared_countdown": return "共享倒计时"
        default: return raw
        }
    }
}

extension Notification.Name {
    static let joinSharedFocus = Notification.Name("synday.joinSharedFocus")
}

// MARK: - 认领 Sheet
private struct ClaimPairingSheet: View {
    @Bindable var vm: CoupleViewModel
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("认领星图令牌")
                    .font(.h2)
                    .foregroundStyle(Color.ink)
                    .padding(.top, Spacing.xxl)
                Text("输入 TA 给你的 6 位邀请码或令牌")
                    .font(.body)
                    .foregroundStyle(Color.secondaryText)
                TextField("6 位邀请码", text: $vm.claimCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(Spacing.md)
                    .background(Color.surfaceSoft)
                    .cornerRadius(CornerRadius.md)
                Spacer()
                PrimaryButton(title: "认领", isLoading: vm.isBusy, isDisabled: vm.claimCode.count < 6) {
                    Swift.Task {
                        await vm.claimPairing()
                        if case .awaitingConfirm = vm.bindingState {
                            onDone()
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
            .navigationTitle("认领")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }
}

// MARK: - 解绑确认
private struct UnbindConfirmSheet: View {
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.red)
                .padding(.top, Spacing.xl)
            Text("确认解除绑定？")
                .font(.h2)
                .foregroundStyle(Color.ink)
            Text("解绑后双方连胜与共享记录将停止累加")
                .font(.subhead)
                .foregroundStyle(Color.tertiaryText)
                .multilineTextAlignment(.center)
            HStack(spacing: Spacing.lg) {
                SecondaryButton(title: "再想想") { dismiss() }
                Button {
                    onConfirm()
                } label: {
                    Text("确认解绑")
                        .font(.h3)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: TouchTarget.buttonPrimary)
                        .background(Color.red)
                        .cornerRadius(CornerRadius.lg)
                }
            }
        }
        .padding(Spacing.xxl)
        .presentationDetents([.height(280)])
    }
}