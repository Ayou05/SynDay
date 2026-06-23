import Foundation

// MARK: - Task（严格对齐 backend/internal/model/task.go）

struct Task: Identifiable, Codable, Hashable {
    let id: String
    let businessDate: String
    let title: String
    let category: TaskCategory
    var status: TaskStatus
    let plannedTime: String?
    var isPinned: Bool
    let sortOrder: Int
    let completedAt: Date?
    let encouragement: String?
    let version: Int64
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case businessDate = "business_date"
        case title, category, status
        case plannedTime = "planned_time"
        case isPinned = "is_pinned"
        case sortOrder = "sort_order"
        case completedAt = "completed_at"
        case encouragement, version
        case createdAt = "created_at"
    }
}

enum TaskCategory: String, Codable {
    case course
    case selfStudy = "self_study"
    case temporary
}

enum TaskStatus: String, Codable {
    case pending      // 未开始
    case completed    // 已完成
    case expired      // 已作废（后端枚举名，对应"已作废"）
}

struct TodaySummary: Codable, Hashable {
    var businessDate: String
    var totalTasks: Int
    var completedTasks: Int
    var completionPercent: Int
    var focusSeconds: Int
    var currentStreak: Int
    var pendingMilestone: Int?

    enum CodingKeys: String, CodingKey {
        case businessDate = "business_date"
        case totalTasks = "total_tasks"
        case completedTasks = "completed_tasks"
        case completionPercent = "completion_percent"
        case focusSeconds = "focus_seconds"
        case currentStreak = "current_streak"
        case pendingMilestone = "pending_milestone"
    }

    static let empty = TodaySummary(businessDate: "", totalTasks: 0, completedTasks: 0,
                                     completionPercent: 0, focusSeconds: 0, currentStreak: 0,
                                     pendingMilestone: nil)
}

struct TodayResponse: Codable {
    let tasks: [Task]
    let summary: TodaySummary
}

struct CreateTaskInput: Encodable {
    let title: String
    let category: String
    let plannedTime: String?
    let isPinned: Bool
    let operationID: String

    enum CodingKeys: String, CodingKey {
        case title, category
        case plannedTime = "planned_time"
        case isPinned = "is_pinned"
        case operationID = "operation_id"
    }
}

struct UpdateTaskInput: Encodable {
    let action: String
    let version: Int64
    let operationID: String

    enum CodingKeys: String, CodingKey {
        case action, version
        case operationID = "operation_id"
    }
}

// MARK: - Focus（严格对齐 backend/internal/model/focus.go）

struct FocusSession: Codable, Identifiable, Hashable {
    let id: String
    let businessDate: String
    let mode: FocusMode
    var status: FocusStatus
    let startedAt: Date
    let plannedSeconds: Int?
    let endedAt: Date?
    let durationSeconds: Int
    let isValid: Bool
    let shareWithPartner: Bool
    let sharedRoomID: String?
    let version: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case businessDate = "business_date"
        case mode, status
        case startedAt = "started_at"
        case plannedSeconds = "planned_seconds"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case isValid = "is_valid"
        case shareWithPartner = "share_with_partner"
        case sharedRoomID = "shared_room_id"
        case version
    }
}

enum FocusMode: String, Codable {
    case soloCountup = "solo_countup"
    case soloCountdown = "solo_countdown"
    case sharedCountup = "shared_countup"
    case sharedCountdown = "shared_countdown"

    var isCountdown: Bool {
        self == .soloCountdown || self == .sharedCountdown
    }

    var isShared: Bool {
        self == .sharedCountup || self == .sharedCountdown
    }

    var displayName: String {
        switch self {
        case .soloCountup: return "正计时 · 单人"
        case .soloCountdown: return "倒计时 · 单人"
        case .sharedCountup: return "正计时 · 共享"
        case .sharedCountdown: return "倒计时 · 共享"
        }
    }
}

enum FocusStatus: String, Codable {
    case active
    case completed
    case voided
}

struct StartFocusInput: Encodable {
    let mode: String
    let plannedSeconds: Int?
    let shareWithPartner: Bool
    let operationID: String

    enum CodingKeys: String, CodingKey {
        case mode
        case plannedSeconds = "planned_seconds"
        case shareWithPartner = "share_with_partner"
        case operationID = "operation_id"
    }
}

struct StopFocusInput: Encodable {
    let operationID: String
    enum CodingKeys: String, CodingKey { case operationID = "operation_id" }
}

// MARK: - Settings（严格对齐 backend/internal/model/settings.go）

struct Settings: Codable {
    var displayName: String
    var aiTone: String
    var externalCheckinEnabled: Bool
    var bedtime: String?
    var notificationReviewEnabled: Bool
    var notificationBedtimeEnabled: Bool
    var notificationPartnerEnabled: Bool
    var notificationStreakEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case aiTone = "ai_tone"
        case externalCheckinEnabled = "external_checkin_enabled"
        case bedtime
        case notificationReviewEnabled = "notification_review_enabled"
        case notificationBedtimeEnabled = "notification_bedtime_enabled"
        case notificationPartnerEnabled = "notification_partner_enabled"
        case notificationStreakEnabled = "notification_streak_enabled"
    }
}

struct LeaveDay: Codable, Identifiable, Hashable {
    let id: String
    let kind: String
    let businessDate: String?
    let weekday: Int?

    enum CodingKeys: String, CodingKey {
        case id, kind
        case businessDate = "business_date"
        case weekday
    }
}

struct LeaveInput: Encodable {
    let kind: String
    let businessDate: String?
    let weekday: Int?

    enum CodingKeys: String, CodingKey {
        case kind
        case businessDate = "business_date"
        case weekday
    }
}

// MARK: - Review & Calendar（严格对齐 backend/internal/model/review.go）

struct Review: Codable, Identifiable, Hashable {
    let id: String
    let businessDate: String
    let title: String
    let fullText: String
    let compactText: String
    let structuredData: String? // 后端是 json.RawMessage，这里存原始 JSON 字符串
    let aiStatus: String
    let generatedAt: Date?
    let finalizedAt: Date?
    let version: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case businessDate = "business_date"
        case title
        case fullText = "full_text"
        case compactText = "compact_text"
        case structuredData = "structured_data"
        case aiStatus = "ai_status"
        case generatedAt = "generated_at"
        case finalizedAt = "finalized_at"
        case version
    }
}

struct UpdateReviewInput: Encodable {
    let fullText: String
    let version: Int64
    enum CodingKeys: String, CodingKey {
        case fullText = "full_text"
        case version
    }
}

struct CalendarDay: Codable, Hashable {
    let businessDate: String
    let qualified: Bool
    let exempt: Bool
    let taskCount: Int
    let focusSeconds: Int

    enum CodingKeys: String, CodingKey {
        case businessDate = "business_date"
        case qualified, exempt
        case taskCount = "task_completed_count"
        case focusSeconds = "focus_seconds"
    }
}

struct CalendarResponse: Codable {
    let days: [CalendarDay]
}

// MARK: - Plan（严格对齐 backend/internal/model/plan.go）

struct Plan: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: TaskCategory
    let recurrence: String
    let startsOn: String
    let endsOn: String?
    let weekdays: [Int]
    let plannedTime: String?
    let isPinned: Bool
    let isActive: Bool
    let version: Int64
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, category, recurrence
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case weekdays
        case plannedTime = "planned_time"
        case isPinned = "is_pinned"
        case isActive = "is_active"
        case version
        case createdAt = "created_at"
    }
}

struct PlanInput: Encodable {
    let title: String
    let category: String
    let recurrence: String
    let startsOn: String
    let endsOn: String?
    let weekdays: [Int]
    let plannedTime: String?
    let isPinned: Bool
    let version: Int64

    enum CodingKeys: String, CodingKey {
        case title, category, recurrence
        case startsOn = "starts_on"
        case endsOn = "ends_on"
        case weekdays
        case plannedTime = "planned_time"
        case isPinned = "is_pinned"
        case version
    }
}

// MARK: - Couple（严格对齐 backend/internal/model/couple.go）

struct PartnerOverview: Codable {
    let userID: String
    let displayName: String
    let completionPercent: Int
    let currentStreak: Int
    let isFocusing: Bool
    let focusStartedAt: Date?
    let focusMode: String?
    let focusRoomID: String?
    let tasks: [Task]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case completionPercent = "completion_percent"
        case currentStreak = "current_streak"
        case isFocusing = "is_focusing"
        case focusStartedAt = "focus_started_at"
        case focusMode = "focus_mode"
        case focusRoomID = "focus_room_id"
        case tasks
    }
}

// MARK: - 通用

struct ServerTime: Codable {
    let serverTime: Date
    let timezone: String
    let businessDate: String

    enum CodingKeys: String, CodingKey {
        case serverTime = "server_time"
        case timezone
        case businessDate = "business_date"
    }
}

struct ReadyResponse: Codable {
    let status: String
    let database: Bool
    let capabilities: Capabilities?
    struct Capabilities: Codable {
        let ai: Bool?
        let realtime: Bool?
        let apns: Bool?
        let fcm: Bool?
        let qiniu: Bool?
    }
}

// MARK: - 唯一操作 ID（用于后端幂等）

enum OperationID {
    static func generate() -> String {
        UUID().uuidString
    }
}
