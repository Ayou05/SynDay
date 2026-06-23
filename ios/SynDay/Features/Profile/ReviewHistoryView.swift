import SwiftUI

// MARK: - 历史复盘页
struct ReviewHistoryView: View {
    @State private var currentMonth: Date = Date()
    @State private var days: [CalendarDay] = []
    @State private var isLoading = false

    private let calendar = Calendar(identifier: .gregorian)

    /// 从日历数据里筛出有有效打卡或休息日的日期，倒序展示
    private var reviewDays: [CalendarDay] {
        days.filter { $0.qualified || $0.exempt }
            .sorted { $0.businessDate > $1.businessDate }
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Button { changeMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.forest)
                        .frame(width: 32, height: 32)
                }
                Spacer()
                Text(monthTitle(currentMonth))
                    .font(.h2)
                    .foregroundStyle(Color.ink)
                Spacer()
                Button { changeMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.forest)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, Spacing.lg)

            if reviewDays.isEmpty && !isLoading {
                EmptyState(icon: "doc.text.magnifyingglass",
                           title: "本月还没有复盘记录",
                           subtitle: "完成打卡后会在 23:30 自动生成")
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(reviewDays, id: \.businessDate) { day in
                            NavigationLink {
                                ReviewDetailView(businessDate: day.businessDate)
                            } label: {
                                ReviewRow(day: day)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                }
            }
        }
        .background(Color.canvas)
        .navigationTitle("历史复盘")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func monthTitle(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: d)
    }

    private func changeMonth(_ delta: Int) {
        currentMonth = calendar.date(byAdding: .month, value: delta, to: currentMonth) ?? currentMonth
        Swift.Task { await load() }
    }

    private func load() async {
        isLoading = true
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-01"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let month = f.string(from: currentMonth)
        do {
            let resp: CalendarResponse = try await APIClient.shared.request(
                "/v1/calendar", query: [URLQueryItem(name: "month", value: month)])
            self.days = resp.days
        } catch { }
        isLoading = false
    }
}

private struct ReviewRow: View {
    let day: CalendarDay

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(day.exempt ? Color.surfaceStrong : Color.forest.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: day.exempt ? "beach.umbrella.fill" : "checkmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(day.exempt ? Color.secondaryText : Color.forest)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(formatDate(day.businessDate))
                    .font(.body)
                    .foregroundStyle(Color.ink)
                Text(day.exempt ? "休息日" : "每日学习复盘")
                    .font(.subhead)
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.tertiaryText)
        }
        .padding(Spacing.lg)
        .background(Color.surfaceSoft)
        .cornerRadius(CornerRadius.lg)
        .cardElevation()
    }

    private func formatDate(_ s: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        guard let d = f.date(from: s) else { return s }
        let out = DateFormatter()
        out.locale = Locale(identifier: "zh_CN")
        out.dateFormat = "M月d日"
        return out.string(from: d)
    }
}

// MARK: - 复盘详情页
struct ReviewDetailView: View {
    let businessDate: String
    @State private var review: Review?
    @State private var editableText: String = ""
    @State private var isSaving = false
    @State private var isLoading = false
    @State private var showCopiedToast = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if isLoading {
                    ProgressView().tint(.forest).padding(.top, Spacing.xxl)
                } else if let review {
                    // 当日总览 Section
                    ReviewSection(title: "当日总览") {
                        Text(review.fullText.isEmpty ? "暂无内容" : review.fullText)
                            .font(.body)
                            .foregroundStyle(Color.ink)
                            .textSelection(.enabled)
                    }

                    // 复盘状态
                    HStack {
                        Image(systemName: statusIcon(review.aiStatus))
                            .foregroundStyle(Color.forest)
                        Text(statusText(review.aiStatus))
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                    }

                    // 编辑区
                    ReviewSection(title: "编辑详细版") {
                        TextEditor(text: $editableText)
                            .font(.body)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                    }

                    PrimaryButton(title: "保存", isLoading: isSaving) {
                        save()
                    }

                    // 一键复制精简版
                    SecondaryButton(title: "📋 复制精简提交版") {
                        copyCompact(review)
                    }
                } else {
                    EmptyState(icon: "doc.text", title: "暂无复盘", subtitle: "23:30 会自动生成")
                }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)
        }
        .background(Color.canvas)
        .navigationTitle(titleDate(businessDate))
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showCopiedToast { ToastView(message: "已复制精简版").padding(.top, Spacing.lg) }
        }
        .task { await load() }
    }

    private func statusIcon(_ s: String) -> String {
        switch s {
        case "ready", "finalized": return "checkmark.circle.fill"
        case "pending", "generating": return "clock"
        default: return "exclamationmark.circle"
        }
    }

    private func statusText(_ s: String) -> String {
        switch s {
        case "ready": return "AI已生成草稿，可编辑"
        case "finalized": return "已确认"
        case "pending": return "生成中"
        case "generating": return "AI正在生成"
        case "failed": return "AI生成失败，使用兜底文案"
        default: return s
        }
    }

    private func titleDate(_ s: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        guard let d = f.date(from: s) else { return s }
        let out = DateFormatter()
        out.locale = Locale(identifier: "zh_CN")
        out.dateFormat = "M月d日 每日学习复盘"
        return out.string(from: d)
    }

    private func load() async {
        isLoading = true
        do {
            let r: Review = try await APIClient.shared.request(
                "/v1/reviews/current", query: [URLQueryItem(name: "date", value: businessDate)])
            self.review = r
            self.editableText = r.fullText
        } catch { }
        isLoading = false
    }

    private func save() {
        guard let review else { return }
        Swift.Task {
            isSaving = true
            do {
                let input = UpdateReviewInput(fullText: editableText, version: review.version)
                let updated: Review = try await APIClient.shared.request(
                    "/v1/reviews/\(review.id)", method: .PUT, body: input)
                self.review = updated
                Haptics.taskCompleted()
            } catch { Haptics.error() }
            isSaving = false
        }
    }

    private func copyCompact(_ review: Review) {
        #if canImport(UIKit)
        UIPasteboard.general.string = review.compactText
        #endif
        Haptics.success()
        withAnimation { showCopiedToast = true }
        Swift.Task {
            try? await Swift.Task.sleep(for: .seconds(2))
            withAnimation { showCopiedToast = false }
        }
    }
}

struct ReviewSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.h3)
                .foregroundStyle(Color.ink)
            Card(background: Color.surfaceSoft) {
                VStack(alignment: .leading, spacing: 0) { content() }
            }
        }
    }
}
