# SynDay 朝夕同序 — V2 实施方案（权威参考）

> 最后更新：2026-06-24
> 本文档是后续所有开发的最高参考。上下文丢失/换 Agent/遗忘时，先读 DECISIONS.md → 再读本文档 → 再读交互规格。
> 需求冲突时的优先级：本文档 > 交互规格文档 > FUTURE_PRODUCT_WHITEPAPER.md > 历史聊天记录。

---

## 一、产品定位（一句话）

**一对一私密状态同步系统 + 情侣陪伴学习工具。**
核心痛点解决：图书馆/自习时不想开微信，但需要让对方实时知道你在干嘛。备考是当下业务载体，未来可替换为论文/工作/作息。

## 二、已敲定的关键产品决策

| 编号 | 决策 | 备注 |
|---|---|---|
| D1 | 双核心对等+Bridge架构 | study_core / couple_core 平级，bridge层唯一互通 |
| D2 | iOS原生SwiftUI，Android保留Tauri+Vanilla JS（视觉对齐SwiftUI风格） | OPPO PUSH彻底放弃（个人开发者不可用），Android走GoEasy长连接+本地通知 |
| D3 | 04:00北京时间日切，23:30默认复盘/PK结算，可自定义就寝提醒时间 | 跨零点到4点的专注归属前一天 |
| D4 | 不做语音/视频IM | 服务器2C2G撑不住，也非刚需；文字+图片即可（七牛云存图） |
| D5 | 可视化课表编辑器（对标Wakeup）前期必须落地，不降级为文本导入 | 这是核心差异化，分多档案（本校/机构A/B）、支持单双周、学期起止、拖拽拆分合并 |
| D6 | LLM双方案排程（均衡/极速）+ 首页Agent温情卡片 | 文案层LLM自由（≤2-3行克制短句），业务层规则锁死，三道安全防线 |
| D7 | 所有任务支持朋友圈式多轮评论，不只是作废任务 | 23:30合并为一条推送，"你有N条新留言"，不展示正文 |
| D8 | 日/周/月三级PK，✅/⚪胜负标识，休息日不计入 | 周PK周日23:30，月PK月末23:30 |
| D9 | 休息日额度收紧：每周1天固定休息日，每月最多2天临时休息日，禁止连续两天休息 | 修正原代码的月4天+连续2天宽松策略 |
| D10 | 半自动状态：高德定时定位→场所标签匹配，可手动覆盖锁定，离开场所恢复自动；一键关定位隐私 | 状态：学习/休息/吃饭/路上/外出，配模糊场所标签（图书馆/宿舍/食堂/教学楼/校外），不用精准GPS |
| D11 | 专注结束极简两档打分（状态不错/状态一般，可跳过），数据用于LLM后续优化排程 | |
| D12 | 复盘双版本：App内展示详细可编辑版（四段式），隐藏一键复制精简提交版（机构打卡用） | 23:30自动生成草稿，机构模式强通知/普通模式弱提醒 |
| D13 | GoEasy WebSocket本地npm依赖，不走CDN，不用降级轮询 | CDN脚本有商店审核和供应链风险 |
| D14 | 连续打卡streak：靠休息日豁免保连胜，不用冻结令牌道具；里程碑30/100/365天开App弹一次极简卡片 | 无凌晨3点兜底推送，只就寝前1小时弱横幅+23:30复盘通知内带风险小字 |
| D15 | 个人连胜规则：完成≥1条任务OR产生≥60秒有效专注即算打卡；情侣连胜：任一方非休息日有有效学习记录即+1 | |
| D16 | 解绑后IM只读存档，不删除；账号注销7天冷静期 | |
| D17 | 无表情、无语音、无视频、无表情包键盘、无商城/付费/会员/广告/陌生人社交 | 纯净双人工具 |
| D18 | 评论/系统消息合并推送：白天逐条，当日所有留言23:30合并为1条 | 课程/任务/专注相关推送独立逐条下发 |
| D19 | AI默认DeepSeek v4-flash，低延迟优先，显式关闭thinking模式 | 所有AI文案/排程prompt写死system prompt防越权 |

## 三、技术架构

### 3.1 后端目录重构（Go）

从当前扁平 `internal/` 重组为：

```
backend/
├── cmd/
│   ├── api/            # API入口
│   └── migrate/        # 迁移工具
├── core/               # L0 内核（禁改业务逻辑，只修bug）
│   ├── time_engine/    # 04:00日切、业务日计算
│   ├── push_service/   # 统一推送调度（APNs/FCM/GoEasy/本地）
│   ├── ai_generator/   # DeepSeek客户端+prompt模板+文案约束
│   └── base_db/        # 通用repository基类、错误、事务
├── features/
│   ├── study_core/     # L1 单人学习模块
│   │   ├── tasks/      # 今日任务、模板、完成/作废
│   │   ├── focus/      # 单人专注计时
│   │   ├── planner/    # 课表、刚性事件、LLM排程、Agent卡片
│   │   ├── review/     # 每日复盘（详细+精简）
│   │   ├── streak/     # 个人连胜、PK统计
│   │   ├── calendar/   # 月历三色、历史数据
│   │   └── settings/   # 个人设置、休息日、AI偏好
│   ├── couple_core/    # L1 情侣陪伴模块
│   │   ├── binding/    # 绑定/解绑/二维码/6位码/双方确认
│   │   ├── im/         # 1v1聊天、消息持久化、已读回执、系统事件
│   │   ├── shared_focus/ # 联机专注房间
│   │   ├── couple_streak/ # 情侣连胜、月报
│   │   ├── comments/   # 任务评论区（朋友圈式多轮留言）
│   │   └── status/     # 半自动状态上报、位置标签、实时广播
│   └── future/         # L3 预留：相册、共享白板、社区
├── bridge/             # L2 桥接层（唯一允许双核心互通的地方）
│   ├── events.go       # 事件订阅/发布（study完成→IM系统消息 等）
│   ├── readonly.go     # 双向只读数据路由（伴侣看对方学习数据）
│   └── perms.go        # 权限校验
├── internal/
│   ├── auth/           # Supabase JWT验证（保留）
│   ├── config/         # 配置加载
│   ├── httpapi/        # HTTP路由层（按模块拆handler）
│   ├── repository/     # 数据访问层（按模块拆）
│   ├── realtime/       # GoEasy发布器
│   ├── push/           # APNs/FCM适配器（OPPO放弃）
│   └── model/          # 数据模型
└── migrations/         # SQL迁移（继续用递增编号）
```

**硬约束**：
- study_core 内禁止 import couple_core 的任何包
- couple_core 只能通过 bridge 订阅 study_core 的事件，不能直连study内部
- bridge 只做事件转发/格式化/权限校验，不写业务逻辑，不调用AI

### 3.2 iOS前端（SwiftUI 新工程）

```
ios/SynDay/
├── App/
│   ├── SynDayApp.swift
│   └── AppTheme.swift       # 设计token（暮色绿、字体、间距、圆角）
├── Core/
│   ├── APIClient.swift      # REST API封装（底层URLSession）
│   ├── AuthManager.swift    # Supabase Auth会话
│   ├── WebSocketManager.swift # GoEasy连接/重连/订阅
│   ├── OfflineQueue.swift   # 操作队列+指数退避
│   ├── CacheStore.swift     # 本地缓存（UserDefaults+SQLite via GRDB）
│   └── LLMProxy.swift       # AI文案本地兜底+远程调用
├── Features/
│   ├── Focus/               # Tab1 专注
│   ├── Couple/              # Tab2 情侣状态+月报+邀请
│   ├── Planner/             # Tab3 排程（C位）
│   │   ├── TimetableEditor/ # 课表可视化编辑器（单独子目录）
│   │   └── AgentCard/       # 首页LLM温情卡片
│   ├── Chat/                # Tab4 IM
│   └── Profile/             # Tab5 我的+设置+日历+复盘
├── Shared/
│   ├── Components/          # 按钮、卡片、Toast、Sheet、EmptyState
│   ├── Design/              # Color+Font+Spacing扩展
│   └── Haptics/             # 震动反馈封装
└── Resources/
    ├── Assets.xcassets
    └── Sounds/              # 5类通知音效
```

- 最低部署目标 iOS 17（用Observation、SwiftData/GRDB）
- 全部 `@Observable` ViewModel，不引入Combine
- 网络层用原生URLSession，不引入Alamofire
- 数据库用GRDB.sqlite（轻量、Swifty），CoreData过重
- 图片缓存用Nuke

### 3.3 Android前端（保留Tauri+Vanilla JS，视觉重做）

现有 `frontend/` 目录保留，但：
- 视觉样式全面对齐SwiftUI版本（同款暮色绿、同款17px正文、同款12pt圆角、同款卡片结构）
- 用轻量组件化改造（ES Module + 原生Custom Elements或preact/htm，3KB）
- 12秒轮询改回GoEasy WebSocket（npm本地依赖）
- 推送不用APNs/FCM/OPPO，全部依赖GoEasy在线推送+本地scheduled notifications兜底（Tauri notification插件）
- 保留Dexie离线队列、outbox模式

### 3.4 外部服务

| 服务 | 用途 | 状态 |
|---|---|---|
| Supabase（新加坡） | Auth + PostgreSQL + RLS | ✅ 已配置，需补新migration |
| GoEasy（杭州） | WebSocket实时通道、IM消息、状态广播、Android推送兜底 | ✅ 已有key，前端npm本地装SDK |
| DeepSeek v4-flash | AI激励文案、排程、Agent卡片、复盘生成 | ✅ 已有key |
| 七牛云Kodo | IM图片存储、未来相册 | ❌ 待注册（10GB免费） |
| 高德开放平台 | 定位+场所模糊匹配 | ✅ 已有key（待确认） |
| APNs | iOS推送 | ⚠️ p8证书待上传后端 |
| FCM | Android备用推送（若未来要做） | 暂缓，优先GoEasy |

## 四、分阶段实施路线

> 原则：每个阶段结束都是可用产品。3个月冻结期内只修bug不加新功能（阶段零之后）。

### 阶段零：基础设施对齐（1-2天，立刻做）
- [ ] 轮换所有已泄露密钥（DeepSeek、GoEasy Rest Key、DB密码），backend/.env加入.gitignore
- [ ] 部署最新API镜像到腾讯云（当前服务器版本过旧，无/readyz）
- [ ] 在Supabase执行migration 006
- [ ] 本地构建验证iOS debug、Android debug能出包
- [ ] 确认GoEasy npm包能集成进前端
- [ ] 注册七牛云，拿到Access Key

### 阶段一：iOS SwiftUI主链路（3-4周）
**目标**：iOS端SwiftUI重写出一个能独立使用的单人版，情侣功能在阶段二加。
- [ ] 新建Xcode工程，配置Signing & Capabilities（bundle ID: cloud.catclaw.synday, team: SXBSWNH85W）
- [ ] 搭建AppTheme设计token系统（颜色/字体/间距/圆角全部对齐交互文档）
- [ ] 实现APIClient + AuthManager + Supabase邮箱登录/注册页
- [ ] Tab5"我的"页（Profile）：资料卡、三列数据、设置分组、月历、复盘历史
- [ ] Tab1"专注"页：Idle/Focusing状态机、正/倒计时、打分弹窗、本地通知震动
- [ ] Tab3"排程"页（C位）：
  - 顶部完成率+连胜行
  - 今日任务时间轴（刚性/未开始/进行中/已完成/已作废五态卡片）
  - Agent卡片（准时/轻微迟到/严重超时三场景，先接本地兜底文案，LLM后接）
  - 悬浮新增按钮 + 新增任务Sheet + 任务ActionSheet
  - 下拉刷新、乐观更新、离线横幅
- [ ] 对接现有后端API（tasks/focus/plans/settings/reviews/notifications）
- [ ] 实现OfflineQueue+CacheStore，弱网场景能用
- [ ] 注册APNs token，后端接收设备token，通知分类音效配置
- [ ] 双人真机自测一轮，修bug

### 阶段二：情侣Core+IM+状态系统（3-4周）
**目标**：绑定、IM、状态上线，能替代微信日常使用。
- [ ] DB迁移新增表：`im_messages`, `im_conversations`, `task_comments`, `status_updates`, `status_locations`, `user_presence`, `qiniu_upload_tokens`
- [ ] 后端：couple_core/binding绑定确认流加固，接入WebSocket endpoint（通过GoEasy pubsub桥接）
- [ ] 后端：couple_core/im消息持久化、历史拉取、已读回执、系统事件生成
- [ ] 后端：couple_core/comments任务多轮评论
- [ ] 后端：couple_core/status状态上报接口（配高德反向地理编码，后端做场所模糊匹配）
- [ ] 后端：bridge层事件总线（study任务完成→IM系统消息、专注启停→IM、评论→通知聚合）
- [ ] 后端：日/周/月PK结算统计接口
- [ ] iOS Tab2"情侣"页：双人概览卡（头像+状态+双方完成率+相伴连胜）、对方今日待办只读、月度简报、邀请一起专注、未绑定态星图QR+6位码
- [ ] iOS Tab4"IM"页：消息气泡、系统事件胶囊、已读回执、输入框、分享卡片（今日待办/专注状态/复盘摘要）、顶部数据条、未读红点、离线发送队列
- [ ] iOS 通知点击路由（不同通知跳不同页）
- [ ] iOS 位置权限申请、前台30分钟/后台2小时定位、场所标签匹配、手动覆盖锁定、隐私开关
- [ ] 七牛云图片上传SDK接入（IM发图先传七牛拿URL再发消息）
- [ ] 情侣双人联调，真实用一周

### 阶段三：智能排程+可视化课表编辑器（5-7周，最大模块）
**目标**：核心差异化功能上线。
- [ ] DB迁移新增表：`timetable_profiles`（课表档案）、`timetable_cells`（课表单元格）、`schedule_events`（刚性事件实例）、`schedule_versions`（排程草稿/确认版本）、`schedule_tasks`（学习任务带planned_time/difficulty/plan_mode）、`schedule_adjustments`（调整日志后台留存）、`energy_preferences`（用户精力画像）
- [ ] 后端：planner模块——课表CRUD、多档案隔离、冲突检测、每日刚性事件推演
- [ ] 后端：LLM排程pipeline——空闲时间抽取→均衡/极速双方案JSON输出→放置理由→用户确认入库
- [ ] 后端：Agent卡片实时推理接口（当前任务+剩余时长→LLM温情文案+固定选项）
- [ ] 后端：当日状态反馈→LLM局部重排（微调/减负两模式）
- [ ] 后端：休息日规则收紧（月2天+禁连续2天）
- [ ] iOS 课表可视化编辑器（最复杂UI）：
  - 多档案切换（本校/机构A/机构B/...）
  - 周视图画布（纵向小节×横向周一到周日）
  - 拖拽创建/移动/拉伸课程块
  - 双指捏合/点击编辑拆分合并小节
  - 课程详情Sheet（名称、教室、老师、普通周/单周/双周、学期起止、颜色标签）
  - 冲突检测高亮
- [ ] iOS 排程草稿确认页（双方案左右/上下切换+放置理由+微调编辑+确认/推翻）
- [ ] iOS 当日状态反馈Sheet（四快捷标签+自由文本+微调/减负选项）
- [ ] iOS Agent卡片接通真实LLM，本地兜底文案
- [ ] LLM prompt工程+单元测试（mock场景检查输出结构）
- [ ] 单人联调排程准确性，再情侣联调

### 阶段四：补齐体验层+Android视觉对齐（2-3周）
- [ ] PK卡片（日/周/月，✅/⚪标识）
- [ ] 专注结束打分→LLM后续个性化
- [ ] 机构打卡模式（强通知+精简版复盘一键复制）
- [ ] 自定义提醒铃声（课程音/任务音）
- [ ] 任务置顶
- [ ] 月历三色视图（完成/未完成/休息）
- [ ] 历史复盘详情页（四段式详细版+可编辑+一键复制精简版）
- [ ] Android端Tauri版本视觉重构对齐SwiftUI（同款色板字号圆角卡片）
- [ ] Android端切回GoEasy WebSocket
- [ ] Android端本地通知兜底scheduling
- [ ] 双人真实使用2周，集中修bug
- [ ] 收紧通知频率，避免消息过载
- [ ] 暗色模式打磨、动态字体、无障碍标签

### 阶段五（远期，不阻塞V2）
- 共享白板（线下图书馆场景）
- 七牛相册+纪念日倒计时
- 复盘数据导出Markdown
- 朋友圈社区（在做好举报/拉黑/审核前**禁止**上线）
- 年度专属回顾页

### 上线后冻结期
阶段四结束即V2正式版，进入**3个月冻结期**：只修bug、调参数、优化文案，禁止新增任何业务功能。

## 五、需要补写的交互规格文档

在开始阶段一前，补齐以下详设文档（优先级从高到低）：

1. **《交互规格-登录与认证页》** — 邮箱注册/登录/忘记密码/深链接续接
2. **《交互规格-可视化课表编辑器》** — 阶段三核心，详设画布/手势/单元格/冲突UI
3. **《交互规格-状态与定位》** — 状态卡片、场所标签、手动锁定、隐私
4. **《交互规格-任务评论与互动》** — 评论入口、评论列表、输入框、新留言标记
5. **《交互规格-PK与连胜》** — 日/周/月PK卡片、里程碑弹窗、连胜冻结规则
6. **修正现有文档矛盾**：结算时间22:30→23:30统一，休息日额度收紧，OPPO PUSH删除，GoEasy改回WebSocket
7. **Android视觉差异说明** — Tauri版本如何用CSS还原SwiftUI组件

## 六、开发硬约束（写给未来AI/自己看）

1. **任何新功能先归类**：是study_core？couple_core？还是bridge？无法归类的不做。
2. **AI文案必须有本地兜底**：DeepSeek超时/失败/无网络时，显示预设短句库，绝不阻塞核心流程。
3. **LLM输出一律走JSON Schema校验**：排程、Agent、复盘都要有struct反序列化+字段校验，异常走fallback。
4. **禁止引入CDN第三方JS**：所有依赖npm装本地包，lockfile提交。
5. **每次改动必须能单模块独立测试**：改IM不影响专注，改排程不影响情侣。
6. **迁移永不改历史migration**：只加新编号SQL。
7. **密钥.env永不进Git**：.env.example放占位符。
8. **Vibe coding工作流**：单次AI生成限定作用域（"只改study_core/planner，不碰couple_core"），禁止让AI一次改多模块。
9. **非必要不加依赖**：iOS端优先原生框架，后端优先标准库，能自己写的不引第三方库。
10. **所有推送必须可分类关闭**：不做任何"关键警报"绕过静音。

## 七、验收标准（V2上线前必过）

- [ ] iOS真机TestFlight可安装，Android APK可安装
- [ ] 双机能稳定绑定、互发消息、看对方状态
- [ ] 断网10分钟内操作不丢失，恢复后自动同步
- [ ] 04:00日切逻辑连续3天无异常
- [ ] 23:30复盘自动生成、PK结算正确
- [ ] 课表排程能稳定生成合理日程，LLM JSON解析失败不崩溃
- [ ] 苹果TestFlight审核反馈无拒绝（隐私描述、定位权限文案、账号删除）
- [ ] Android不依赖Google Play Services也能跑（OPPO等国产机）
- [ ] 服务器内存占用<1.5G，响应P99<500ms
- [ ] 弱网（图书馆场景）下WebSocket断线重连无消息丢失
- [ ] 双人连续使用一周无数据错乱、无闪退

---

## 八、当前服务器/域名/账号速查表

| 项 | 值 |
|---|---|
| API域名 | https://api.synday.catclaw.cloud |
| 服务器 | 腾讯云香港 43.129.180.248（2C2G Ubuntu 24.04），IPv6 240d:c000:f000:9300:2846:e1c4:50e6:0 |
| SSH key | ~/.ssh/synday-deploy |
| Supabase项目 | abuhrrrqvpivzdvwkmik（新加坡）|
| GoEasy | 杭州区，AppKey BC-4f5ac2cd82fd4717b3ea5b1d035bb151 |
| 部署 | Docker host网络+Nginx HTTPS+Let's Encrypt自动续期 |
| GitHub | Ayou05/SynDay |

## 九、未决事项（未来决策点）

- 共享白板技术选型（CRDT还是简单last-write-wins）
- 相册是否需要人脸识别/自动分类（大概率不需要）
- iPad原生适配（暂时用iPhone缩放）
- macOS原生版本（可以用Catalyst一键带出来，优先级低）
- Widget/锁屏小组件（iOS 17+支持，体验提升但不阻塞主链路）
- Apple Watch伴侣应用（远期再议）

---

*本文档写完即冻结。后续所有产品决策变化，以新的"决策记录"追加到DECISIONS.md为准，不直接改本文件（保持时间线可追溯）。*
