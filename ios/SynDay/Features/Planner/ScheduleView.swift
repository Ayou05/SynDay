import SwiftUI

struct ScheduleView: View {
    @State private var vm = ScheduleViewModel()
    @State private var showAddSheet = false
    @State private var selectedTask: Task?
    @State private var refreshTimer: Timer?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        if let error = vm.error {
                            ErrorBanner(message: error)
                        }

                        ScheduleHeader(summary: vm.summary)

                        if let agent = vm.agentCard {
                            AgentCard(agent: agent, vm: vm)
                        }

                        if vm.tasks.isEmpty && !vm.isLoading {
                            EmptyState(icon: "calendar.badge.plus",
                                       title: "今天还没有安排任务",
                                       subtitle: "加一个开始今天的节奏",
                                       actionTitle: "新增任务") { showAddSheet = true }
                                .padding(.top, Spacing.xxl)
                        } else {
                            TaskTimelineList(tasks: vm.tasks,
                                             onComplete: { task in Swift.Task { await vm.completeTask(task) } },
                                             onTogglePin: { task in Swift.Task { await vm.togglePin(task) } },
                                             onDelete: { task in Swift.Task { await vm.deleteTask(task) } },
                                             onComment: { _ in /* 阶段二：评论入口 */ },
                                             onTap: { selectedTask = $0 })
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, 100)
                }
                .background(Color.canvas)

                AddTaskButton { showAddSheet = true }
                    .padding(.trailing, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
            }
            .navigationTitle("今天")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await vm.load() }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showAddSheet) {
            AddTaskSheet { title, category, time, pinned in
                showAddSheet = false
                Swift.Task { await vm.createTask(title: title, category: category, plannedTime: time, isPinned: pinned) }
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskActionSheet(task: task,
                            onStart: { /* TODO: 跳专注页预填任务 */ },
                            onTogglePin: { Swift.Task { await vm.togglePin(task) } },
                            onEdit: { /* TODO: 编辑任务 */ },
                            onDelete: { Swift.Task { await vm.deleteTask(task) } })
        }
        .onAppear { startRefreshTimer() }
        .onDisappear { refreshTimer?.invalidate() }
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            vm.refreshAgentCard()
        }
    }
}

// MARK: - 顶部头部
private struct ScheduleHeader: View {
    let summary: TodaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(businessDateDisplay(summary.businessDate))
                .font(.subhead)
                .foregroundStyle(Color.tertiaryText)
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(summary.completionPercent)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.forest)
                    Text("完成率")
                        .font(.label)
                        .foregroundStyle(Color.tertiaryText)
                }
                Divider().background(Color.hairline).frame(height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.orange)
                        Text("\(summary.currentStreak)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.orange)
                    }
                    Text("连续天数")
                        .font(.label)
                        .foregroundStyle(Color.tertiaryText)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.surfaceSoft)
        .cornerRadius(CornerRadius.lg)
        .cardElevation()
    }

    private func businessDateDisplay(_ s: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        guard let d = f.date(from: s) else { return s }
        let out = DateFormatter()
        out.locale = Locale(identifier: "zh_CN")
        out.dateFormat = "yyyy年M月d日 EEEE"
        return out.string(from: d)
    }
}

// MARK: - Agent 卡片
private struct AgentCard: View {
    let agent: AgentCardState
    @Bindable var vm: ScheduleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.forest)
                Text("AI 提示")
                    .font(.caption)
                    .foregroundStyle(Color.forest)
                Spacer()
            }
            Text(agent.text)
                .font(.body)
                .foregroundStyle(Color.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if let task = agent.task {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                    Text(task.title)
                        .font(.subhead)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                }
            }
            if let remaining = agent.remainingMinutes {
                Text("剩余可用 \(remaining) 分钟")
                    .font(.caption)
                    .foregroundStyle(Color.tertiaryText)
            }

            HStack(spacing: Spacing.sm) {
                ForEach(agent.scenario.options) { option in
                    AgentOptionButton(option: option) {
                        handleOption(option)
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.forest.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: CornerRadius.lg).stroke(Color.forest.opacity(0.15), lineWidth: 0.5))
        .cornerRadius(CornerRadius.lg)
    }

    private func handleOption(_ option: AgentOption) {
        Haptics.selectionChanged()
        switch option {
        case .startFocus:
            // TODO: 跳转专注页预填任务
            break
        default:
            break
        }
    }
}

private struct AgentOptionButton: View {
    let option: AgentOption
    let action: () -> Void
    @State private var isSelected = false

    var body: some View {
        Button(action: { isSelected.toggle(); action() }) {
            Text(option.rawValue)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.white : Color.forest)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? Color.forest : Color.canvas)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.sm).stroke(Color.forest.opacity(0.3), lineWidth: 0.5))
                .cornerRadius(CornerRadius.sm)
        }
    }
}

// MARK: - 任务时间轴
private struct TaskTimelineList: View {
    let tasks: [Task]
    let onComplete: (Task) -> Void
    let onTogglePin: (Task) -> Void
    let onDelete: (Task) -> Void
    let onComment: (Task) -> Void
    let onTap: (Task) -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(tasks) { task in
                TaskCard(task: task,
                         onComplete: { onComplete(task) },
                         onComment: { onComment(task) },
                         onTap: { onTap(task) })
            }
        }
    }
}

// MARK: - 任务卡片（五态）
private struct TaskCard: View {
    let task: Task
    let onComplete: () -> Void
    let onComment: () -> Void
    let onTap: () -> Void

    private var isCourse: Bool { task.category == .course }
    private var isCompleted: Bool { task.status == .completed }
    private var isExpired: Bool { task.status == .expired }
    private var isPending: Bool { task.status == .pending }

    var body: some View {
        HStack(spacing: Spacing.md) {
            bar

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text(timeDisplay)
                        .font(.caption)
                        .foregroundStyle(isCompleted || isExpired ? Color.tertiaryText : Color.secondaryText)
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.forest)
                    }
                    if isExpired {
                        Text("已作废")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(CornerRadius.xs)
                    }
                }
                Text(task.title)
                    .font(.body)
                    .strikethrough(isCompleted || isExpired)
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                if task.isPinned && isPending {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                        Text("置顶")
                            .font(.label)
                    }
                    .foregroundStyle(Color.forest)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 1)
                    .background(Color.forest.opacity(0.1))
                    .cornerRadius(CornerRadius.xs)
                }
            }
            Spacer()

            trailingAction
        }
        .padding(Spacing.md)
        .background(cardBackground)
        .overlay(cardBorder)
        .cornerRadius(CornerRadius.md)
        .cardElevation()
        .contentShape(Rectangle())
        .onTapGesture {
            if isPending { onTap() }
        }
    }

    @ViewBuilder
    private var bar: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(width: isPending && !isCourse ? 4 : 3, height: 44)
    }

    private var barColor: Color {
        if isCompleted || isExpired { return .surfaceStrong }
        if isCourse { return .surfaceStrong }
        return .forest
    }

    private var titleColor: Color {
        if isCompleted || isExpired { return .tertiaryText }
        if isCourse { return .secondaryText }
        return .ink
    }

    private var cardBackground: Color {
        if isCourse || isExpired { return .surfaceSoft }
        if isCompleted { return .surfaceSoft.opacity(0.7) }
        return .canvas
    }

    private var cardBorder: some View {
        Group {
            if isPending && !isCourse {
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(Color.hairline, lineWidth: 0.5)
            } else {
                Color.clear
            }
        }
    }

    private var timeDisplay: String {
        task.plannedTime ?? "全天"
    }

    @ViewBuilder
    private var trailingAction: some View {
        if isPending && !isCourse {
            Button(action: onComplete) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.forest)
                    .clipShape(Circle())
                    .shadow(color: Color.forest.opacity(0.3), radius: 3, y: 1)
            }
        } else if isExpired {
            Button(action: onComment) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.tertiaryText)
                    .frame(width: 32, height: 32)
            }
        }
    }
}

// MARK: - 悬浮新增按钮
private struct AddTaskButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.forest)
                .clipShape(Circle())
                .floatingElevation()
        }
    }
}

// MARK: - 新增任务 Sheet
private struct AddTaskSheet: View {
    @State private var title = ""
    @State private var category: TaskCategory = .selfStudy
    @State private var time = Date()
    @State private var duration: Int = 60
    @State private var customDuration = false
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String, TaskCategory, String?, Bool) -> Void

    private let durations = [30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            Form {
                Section("任务标题") {
                    TextField("输入任务名称", text: $title)
                }
                Section("分类") {
                    Picker("分类", selection: $category) {
                        Text("课程").tag(TaskCategory.course)
                        Text("自主").tag(TaskCategory.selfStudy)
                        Text("临时").tag(TaskCategory.temporary)
                    }
                    .pickerStyle(.segmented)
                }
                Section("计划时间") {
                    DatePicker("时间", selection: $time, displayedComponents: .hourAndMinute)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
                Section("预计时长") {
                    Picker("时长", selection: $duration) {
                        ForEach(durations, id: \.self) { d in Text("\(d)min").tag(d) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Button {
                        save()
                    } label: {
                        Text("添加任务")
                            .font(.h3)
                            .foregroundStyle(Color.forest)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .navigationTitle("新增任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }

    private func save() {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        onAdd(title.trimmingCharacters(in: .whitespaces), category, f.string(from: time), false)
    }
}

// MARK: - 任务操作 ActionSheet
private struct TaskActionSheet: View {
    let task: Task
    let onStart: () -> Void
    let onTogglePin: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(task.title) {
                    Button { onStart(); dismiss() } label: {
                        Label("开始专注计时", systemImage: "play.fill").foregroundStyle(Color.forest)
                    }
                    Button { onTogglePin(); dismiss() } label: {
                        Label(task.isPinned ? "取消置顶" : "置顶", systemImage: "pin.fill")
                    }
                    Button { onEdit(); dismiss() } label: {
                        Label("编辑任务", systemImage: "pencil")
                    }
                    Button(role: .destructive) { onDelete(); dismiss() } label: {
                        Label("删除任务", systemImage: "trash")
                    }
                }
                Section { Button("取消") { dismiss() } }
            }
            .navigationTitle("任务操作")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(360)])
    }
}
