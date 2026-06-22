# SynDay 实施状态

最后更新：2026-06-22

## 当前阶段

上线前审计、双端原生构建验证与外部资源联调准备。

## 已完成

- 完整阅读 V1.0 PRD。
- 完成产品、技术、发布、隐私和交互细节对齐。
- 初始化空 Git 仓库和项目目录。
- 安装 Go。
- 安装 Rustup。
- 安装 Rust 1.96.0 与 iOS/Android 编译 targets。
- 安装 CocoaPods。
- 确认 Node、npm、Xcode、Android SDK 可用。
- 安装 Android NDK 29.0.14206865。
- 创建 Go API、北京时间 04:00 日切和初始 Supabase 数据模型。
- Go 单元测试通过。
- 初始化 Tauri 2 工程，前端生产构建通过。
- 生成 iOS Xcode 工程与 Android Gradle 工程。
- Tauri Rust 原生检查通过。
- 实现邮箱密码认证客户端、真实 API 客户端与会话持久化。
- 实现任务列表、新增、完成/撤销、置顶和离线操作队列。
- 实现正计时、倒计时、60 秒有效门槛的前端流程。
- 实现重复计划、情侣绑定、共享专注、复盘、通知和设置的后端 API/仓储层。
- 实现 AI 激励预取与复盘增强服务。
- 实现 APNs 发送器、GoEasy 发布器和持久化通知补拉。
- 实现 FCM HTTP v1 备用推送发送器和 Android 通知通道映射。
- 实现 iOS APNs 设备令牌桥接和客户端设备登记。
- 实现服务端倒计时自动完成、活跃专注恢复与伴侣中途加入。
- 实现 30/100/365 天连胜里程碑与通知。
- 实现二维码相机扫描、深链接、通知收件箱和账户删除二次认证。
- 生成五类通知音效并配置到 iOS/Android 原生资源。
- 新增数据库策略约束迁移。
- 完成隐私边界文档和逐项 V1 验收清单。
- 修正情侣月报跨月边界为北京时间。
- 将请假策略和绑定冲突映射为可识别业务错误。
- 修正个人/相伴连胜的休息日保护语义，并为 DeepSeek Flash 显式关闭思考模式。
- 2026-06-22 复验：Go 测试、Vite 生产构建、Cargo check、`git diff --check` 全部通过。

## 进行中

- 验证 Android debug APK 构建。
- 验证 iOS Xcode 无签名/真机编译链路。
- 审计 SQL 迁移、通知、删除流程与原生配置。
- 补齐 Android FCM/OPPO 设备令牌获取和 OPPO PUSH 适配器（需真实平台项目与应用凭据）。

## 外部待办

- [ ] 购买腾讯云香港 2C2G Ubuntu 24.04 服务器
- [x] 创建 Supabase 新加坡项目：`abuhrrrqvpivzdvwkmik`
- [ ] 注册 GoEasy
- [ ] 注册 OPPO 开放平台
- [ ] 准备 DeepSeek API Key
- [ ] 将 `api.synday.catclaw.cloud` 指向服务器

## 已知问题

- 当前 `xcrun simctl` 无法连接 CoreSimulatorService；先使用 iOS 真机验收，稍后修复模拟器。
- Android 构建已进入 `aarch64-linux-android` Rust 编译，因沙箱无法解析 `static.crates.io` 而无法下载目标依赖。
- iOS Tauri CLI 因沙箱无法连接 CoreSimulatorService 停在运行时预检；离线 target 检查还缺少 `async-broadcast 0.7.2`。
- 本地 Vite 监听和 Playwright Chromium 启动受沙箱权限限制，尚未完成自动化视觉截图验收。
- 工具链环境变量通过 `scripts/dev-env.sh` 加载，尚未写入用户全局 shell。
- Supabase、GoEasy、OPPO 和服务器凭据尚未创建，因此当前只能完成本地编译和无外部凭据测试。
