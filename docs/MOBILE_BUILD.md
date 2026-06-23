# SynDay 双端构建与真机验收

最后更新：2026-06-23

## 共同准备

```bash
cd "/Users/kyleliao/Vibe-Coding/SynDay朝夕同序"
source scripts/dev-env.sh
./scripts/check.sh
```

创建 `frontend/.env.production`，填入生产 API、Supabase publishable key 和 GoEasy app key。任何 service role、数据库密码、AI 或推送私钥都不得放入客户端环境变量。

建议统一通过 `./scripts/native-build.sh android|ios` 构建。脚本会验证生产 API、
Supabase URL 和 publishable key，避免在缺少配置时生成实际指向 localhost 的不可用安装包。

## Android

首次在可访问 crates.io 的终端中预取并构建：

```bash
cd frontend
npx tauri android build --debug --apk
```

发布签名前创建独立 keystore，并通过本机私密 Gradle 配置注入密码。不要将 `.jks`、密码或 `key.properties` 提交 Git。

完成 FCM/OPPO 项目后，还需：

- 放入 Firebase Android 配置并接入设备 token 获取。
- 在 OPPO 开放平台创建 `cloud.catclaw.synday` 对应应用。
- Ace 5 大陆版分别验证 OPPO PUSH 主通道、FCM 备用和数据库通知补拉。
- 验证通知关闭、静音、勿扰、杀进程和重启后的行为。

验收设备：

- 一加 Ace 5（大陆版 ColorOS）
- Windows 上的 MuMu 模拟器作为补充，不替代真机推送验收

## iOS

先确认 Xcode 的 Simulator 服务正常，即使最终使用真机，Tauri CLI 仍会执行运行时预检：

```bash
xcrun simctl list runtimes --json
```

release 无签名编译验收：

```bash
cd frontend
npx tauri ios build --no-sign --target aarch64 --ci
```

Apple Developer 开发签名真机构建：

```bash
./scripts/prepare-ios-assets.sh
npx tauri ios build --target aarch64 --export-method debugging --ci
```

不要直接从命令行裸跑 Xcode 的 Rust build phase；它依赖 Tauri CLI 创建的临时地址文件。
生成工程内部的配置名是小写 `debug` / `release`，但使用上面的 Tauri 命令不需要手动处理。
若执行过 `tauri icon` 或重新生成 iOS 工程，必须再次运行
`./scripts/prepare-ios-assets.sh`，因为 Tauri 源图标要求 RGBA，而 Apple 最终 AppIcon 要求 RGB 无 alpha。

Apple 配置：

- Team ID：`5R7CUPKMAZ`
- Bundle ID：`cloud.catclaw.synday`
- 开启 Push Notifications capability。
- APNs Auth Key 的 `.p8` 只写入服务器环境变量。
- 当前 entitlement 使用 `development`，适合 Apple Developer 开发签名安装到登记真机。
- 对应服务器必须设置 `APNS_ENVIRONMENT=development`；否则开发 token 发往生产 APNs 会被拒绝。
- 若后续走 TestFlight/App Store Connect，改用 `--export-method app-store-connect`，并让 Xcode 生成匹配的 production entitlement。

验收设备：

- iPhone 17 Pro
- iOS 27 beta 1

重点验证相机扫码、深链接、APNs token、前后台通知、静音模式、专注模式和倒计时恢复。

## 已知本机环境阻塞

- Codex 执行沙箱无法解析 `static.crates.io`，Android target 依赖无法补齐。
- 沙箱无法访问 CoreSimulator 日志和服务，Tauri iOS CLI 预检失败。
- 这些限制不影响 `go test ./...`、Vite 生产构建和主机 `cargo check`，但不能代替目标平台构建。
