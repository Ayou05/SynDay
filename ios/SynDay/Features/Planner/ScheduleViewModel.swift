import Foundation
import SwiftUI

// MARK: - Agent 卡片状态
enum AgentScenario: Equatable {
    case onTime          // 准时
    case slightlyLate    // 轻微迟到
    case severelyLate    // 严重超时
    case none            // 无任务

    var fallbackText: String {
        switch self {
        case .onTime: return "专注力在线，安心开始吧"
        case .slightlyLate: return "只晚了一小会儿，不用苛责自己"
        case .severelyLate: return "已过半程，重启完整任务会很割裂"
        case .none: return ""
        }
    }

    var options: [AgentOption] {
        switch self {
        case .onTime: return [.startFocus]
        case .slightlyLate: return [.coreVersion, .deferLater, .switchLight]
        case .severelyLate: return [.deferEvening, .fragmentReview]
        case .none: return []
        }
    }
}

enum AgentOption: String, CaseIterable, Identifiable {
    case startFocus = "开启专注计时"
    case coreVersion = "精简核心版"
    case deferLater = "延后处理"
    case switchLight = "换轻任务"
    case deferEvening = "顺延至晚间"
    case fragmentReview = "碎片复盘"
    var id: String { rawValue }
}

struct AgentCardState: Equatable {
    let scenario: AgentScenario
    var text: String           // LLM 文案，有本地兜底
    let task: Task?
    let remainingMinutes: Int?
}

@Observable
final class ScheduleViewModel {
    var tasks: [Task] = []
    var summary: TodaySummary = .empty
    var agentCard: AgentCardState?
    var isLoading = false
    var online = true
    var error: String?

    private var lastScenario: AgentScenario = .none

    // MARK: - 加载今日
    func load() async {
        isLoading = true
        do {
            let resp: TodayResponse = try await APIClient.shared.request("/v1/today")
            self.tasks = resp.tasks.sorted { sortKey($0) < sortKey($1) }
            self.summary = resp.summary
            self.error = nil
            refreshAgentCard()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func sortKey(_ task: Task) -> (Int, String) {
        // 置顶优先，再按 planned_time 排
        let pin = task.isPinned ? 0 : 1
        return (pin, task.plannedTime ?? "99:99")
    }

    // MARK: - Agent 卡片刷新
    /// 根据当前时间和任务推断场景，同场景不重复刷新（LLM 调用节流）
    func refreshAgentCard() {
        let now = Date()
        guard let current = findCurrentTask(at: now) else {
            agentCard = nil
            lastScenario = .none
            return
        }
        let scenario = detectScenario(task: current, now: now)
        if scenario == lastScenario, let existing = agentCard {
            agentCard = existing // 不变
            return
        }
        lastScenario = scenario
        // 阶段一：用本地兜底文案，阶段三接 LLM
        agentCard = AgentCardState(scenario: scenario,
                                    text: scenario.fallbackText,
                                    task: current,
                                    remainingMinutes: remainingMinutes(task: current, now: now))
    }

    private func findCurrentTask(at now: Date) -> Task? {
        // 找当前时间应该执行的学习任务（未完成 + 有 planned_time）
        return tasks.first { task in
            task.status == .pending && task.category != .course && task.plannedTime != nil
        }
    }

    private func detectScenario(task: Task, now: Date) -> AgentScenario {
        guard let plannedStr = task.plannedTime,
              let planned = parseTime(plannedStr) else { return .onTime }
        let nowMinutes = currentMinutes(now)
        let diff = nowMinutes - planned
        if diff < 10 { return .onTime }
        if diff < 30 { return .slightlyLate }
        return .severelyLate
    }

    private func remainingMinutes(task: Task, now: Date) -> Int? {
        guard let plannedStr = task.plannedTime,
              let planned = parseTime(plannedStr) else { return nil }
        let nowMinutes = currentMinutes(now)
        return max(0, 60 - (nowMinutes - planned)) // 默认 60min 任务
    }

    private func parseTime(_ s: String) -> Int? {
        let parts = s.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    private func currentTimeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: d)
    }

    private func currentMinutes(_ d: Date) -> Int {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let str = f.string(from: d)
        return parseTime(str) ?? 0
    }

    // MARK: - 乐观更新：完成任务
    func completeTask(_ task: Task) async {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let original = tasks[idx]
        // 本地立即打勾
        tasks[idx].status = .completed
        summary.completedTasks += 1
        summary.completionPercent = summary.totalTasks > 0
            ? Int(Double(summary.completedTasks) / Double(summary.totalTasks) * 100) : 0
        Haptics.taskCompleted()

        do {
            let input = UpdateTaskInput(action: "complete", version: task.version, operationID: OperationID.generate())
            let updated: Task = try await APIClient.shared.request("/v1/tasks/\(task.id)", method: .PATCH, body: input)
            tasks[idx] = updated
            refreshAgentCard()
        } catch {
            // 回滚
            tasks[idx] = original
            summary.completedTasks -= 1
            self.error = "网络波动，请稍后重试"
            Haptics.error()
        }
    }

    // MARK: - 乐观更新：置顶
    func togglePin(_ task: Task) async {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let original = tasks[idx]
        tasks[idx].isPinned.toggle()

        let action = tasks[idx].isPinned ? "pin" : "unpin"
        do {
            let input = UpdateTaskInput(action: action, version: task.version, operationID: OperationID.generate())
            let updated: Task = try await APIClient.shared.request("/v1/tasks/\(task.id)", method: .PATCH, body: input)
            tasks[idx] = updated
            tasks.sort { sortKey($0) < sortKey($1) }
        } catch {
            tasks[idx] = original
            Haptics.error()
        }
    }

    // MARK: - 乐观更新：删除任务
    func deleteTask(_ task: Task) async {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let original = tasks[idx]
        tasks.remove(at: idx)
        summary.totalTasks = max(0, summary.totalTasks - 1)

        do {
            try await APIClient.shared.requestEmpty("/v1/tasks/\(task.id)", method: .DELETE)
            refreshAgentCard()
        } catch {
            tasks.insert(original, at: idx)
            summary.totalTasks += 1
            self.error = "删除失败，请稍后重试"
            Haptics.error()
        }
    }

    // MARK: - 新增任务
    func createTask(title: String, category: TaskCategory, plannedTime: String?, isPinned: Bool) async {
        let input = CreateTaskInput(title: title, category: category.rawValue,
                                     plannedTime: plannedTime, isPinned: isPinned,
                                     operationID: OperationID.generate())
        do {
            let task: Task = try await APIClient.shared.request("/v1/tasks", method: .POST, body: input)
            tasks.append(task)
            tasks.sort { sortKey($0) < sortKey($1) }
            summary.totalTasks += 1
            refreshAgentCard()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }
}
