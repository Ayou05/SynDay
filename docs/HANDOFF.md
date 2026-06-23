# SynDay Agent 交接板

最后更新：2026-06-23

## 当前目标

48 小时内交付可安装到 iPhone 17 Pro 与一加 Ace 5 的正式核心版。核心页面必须功能闭环、视觉完整，不放脚手架入口。

## 当前 Git 状态

- 分支：`main`
- 远端：`origin/main`
- 基线提交：`6c392d1`
- 当前未提交工作包含：新版白皮书/范围矩阵、UI 与原生资源精修、通知与登录生命周期修复、部署安全、迁移工具、配对码可靠性和实时频道 capability。
- 接手前先运行：`git status --short --branch`
- 不得覆盖其他 agent 的未提交改动。

## 已完成事实

- Go、Supabase 数据模型、Tauri 双端工程和核心业务页面已实现。
- Supabase、DeepSeek、GoEasy 的本地生产参数已配置，密钥文件被 Git 忽略。
- `./scripts/check.sh` 在 2026-06-23 最终复验通过，包含 Go test/vet、Vite build、Cargo check/clippy、iOS AppIcon alpha 与双端原生 XML 校验。
- iOS plist、entitlements 与 GitHub Actions YAML 也已通过语法校验。
- 最终交接快照额外通过离线 `npm ci --dry-run` 与 Android 全量资源 AAPT2 编译。
- Git 历史中未发现真实密钥。
- 新版终态产品文档已写入 `docs/FUTURE_PRODUCT_WHITEPAPER.md`。
- macOS 调试 App 已成功产出，可证明 Tauri 主机端完整打包链路可用；它不等同于 iOS/Android 真机产物。

## 本轮已完成

1. 生产 API 仅监听 loopback，避免 host 网络绕过 Nginx。
2. Go 工具链统一为 1.25。
3. 六位绑定码生成防碰撞，认领只锁定一条记录。
4. 新增不可猜测的 GoEasy 频道 capability；后续仍可升级为 GoEasy 官方 token 鉴权。
5. UI 基线已从 Airtable 切换为本地 Apple 设计规范的结构语法，并使用 SynDay 自有暮色绿色，不照搬 Apple 蓝。
6. `VITE_PREVIEW_MODE=true npm run build` 可生成带完整示例数据的视觉预览；预览模式不会启动离线同步。
7. 已移除运行时 GoEasy CDN 脚本；前台暂用 12 秒持久通知补拉。恢复 WebSocket 前必须把 SDK 固定为本地依赖。
8. 原生最低系统统一为 iOS 15 / Android 26；手机与 iPad 的生成源和生成物均已统一为竖屏。
9. 五类 iOS 通知音效已验证落在 App bundle 资源根目录，与 APNs `sound` 文件名匹配。
10. DeepSeek 当前正式 `deepseek-v4-flash` 已按官方接口显式关闭思考模式；每日复盘启用 `json_object` 输出，减少 JSON 解析降级。
11. 历史日期空复盘、剪贴板不可用、设置异步加载竞态均已有客户端降级处理。
12. `scripts/native-build.sh` 会先验证生产 API 与 Supabase 客户端参数，禁止生成回退到 localhost 的假成功安装包。
13. 专注计时改为局部 DOM 更新；通知/伴侣后台补拉在用户编辑表单时延迟重绘，避免输入内容被周期刷新清空。
14. iOS 全套 AppIcon 已移除 alpha 通道；iOS 与 Android 启动屏统一为暮色绿品牌过渡，不再使用默认白屏；Android 资源通过 AAPT2 编译。
15. 产品版本已统一为 `1.0.0`：iOS build `1`，Android versionCode `1000000`。
16. 若重生成图标，运行 `./scripts/prepare-ios-assets.sh`；它保留 Tauri RGBA 源图标，并把最终 Apple AppIcon 转为无 alpha RGB。
17. 前端依赖已由 `latest` 改为当前验证版本精确锁定；`npm ci --dry-run --offline` 通过。
18. 修复产品层覆盖暗色 token 的顺序问题；暗色文字、卡片、空状态与选中导航已重新校准。
19. 本地通知已按平台分流：Android 才创建频道，iOS 声音使用 `.wav` 文件名；点击本地通知会进入复盘/今日等对应页面。
20. 冷启动恢复与首次登录统一执行专注恢复、今日、设备 token、通知和实时初始化；iOS 原生层缓存 APNs token，JS 启动后主动补读，避免早到事件丢失。
21. 未登录时收到的情侣绑定深链接会本地暂存，登录成功后自动继续认领，不再丢失。
22. 2C2G 服务器上的 API 容器限制为 1 CPU / 512MB / 128 PIDs，并启用 10MB × 3 日志轮转。
23. 第 6 迁移撤销 `anon/authenticated/PUBLIC` 对全部系统级 `SECURITY DEFINER` 函数的执行权，避免客户端 RPC 越权调用账号删除、结算和生成任务。
24. 服务端伴侣动态与连胜里程碑分别读取 `notification_partner_enabled` / `notification_streak_enabled`，设置页四类通知开关不再串线。
25. APNs endpoint 按 `APNS_ENVIRONMENT` 分流；当前开发签名默认 sandbox，切 TestFlight 时必须同步改 production。
26. 设备 token 登记会原子清理同 token 与同设备/provider 的旧映射，兼容 App 数据清理和厂商 token 轮换。
27. 退出登录会先停用当前设备的服务端推送映射并取消本地定时提醒；网络失败不阻塞退出。

## 下一步命令

```bash
cd "/Users/kyleliao/Vibe-Coding/SynDay朝夕同序"
./scripts/check.sh
```

检查通过后：

1. 在可访问公网的终端执行 Supabase 第 6 个迁移；
2. 购买/初始化服务器，部署 API 并核验 `/healthz`、`/readyz`、`/v1/time`；
3. 在允许写 Git 的会话审查并提交当前完整工作区，触发双端 CI；
4. 生成 Android debug APK 与 iOS release 无签名包；
5. 补齐 APNs、OPPO/FCM 平台凭据后做两台真机验收。

迁移命令：

```bash
cd backend
set -a; source .env; set +a
go run ./cmd/migrate migrations/006_realtime_channel_capabilities.sql
```

成功时应看到 `applied 006_realtime_channel_capabilities.sql`；重复执行应看到 `skip`。

生产公开端点检查：

```bash
./scripts/production-check.sh
```

原生产物重试：

```bash
./scripts/native-build.sh android
./scripts/native-build.sh ios
```

本机网络仍不可用时，提交 `.github/workflows/android-debug.yml` 和 `.github/workflows/ios-nosign.yml` 并在 GitHub Actions 运行。先在仓库 Actions secrets 配置 `SUPABASE_PUBLISHABLE_KEY` 与 `GOEASY_APP_KEY`。

注意：iOS 工程的配置名是小写 `debug` / `release`。不要直接运行裸
`xcodebuild -configuration Release`；Rust 构建阶段依赖 Tauri CLI 预先创建的临时地址文件。
`./scripts/native-build.sh ios` 已使用正确的 release 无签名入口。

## 当前硬阻塞

- 当前 Codex 沙箱 DNS 可能无法解析公网 API。
- 2026-06-23 00:24 执行第 6 迁移时无法解析 Supabase 数据库主机；连接建立前即失败，远端没有部分变更。
- Android target crates 和 iOS CoreSimulator 在此前沙箱中受限。
- 2026-06-23 执行 release iOS 构建时仍在 Tauri 预检阶段失败：
  `xcrun simctl list runtimes --json` 无法连接 CoreSimulatorService；尚未进入项目编译。
- 2026-06-23 离线 iOS target 检查仍停在缺少缓存 crate
  `async-broadcast v0.7.2`；Rustfmt 已解析 iOS 源码，主机 target 的 check/clippy 通过。
- APNs、OPPO/FCM 真机凭据仍不完整。
- GitHub App 创建远程分支被集成策略 403 拒绝；CI 文件已落在本地，但尚未提交到远端。
- 当前执行环境不允许创建 `.git/index.lock`，因此本轮无法替用户暂存或提交；所有改动仍完整保留在工作区。

## 不可回退的产品决定

- 04:00 日切，固定北京时间。
- AI 鼓励预取、内联展示，不等待迟到结果。
- 允许伴侣中途加入专注；各自时长和共同重叠时长分开。
- 临时请假默认每月 4 天、最多连续 2 天，可服务端调整。
- 非必要不用弹窗。
- 当前先交付正式核心版；IM、社区属于远期终态。
