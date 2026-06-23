import UIKit
import CoreHaptics

enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        light.prepare()
        medium.prepare()
        selection.prepare()
        notification.prepare()
    }

    /// 任务完成
    static func taskCompleted() { light.impactOccurred() }

    /// 通用中等震动（开始专注等中等反馈）
    static func mediumImpact() { medium.impactOccurred() }

    /// 专注结束 / 倒计时归零
    static func focusEnded() { medium.impactOccurred() }

    /// 倒计时归零（带通知震动）
    static func countdownFinished() {
        medium.impactOccurred()
        notification.notificationOccurred(.warning)
    }

    /// 绑定成功
    static func success() { notification.notificationOccurred(.success) }

    /// 操作失败
    static func error() { notification.notificationOccurred(.error) }

    /// 滑动 / 选择操作
    static func selectionChanged() { selection.selectionChanged() }
}
