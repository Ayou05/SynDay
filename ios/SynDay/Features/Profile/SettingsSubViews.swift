import SwiftUI

// MARK: - 通知设置子页
struct NotificationSettingsView: View {
    let settings: Settings
    @Bindable var vm: ProfileViewModel
    @State private var reviewEnabled: Bool
    @State private var bedtimeEnabled: Bool
    @State private var partnerEnabled: Bool
    @State private var streakEnabled: Bool
    @State private var externalCheckin: Bool

    init(settings: Settings, vm: ProfileViewModel) {
        self.settings = settings
        self.vm = vm
        _reviewEnabled = State(initialValue: settings.notificationReviewEnabled)
        _bedtimeEnabled = State(initialValue: settings.notificationBedtimeEnabled)
        _partnerEnabled = State(initialValue: settings.notificationPartnerEnabled)
        _streakEnabled = State(initialValue: settings.notificationStreakEnabled)
        _externalCheckin = State(initialValue: settings.externalCheckinEnabled)
    }

    var body: some View {
        Form {
            Section("复盘提醒") {
                Toggle("启用复盘提醒", isOn: $reviewEnabled)
                    .tint(.forest)
                    .onChange(of: reviewEnabled) { _, v in
                        Swift.Task { try? await vm.updateSettings(updating: settings, review: v) }
                    }
                if reviewEnabled {
                    Picker("提醒时间", selection: .constant("23:30")) {
                        Text("22:30").tag("22:30")
                        Text("23:00").tag("23:00")
                        Text("23:30").tag("23:30")
                    }
                    Text(externalCheckin ? "机构模式：23:30 强提醒（带声音）"
                                          : "普通模式：23:30 弱提醒（静默）")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            Section("其他提醒") {
                Toggle("睡前提醒", isOn: $bedtimeEnabled)
                    .tint(.forest)
                    .onChange(of: bedtimeEnabled) { _, v in
                        Swift.Task { try? await vm.updateSettings(updating: settings, bedtimeNotify: v) }
                    }
                Toggle("情侣动态", isOn: $partnerEnabled)
                    .tint(.forest)
                    .onChange(of: partnerEnabled) { _, v in
                        Swift.Task { try? await vm.updateSettings(updating: settings, partner: v) }
                    }
                Toggle("连胜里程碑", isOn: $streakEnabled)
                    .tint(.forest)
                    .onChange(of: streakEnabled) { _, v in
                        Swift.Task { try? await vm.updateSettings(updating: settings, streak: v) }
                    }
            }
            Section {
                Button(role: .destructive) {
                    Swift.Task {
                        try? await vm.updateSettings(updating: settings,
                                                      review: false, bedtimeNotify: false,
                                                      partner: false, streak: false)
                        reviewEnabled = false; bedtimeEnabled = false
                        partnerEnabled = false; streakEnabled = false
                        Haptics.success()
                    }
                } label: {
                    Text("全部静默").frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("通知设置")
    }
}

// MARK: - AI 语气偏好子页
struct AIPreferenceView: View {
    let settings: Settings
    @Bindable var vm: ProfileViewModel
    @State private var selection: String

    init(settings: Settings, vm: ProfileViewModel) {
        self.settings = settings
        self.vm = vm
        _selection = State(initialValue: settings.aiTone)
    }

    var body: some View {
        Form {
            Section("AI 语气") {
                toneRow(title: "克制温和", desc: "简洁克制，点到为止", value: "restrained")
                toneRow(title: "朋友陪伴", desc: "像朋友一样陪伴鼓励", value: "companion")
                toneRow(title: "简短有力", desc: "短句直接，有力量", value: "concise")
            }
        }
        .navigationTitle("AI 语气偏好")
    }

    private func toneRow(title: String, desc: String, value: String) -> some View {
        Button {
            selection = value
            Swift.Task { try? await vm.updateSettings(updating: settings, aiTone: value) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body).foregroundStyle(Color.ink)
                    Text(desc).font(.caption).foregroundStyle(Color.secondaryText)
                }
                Spacer()
                if selection == value {
                    Image(systemName: "checkmark").foregroundStyle(Color.forest)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 休息日配置子页
struct LeaveDayConfigView: View {
    @Bindable var vm: ProfileViewModel
    @State private var showAddSheet = false
    @State private var weekdaySelections: [Int] = []

    var body: some View {
        Form {
            Section("每周固定休息日") {
                if vm.leaveDays.filter({ $0.kind == "weekly_rest" }).isEmpty {
                    Text("尚未设置固定休息日")
                        .font(.subhead)
                        .foregroundStyle(Color.secondaryText)
                }
                ForEach(vm.leaveDays.filter { $0.kind == "weekly_rest" }) { day in
                    HStack {
                        Text(weekdayName(day.weekday ?? 0))
                            .font(.body)
                        Spacer()
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Swift.Task { try? await vm.deleteLeaveDay(day.id) }
                        } label: { Label("删除", systemImage: "trash") }
                    }
                }
            }
            Section("临时休息日") {
                if vm.leaveDays.filter({ $0.kind == "temporary_leave" }).isEmpty {
                    Text("每月最多2天，不可连续")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                ForEach(vm.leaveDays.filter { $0.kind == "temporary_leave" }) { day in
                    HStack {
                        Text(day.businessDate ?? "")
                            .font(.body)
                        Spacer()
                        Text("临时")
                            .font(.caption)
                            .foregroundStyle(Color.tertiaryText)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Swift.Task { try? await vm.deleteLeaveDay(day.id) }
                        } label: { Label("删除", systemImage: "trash") }
                    }
                }
            }
            Section {
                Button { showAddSheet = true } label: {
                    Label("新增休息日", systemImage: "plus")
                        .foregroundStyle(Color.forest)
                }
            }
        }
        .navigationTitle("休息日配置")
        .sheet(isPresented: $showAddSheet) {
            AddLeaveDaySheet(vm: vm)
        }
    }

    private func weekdayName(_ n: Int) -> String {
        ["日","一","二","三","四","五","六","日"]
        .indices.contains(n == 7 ? 0 : n) ? "周" + ["日","一","二","三","四","五","六"][n == 7 ? 0 : n] : "未知"
    }
}

private struct AddLeaveDaySheet: View {
    @Bindable var vm: ProfileViewModel
    @State private var mode: String = "weekly_rest"
    @State private var weekday: Int = 7
    @State private var date = Date()
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("类型", selection: $mode) {
                    Text("每周固定休息日").tag("weekly_rest")
                    Text("临时休息日").tag("temporary_leave")
                }
                .pickerStyle(.segmented)

                if mode == "weekly_rest" {
                    Picker("星期", selection: $weekday) {
                        ForEach(1...7, id: \.self) { d in
                            Text("周" + ["一","二","三","四","五","六","日"][d-1]).tag(d)
                        }
                    }
                } else {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
            }
            .navigationTitle("新增休息日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        Swift.Task {
            isSaving = true
            do {
                if mode == "weekly_rest" {
                    try await vm.addLeaveDay(kind: mode, businessDate: nil, weekday: weekday)
                } else {
                    let str = dateString(date)
                    try await vm.addLeaveDay(kind: mode, businessDate: str, weekday: nil)
                }
                dismiss()
            } catch { Haptics.error() }
            isSaving = false
        }
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: d)
    }
}

// MARK: - 占位：重复计划 & 课表管理（阶段三实现）
struct PlanManagementView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48)).foregroundStyle(Color.tertiaryText)
            Text("重复计划").font(.body).foregroundStyle(Color.secondaryText)
            Text("将在阶段三随排程系统一起上线").font(.caption).foregroundStyle(Color.tertiaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas)
        .navigationTitle("重复计划")
    }
}

struct TimetableEditorView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "square.grid.3x3.fill.square")
                .font(.system(size: 48)).foregroundStyle(Color.tertiaryText)
            Text("课表可视化编辑器").font(.body).foregroundStyle(Color.secondaryText)
            Text("核心模块，将在阶段三重点开发").font(.caption).foregroundStyle(Color.tertiaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas)
        .navigationTitle("课表管理")
    }
}
