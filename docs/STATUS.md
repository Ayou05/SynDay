# SynDay 实施状态

最后更新：2026-06-23

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
- 纳入新版远期完整白皮书，补齐情侣 IM、备考社区、完整数据看板和长期数据模型。
- 建立当前投用版与完整终态的范围矩阵，并裁决与既有决定的冲突。
- 建立 `docs/HANDOFF.md` 跨 Agent 交接板。
- 收紧 host 网络下的 API 监听地址，统一 Go 1.25 构建链。
- 修复六位绑定码碰撞与多行认领风险。
- 新增随机实时频道 capability，避免通过用户 UUID 猜测私人频道。
- 完成第一轮正式移动端视觉重构：Apple 结构语法、SynDay 暮色绿、浮动磨砂底栏与线性图标。
- 新增带数据库锁和校验和账本的迁移命令；第 6 迁移受当前沙箱 DNS 限制尚未写入 Supabase。
- 2026-06-23 最终复验：Go test/vet、Vite 生产构建、Cargo check/clippy、iOS AppIcon/XML、离线 npm 安装计划、Android AAPT2 资源编译与 `git diff --check` 全部通过。
- 移除运行时第三方 CDN JavaScript，前台实时动态改为 12 秒持久通知补拉，避免供应链与商店审核风险。
- 增加 Supabase transaction pooler 的 simple protocol 与连接池边界配置，并补充仓储配置测试。
- 增加 `/readyz` 生产能力探针与公网检查脚本。
- 双端最低版本统一为 iOS 15 / Android 26；iPhone、iPad 方向配置已在生成源和生成物中统一。
- macOS Tauri 调试 App 已成功打包，五类通知音效已验证进入 bundle 资源根目录。
- DeepSeek V4 Flash 复盘请求启用官方 JSON Output，激励与复盘继续显式关闭思考模式以控制等待时间。
- 修复历史日期空复盘标题、剪贴板失败提示和设置页快速提交竞态。
- 修复专注每秒刷新与通知轮询整页重绘导致表单输入丢失的问题，并统一月历按北京时间计算星期。
- 清理 iOS AppIcon alpha 通道并补齐双端品牌启动屏；XML 静态校验通过，ibtool 动态编译仍受当前 CoreSimulator 环境阻塞。
- 将 Web、Rust、Tauri、iOS 与 Android 产品版本统一为 `1.0.0`。
- 将前端 `latest` 依赖改为 lockfile 对应的精确版本，离线 `npm ci --dry-run` 通过。
- 修复产品样式层覆盖暗色模式文字 token 的问题，补齐暗色空状态与导航对比度。
- 修复 iOS 调用 Android 通知频道接口与自定义声音缺少扩展名的问题，并接入本地通知点击路由。
- 统一登录后与冷启动的会话初始化，并增加 APNs token 原生缓存/主动补读，避免首次注册事件早于 WebView 监听。
- 增加未登录绑定深链接暂存与登录后续接，避免扫码唤起后因认证流程丢失 token。
- 第 6 迁移收紧系统级 `SECURITY DEFINER` 函数执行权限，阻断 Supabase 客户端 RPC 越权面。
- 修复连胜通知错误复用伴侣动态开关的问题，服务端按通知类型读取独立偏好。
- 增加 APNs development/production endpoint 配置与测试，当前开发签名默认走 sandbox。
- 修复设备 token 双唯一约束下的登记冲突，兼容设备 ID 重建与推送 token 轮换。
- 退出登录新增设备推送注销与本地定时提醒清理，降低共享设备上的隐私残留。

- 2026-06-23 接手审计：备份代码，完成白皮书 vs 代码差异分析（docs/GAP_ANALYSIS.md）。
- 2026-06-23 提交 80 个未提交文件到 Git（commit 5906009）。
- 2026-06-23 前端生产配置 frontend/.env.production 创建完成，Vite 生产构建通过。
- 2026-06-23 Go 后端测试全通过，Linux amd64 交叉编译二进制成功（/tmp/synday-api-linux-amd64, 17MB）。
- 2026-06-23 确认外部资源全部就绪：Supabase 可达、GoEasy 可达、DeepSeek 可达、API 域名已解析、API /healthz 返回 OK。
- 2026-06-23 确认服务器 API 版本偏旧（/readyz 返回 404），需要重新部署。

## 进行中

- 需要服务器 SSH 访问权限以部署最新 API 二进制（当前服务器运行旧版，无 /readyz 端点）。
- 需要在 Supabase SQL Editor 手动执行迁移 006（本地 DNS 无法解析 Supabase DB 直连地址）。
- 验证 Android debug APK 构建。
- 验证 iOS Xcode 无签名/真机编译链路。
- 完成全页面视觉检查和细节迭代。
- 补齐 Android FCM/OPPO 设备令牌获取和 OPPO PUSH 适配器（需真实平台项目与应用凭据）。

## 外部待办

- [ ] 购买腾讯云香港 2C2G Ubuntu 24.04 服务器
- [x] 创建 Supabase 新加坡项目：`abuhrrrqvpivzdvwkmik`
- [x] 注册并配置 GoEasy 本地生产参数；待公网联调
- [ ] 注册 OPPO 开放平台
- [x] 配置 DeepSeek API Key；待公网延迟与降级联调
- [ ] 将 `api.synday.catclaw.cloud` 指向服务器

## 已知问题

- 当前 `xcrun simctl` 无法连接 CoreSimulatorService；先使用 iOS 真机验收，稍后修复模拟器。
- Android 构建已进入 `aarch64-linux-android` Rust 编译，因沙箱无法解析 `static.crates.io` 而无法下载目标依赖。
- iOS release/arm64/no-sign 构建入口已统一；Tauri CLI 因沙箱无法连接 CoreSimulatorService 停在 `xcrun simctl list runtimes --json` 预检，尚未进入项目编译。
- 本地 Vite 监听和 Playwright Chromium 启动受沙箱权限限制，尚未完成自动化视觉截图验收。
- 工具链环境变量通过 `scripts/dev-env.sh` 加载，尚未写入用户全局 shell。
- Supabase、DeepSeek、GoEasy 的本地生产参数已存在于 Git 忽略文件；当前沙箱 DNS 无法访问公网，因此仍未完成真实服务往返验证。
- OPPO、FCM 与 APNs 生产凭据/项目配置仍不完整，后台推送与双机验收必须在平台项目准备后继续。
- GitHub App 写分支被 403 拒绝；但本地 Git 提交已完成（5906009），CI 文件已包含在提交中。
