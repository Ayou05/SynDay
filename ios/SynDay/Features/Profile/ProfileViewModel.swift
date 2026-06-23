import Foundation
import SwiftUI

@Observable
final class ProfileViewModel {
    var settings: Settings?
    var leaveDays: [LeaveDay] = []
    var streak: Int = 0
    var todayPercent: Int = 0
    var weekCheckinDays: Int = 0
    var weekFocusSeconds: Int = 0
    var isLoading = false
    var error: String?

    /// 加载设置 + 今日数据概览（今日完成率来自 today summary）
    func load() async {
        isLoading = true
        error = nil
        async let settingsResult = fetchSettings()
        async let todayResult = fetchToday()
        do {
            let (s, leaves) = try await settingsResult
            let today = try await todayResult
            self.settings = s
            self.leaveDays = leaves
            self.streak = today.summary.currentStreak
            self.todayPercent = today.summary.completionPercent
            self.weekFocusSeconds = today.summary.focusSeconds
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func fetchSettings() async throws -> (Settings, [LeaveDay]) {
        struct SettingsResponse: Codable {
            let settings: Settings
            let leaveDays: [LeaveDay]
            enum CodingKeys: String, CodingKey {
                case settings
                case leaveDays = "leave_days"
            }
        }
        let resp: SettingsResponse = try await APIClient.shared.request("/v1/settings")
        return (resp.settings, resp.leaveDays)
    }

    private func fetchToday() async throws -> TodayResponse {
        try await APIClient.shared.request("/v1/today")
    }

    func updateSettings(_ settings: Settings) async throws {
        let updated: Settings = try await APIClient.shared.request("/v1/settings", method: .PUT, body: settings)
        self.settings = updated
    }

    /// 单字段更新辅助（保持其他字段不变）
    func updateSettings(updating base: Settings,
                        displayName: String? = nil,
                        aiTone: String? = nil,
                        externalCheckin: Bool? = nil,
                        bedtime: String? = nil,
                        review: Bool? = nil,
                        bedtimeNotify: Bool? = nil,
                        partner: Bool? = nil,
                        streak: Bool? = nil) async throws {
        var s = base
        if let displayName { s.displayName = displayName }
        if let aiTone { s.aiTone = aiTone }
        if let externalCheckin { s.externalCheckinEnabled = externalCheckin }
        if let bedtime { s.bedtime = bedtime }
        if let review { s.notificationReviewEnabled = review }
        if let bedtimeNotify { s.notificationBedtimeEnabled = bedtimeNotify }
        if let partner { s.notificationPartnerEnabled = partner }
        if let streak { s.notificationStreakEnabled = streak }
        try await updateSettings(s)
    }

    func addLeaveDay(kind: String, businessDate: String?, weekday: Int?) async throws {
        let input = LeaveInput(kind: kind, businessDate: businessDate, weekday: weekday)
        let day: LeaveDay = try await APIClient.shared.request("/v1/settings/leave-days", method: .POST, body: input)
        leaveDays.append(day)
    }

    func deleteLeaveDay(_ id: String) async throws {
        try await APIClient.shared.requestEmpty("/v1/settings/leave-days/\(id)", method: .DELETE)
        leaveDays.removeAll { $0.id == id }
    }

    var weekFocusMinutes: Int {
        weekFocusSeconds / 60
    }
}
