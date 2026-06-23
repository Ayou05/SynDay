# SynDay 白皮书 vs 代码差异分析

> 生成时间：2026-06-23
> 原则：以已落成代码的选型和技术路线为准，白皮书定义完整终态。

## 一、已完成且有对应代码的模块

| 白皮书章节 | 代码实现 | 状态 |
|---|---|---|
| 1.1 自然日 04:00 日切 | timeutil/business_day.go + scheduler 0 4 * * * | 完成 |
| 1.2 任务生命周期 | repository/tasks.go + model/task.go | 完成 |
| 1.3 推送分级 | APNs/FCM/OPPO + 本地通知 + 通知开关 | 完成 |
| 1.5 异常处理 | 离线队列 sync.js + IndexedDB + writeRepositoryError | 完成 |
| 1.6 AI 文案约束 | ai/client.go + service/ai_service.go | 完成 |
| 2.1 今日待办 | httpapi/router.go today + main.js 渲染 | 完成 |
| 2.2 专注计时 | httpapi/shared_focus.go + repository/focus.go | 完成 |
| 2.3 AI 激励文案 | ai_service.go PrefetchEncouragements | 完成 |
| 2.4 每日复盘 | scheduler.go runReviewDrafts 23:30 + repository/reviews.go | 完成 |
| 2.5 连胜系统 | repository/jobs.go + model/settings.go | 完成 |
| 2.5.2 休息日 | 每周 1 天 + 每月 4 天临时（代码 4 天，白皮书 2 天） | 差异 |
| 2.6 月度日历 | httpapi/reviews.go calendar | 完成 |
| 3.1 情侣绑定 | repository/couple.go 6 位码 + 二维码 + 双方确认 | 完成 |
| 3.2 双向只读 | httpapi/couple.go partnerOverview | 完成 |
| 3.3 联机专注 | httpapi/shared_focus.go + repository/focus.go | 完成 |
| 3.5 情侣通知 | service/notification_service.go NotifyPartner | 完成 |
| 3.6 双轨连胜 | personal_streaks + couple_streaks | 完成 |
| 3.7 月度情侣简报 | scheduler.go runPreviousMonthReport | 完成 |
| 3.8 隐私边界 | RLS 策略 + 复盘不可见 | 完成 |
| 5 推送总表 | 5 类通知 + 独立开关 | 完成 |
| 6 页面清单 | 页面 1-6, 11 已实现 | 部分 |

## 二、白皮书有但代码未实现的模块（远期终态）

| 白皮书章节 | 模块 | 说明 |
|---|---|---|
| 2.7 全周期数据看板 | 周/月/长期统计图表 | 无后端 API，无前端页面 |
| 3.4 情侣 1v1 IM | GoEasy WebSocket 实时聊天 | 无 IM 会话/消息表，无前端聊天页 |
| 4 朋友圈社区 | 动态发布/信息流/关注/评论/点赞 | 无任何社区代码 |
| 6.7 情侣 IM 私聊页 | 聊天 UI | 依赖 3.4 |
| 6.8 社区首页 | 信息流 | 依赖第四部分 |
| 6.9 个人动态主页 | 历史动态 | 依赖第四部分 |
| 6.10 社区通知页 | 点赞/评论/@ | 依赖第四部分 |

## 三、代码与白皮书的选型差异（以代码为准）

| 项目 | 白皮书 | 代码实际 | 决策原因 |
|---|---|---|---|
| 临时请假天数 | 每月最多 2 天 | 每月最多 4 天 | Codex 协商结果，更灵活 |
| 连续休息日限制 | 禁止连续 2 天 | 最多连续 2 天 | 代码允许连续 2 天 |
| GoEasy 使用方式 | WebSocket 长连接 | 降级为 12s 轮询 | CDN 脚本被移除，待固定为本地依赖 |
| 免打扰模式 | 计时自动开启全局免打扰 | 未实现 | Tauri 2 限制，需原生插件 |

## 四、推进优先级

### P0 — 立即执行
- [ ] 提交 80 个未提交文件到 Git
- [ ] 执行 Supabase 迁移 006
- [ ] 创建 frontend/.env.production
- [ ] 构建并部署最新 API 到服务器

### P1 — 本轮或下一轮
- [ ] Android debug APK 构建验证
- [ ] 恢复 GoEasy WebSocket（本地依赖替代 CDN）
- [ ] 全页面视觉检查
- [ ] iOS 无签名构建验证

### P2 — 远期
- [ ] 数据看板（单人）
- [ ] 情侣 IM
- [ ] 朋友圈社区
