import Foundation
import SwiftUI

enum FocusVMState: Equatable {
    case idle
    case focusing
    case stopping
    case completed
    case rating
}

@Observable
final class FocusViewModel {
    var state: FocusVMState = .idle
    var activeSession: FocusSession?
    var todayTotalSeconds: Int = 0
    var todayCount: Int = 0
    var partnerFocus: PartnerFocusInfo?
    var error: String?
    var isLoading = false

    // 计时
    private(set) var elapsedSeconds: Int = 0
    private var timerTask: Swift.Task<Void, Never>?

    struct PartnerFocusInfo {
        let displayName: String
        let isFocusing: Bool
        let startedAt: Date?
        let mode: FocusMode?
        let shareWithPartner: Bool
    }

    // MARK: - 加载
    func load() async {
        async let activeTask = fetchActive()
        async let todayTask = fetchToday()
        do {
            let active = try await activeTask
            if let active {
                self.activeSession = active
                if active.status == .active {
                    self.state = .focusing
                    startTimer(from: active.startedAt, planned: active.plannedSeconds)
                }
            }
            let today = try await todayTask
            self.todayTotalSeconds = today.summary.focusSeconds
            // 今日专注次数从任务数近似（后端无专门字段，用 focus_seconds>0 粗略）
            self.todayCount = max(1, today.summary.focusSeconds / 60 / 25) // 占位估算
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func fetchActive() async throws -> FocusSession? {
        do {
            return try await APIClient.shared.request("/v1/focus/active")
        } catch let error as APIClient.APIError where error.status == 404 {
            _ = error
            return nil
        }
    }

    private func fetchToday() async throws -> TodayResponse {
        try await APIClient.shared.request("/v1/today")
    }

    // MARK: - 开始专注
    func startFocus(mode: FocusMode, plannedSeconds: Int?, shareWithPartner: Bool) async {
        isLoading = true
        let input = StartFocusInput(mode: mode.rawValue,
                                     plannedSeconds: plannedSeconds,
                                     shareWithPartner: shareWithPartner,
                                     operationID: OperationID.generate())
        do {
            let session: FocusSession = try await APIClient.shared.request("/v1/focus/start", method: .POST, body: input)
            self.activeSession = session
            self.state = .focusing
            self.error = nil
            startTimer(from: session.startedAt, planned: session.plannedSeconds)
            Haptics.mediumImpact()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
        isLoading = false
    }

    // MARK: - 结束专注
    func stopFocus() async {
        guard activeSession != nil else { return }
        state = .stopping
        let input = StopFocusInput(operationID: OperationID.generate())
        do {
            let session: FocusSession = try await APIClient.shared.request("/v1/focus/stop", method: .POST, body: input)
            self.activeSession = session
            stopTimer()
            self.elapsedSeconds = session.durationSeconds
            Haptics.focusEnded()
            self.state = .rating
        } catch let error as APIClient.APIError where error.status == 409 {
            // 版本冲突，刷新
            self.error = error.message
            await load()
        } catch {
            self.error = error.localizedDescription
            self.state = .focusing // 回滚
            Haptics.error()
        }
    }

    // MARK: - 打分完成
    func finishRating() {
        state = .idle
        activeSession = nil
        elapsedSeconds = 0
        Swift.Task { await load() }
    }

    // MARK: - 计时器（用时间戳校准，不用 Timer.publish）
    private func startTimer(from startedAt: Date, planned: Int?) {
        timerTask?.cancel()
        elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
        timerTask = Swift.Task { [weak self] in
            while !Swift.Task.isCancelled {
                guard let self else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
                // 倒计时归零
                if let planned, self.elapsedSeconds >= planned {
                    await MainActor.run {
                        self.handleCountdownFinished()
                    }
                    return
                }
                try? await Swift.Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func handleCountdownFinished() {
        Haptics.countdownFinished()
        stopTimer()
        Swift.Task { await stopFocus() }
    }

    // MARK: - 格式化
    var elapsedDisplay: String {
        formatDuration(elapsedSeconds)
    }

    var remainingDisplay: String? {
        guard let planned = activeSession?.plannedSeconds else { return nil }
        let remaining = max(0, planned - elapsedSeconds)
        return formatDuration(remaining)
    }

    var progress: Double {
        guard let planned = activeSession?.plannedSeconds, planned > 0 else { return 0 }
        return min(1.0, Double(elapsedSeconds) / Double(planned))
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var todayTotalMinutes: Int { todayTotalSeconds / 60 }

    func cancelActiveOnAppear() {
        // 占位：进入页面时如果有遗留 active 会自动恢复
    }
}
