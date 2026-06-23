import SwiftUI

struct FocusView: View {
    @State private var vm = FocusViewModel()
    @State private var showModeSheet = false
    @State private var showStopConfirm = false
    @State private var showRating = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                if let error = vm.error {
                    ErrorBanner(message: error)
                }

                focusStatusCard
                    .frame(maxWidth: .infinity)

                TodayOverview(totalMinutes: vm.todayTotalMinutes, count: vm.todayCount)

                if vm.partnerFocus != nil {
                    PartnerFocusCard(info: vm.partnerFocus!)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)
            .background(Color.canvas)
            .navigationTitle("专注")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await vm.load() }
        .sheet(isPresented: $showModeSheet) {
            FocusModeSheet { mode, planned, share in
                showModeSheet = false
                Swift.Task { await vm.startFocus(mode: mode, plannedSeconds: planned, shareWithPartner: share) }
            }
        }
        .sheet(isPresented: $showStopConfirm) {
            StopConfirmSheet {
                showStopConfirm = false
                Swift.Task { await vm.stopFocus() }
            }
        }
        .onChange(of: vm.state) { _, newState in
            if newState == .rating { showRating = true }
        }
        .sheet(isPresented: $showRating, onDismiss: { vm.finishRating() }) {
            RatingSheet { vm.finishRating() }
        }
    }

    @ViewBuilder
    private var focusStatusCard: some View {
        switch vm.state {
        case .idle:
            IdleCard(lastFocusMinutes: vm.todayTotalMinutes) {
                showModeSheet = true
            }
        case .focusing, .stopping:
            if let session = vm.activeSession {
                FocusingCard(session: session,
                             elapsed: vm.elapsedDisplay,
                             remaining: vm.remainingDisplay,
                             progress: vm.progress,
                             isStopping: vm.state == .stopping) {
                    showStopConfirm = true
                }
            }
        case .completed, .rating:
            IdleCard(lastFocusMinutes: vm.todayTotalMinutes) { showModeSheet = true }
        }
    }
}

// MARK: - Idle 卡片
private struct IdleCard: View {
    let lastFocusMinutes: Int
    let onStart: () -> Void
    @State private var breath = false

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.forest.opacity(0.08))
                        .frame(width: 140, height: 140)
                        .scaleEffect(breath ? 1.08 : 0.92)
                        .opacity(breath ? 0.7 : 0.3)

                    Circle()
                        .fill(Color.forest.opacity(0.12))
                        .frame(width: 108, height: 108)
                        .scaleEffect(breath ? 1.04 : 0.98)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(Color.forest)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                        breath = true
                    }
                }

                VStack(spacing: Spacing.xs) {
                    Text("准备好就开始吧")
                        .font(.h2)
                        .foregroundStyle(Color.ink)
                    if lastFocusMinutes > 0 {
                        Text("今天已经专注 \(lastFocusMinutes) 分钟")
                            .font(.subhead)
                            .foregroundStyle(Color.tertiaryText)
                    } else {
                        Text("选一种方式，进入心流")
                            .font(.subhead)
                            .foregroundStyle(Color.tertiaryText)
                    }
                }
            }

            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.lg) {
                    modeButton(icon: "infinity", title: "正计时", isPrimary: false, action: onStart)
                    modeButton(icon: "hourglass", title: "倒计时", isPrimary: true, action: onStart)
                }
                SecondaryButton(title: "邀请 TA 一起专注") { /* TODO: 阶段二 */ }
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceSoft)
        .cornerRadius(CornerRadius.xl)
        .cardElevation()
    }

    private func modeButton(icon: String, title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                Text(title)
                    .font(.h3)
            }
            .foregroundStyle(isPrimary ? Color.white : Color.forest)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(isPrimary ? Color.forest : Color.canvas)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(isPrimary ? Color.clear : Color.hairline, lineWidth: 1)
            )
            .cornerRadius(CornerRadius.lg)
        }
    }
}

// MARK: - Focusing 卡片
private struct FocusingCard: View {
    let session: FocusSession
    let elapsed: String
    let remaining: String?
    let progress: Double
    let isStopping: Bool
    let onStop: () -> Void

    private var isCountdown: Bool { session.mode.isCountdown }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // 圆环进度 + 计时
            ZStack {
                Circle()
                    .stroke(Color.forest.opacity(0.12), lineWidth: 6)
                    .frame(width: 220, height: 220)

                if isCountdown {
                    Circle()
                        .trim(from: 0, to: max(0.001, progress))
                        .stroke(BrandGradient.focusRing, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 220, height: 220)
                        .animation(.linear(duration: 0.3), value: progress)
                }

                VStack(spacing: Spacing.xs) {
                    Text(remaining ?? elapsed)
                        .font(.display)
                        .foregroundStyle(Color.forest)
                        .monospacedDigit()
                    Text(session.mode.displayName)
                        .font(.subhead)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .padding(.top, Spacing.md)

            // 结束按钮
            Button {
                onStop()
            } label: {
                Group {
                    if isStopping {
                        HStack(spacing: Spacing.xs) {
                            ProgressView().tint(.red)
                            Text("结束中…")
                        }
                    } else {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "stop.fill")
                            Text("结束专注")
                        }
                    }
                }
                .font(.h3)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.lg).stroke(Color.red.opacity(0.2), lineWidth: 1))
                .cornerRadius(CornerRadius.lg)
            }

            if session.shareWithPartner {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(Color.forest)
                    Text("伴侣可以看到你正在专注")
                        .font(.subhead)
                        .foregroundStyle(Color.secondaryText)
                }
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceSoft)
        .cornerRadius(CornerRadius.xl)
        .cardElevation()
    }
}

// MARK: - 今日概览
private struct TodayOverview: View {
    let totalMinutes: Int
    let count: Int

    var body: some View {
        HStack(spacing: 0) {
            overviewCell(value: "\(totalMinutes)", unit: "分钟", label: "今日累计")
            Divider().background(Color.hairline).frame(height: 36)
            overviewCell(value: "\(count)", unit: "次", label: "有效次数")
        }
        .padding(Spacing.lg)
        .background(Color.surfaceSoft)
        .cornerRadius(CornerRadius.lg)
        .cardElevation()
    }

    private func overviewCell(value: String, unit: String, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
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

// MARK: - 伴侣专注卡片
private struct PartnerFocusCard: View {
    let info: FocusViewModel.PartnerFocusInfo

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(info.isFocusing ? Color.forest.opacity(0.15) : Color.surfaceStrong.opacity(0.5))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.forest)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(info.displayName)
                    .font(.body)
                    .foregroundStyle(Color.ink)
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(info.isFocusing ? Color.forest : Color.tertiaryText)
                        .frame(width: 6, height: 6)
                    Text(info.isFocusing ? "正在专注" : "TA 现在不在专注中")
                        .font(.subhead)
                        .foregroundStyle(info.isFocusing ? Color.forest : Color.secondaryText)
                }
            }
            Spacer()
            if info.isFocusing {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Color.forest.opacity(0.6))
            }
        }
        .padding(Spacing.lg)
        .background(Color.canvas)
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.lg).stroke(Color.hairline, lineWidth: 0.5))
        .cornerRadius(CornerRadius.lg)
    }
}

// MARK: - 模式选择 Sheet
private struct FocusModeSheet: View {
    @State private var mode: FocusMode = .soloCountup
    @State private var duration: Int = 60
    @State private var shareWithPartner = true
    @Environment(\.dismiss) private var dismiss
    let onStart: (FocusMode, Int?, Bool) -> Void

    private let durations = [30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            Form {
                Section("模式") {
                    Picker("专注模式", selection: $mode) {
                        Text("正计时 · 单人").tag(FocusMode.soloCountup)
                        Text("倒计时 · 单人").tag(FocusMode.soloCountdown)
                        Text("正计时 · 共享").tag(FocusMode.sharedCountup)
                        Text("倒计时 · 共享").tag(FocusMode.sharedCountdown)
                    }
                }
                if mode.isCountdown {
                    Section("时长") {
                        Picker("倒计时长", selection: $duration) {
                            ForEach(durations, id: \.self) { d in
                                Text("\(d)分钟").tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if mode.isShared {
                    Section {
                        Toggle("伴侣可以看到", isOn: $shareWithPartner).tint(.forest)
                    }
                }
                Section {
                    Button {
                        onStart(mode, mode.isCountdown ? duration * 60 : nil, shareWithPartner)
                    } label: {
                        Text("开始专注")
                            .font(.h3)
                            .foregroundStyle(Color.forest)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("开始专注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 结束确认 Sheet
private struct StopConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "stop.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.red)
                .padding(.top, Spacing.xl)
            Text("确认结束本次专注？")
                .font(.h2)
                .foregroundStyle(Color.ink)
            Text("剩余时间将不计入今日专注")
                .font(.subhead)
                .foregroundStyle(Color.tertiaryText)
            HStack(spacing: Spacing.lg) {
                SecondaryButton(title: "继续专注") { dismiss() }
                Button {
                    onConfirm()
                } label: {
                    Text("确认结束")
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
        .presentationDetents([.height(240)])
    }
}

// MARK: - 打分弹窗
private struct RatingSheet: View {
    let onRate: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("这次专注感觉如何？")
                .font(.h2)
                .foregroundStyle(Color.ink)
                .padding(.top, Spacing.xxl)
            HStack(spacing: Spacing.lg) {
                ratingButton(icon: "face.smiling.fill", title: "状态不错", tint: Color.forest) {
                    Haptics.taskCompleted()
                    onRate()
                }
                ratingButton(icon: "face.neutral.fill", title: "状态一般", tint: Color.secondaryText) {
                    Haptics.taskCompleted()
                    onRate()
                }
            }
            TextButton(title: "跳过", action: onRate)
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .presentationDetents([.height(340)])
    }

    private func ratingButton(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .regular))
                Text(title)
                    .font(.h3)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Color.surfaceSoft)
            .cornerRadius(CornerRadius.lg)
        }
    }
}
