import SwiftUI

// MARK: - 月度日历页
struct CalendarView: View {
    @State private var currentMonth: Date = Date()
    @State private var days: [CalendarDay] = []
    @State private var isLoading = false
    @State private var error: String?

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        VStack(spacing: Spacing.md) {
            // 月份切换
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

            // 星期表头
            HStack(spacing: 0) {
                ForEach(["日","一","二","三","四","五","六"], id: \.self) { w in
                    Text(w)
                        .font(.caption)
                        .foregroundStyle(Color.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Spacing.sm)

            // 日期格子
            let grid = monthGrid(currentMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: Spacing.xs) {
                ForEach(grid, id: \.self) { date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, Spacing.sm)

            // 图例
            HStack(spacing: Spacing.lg) {
                legendItem(color: Color.forest.opacity(0.15), text: "有效打卡")
                legendItem(color: Color.surfaceStrong, text: "休息日")
                legendItem(color: Color.forest, text: "今天", isCircle: true)
            }
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .padding(.top, Spacing.md)

            Spacer()
        }
        .background(Color.canvas)
        .navigationTitle("月度日历")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let dayInfo = days.first { $0.businessDate == businessDateString(date) }
        let isExempt = dayInfo?.exempt ?? false
        let isQualified = dayInfo?.qualified ?? false

        let background: Color = {
            if isToday { return Color.forest }
            if isExempt { return Color.surfaceStrong }
            if isQualified { return Color.forest.opacity(0.15) }
            return Color.canvas
        }()
        let textColor: Color = {
            if isToday { return .white }
            if isExempt { return .secondaryText }
            if isQualified { return .forest }
            return .tertiaryText
        }()

        Text("\(calendar.component(.day, from: date))")
            .font(.system(size: 14, weight: isToday || isQualified ? .semibold : .regular))
            .foregroundStyle(textColor)
            .frame(width: 40, height: 40)
            .background(background)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.forest, lineWidth: isToday ? 0 : (isQualified ? 0 : 0))
            )
            .shadow(color: isToday ? Color.forest.opacity(0.3) : .clear, radius: isToday ? 4 : 0, y: 1)
    }

    private func legendItem(color: Color, text: String, isCircle: Bool = false) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    private func monthTitle(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f.string(from: d)
    }

    private func businessDateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: d)
    }

    private func monthGrid(_ month: Date) -> [Date?] {
        guard let range = calendar.dateInterval(of: .month, for: month) else { return [] }
        let firstDay = range.start
        let weekday = calendar.component(.weekday, from: firstDay)
        var grid: [Date?] = Array(repeating: nil, count: weekday - 1)
        var current = firstDay
        while current < range.end {
            grid.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return grid
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
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
