# GitHub Actions 构建说明

## Android debug APK

工作流：`.github/workflows/android-debug.yml`

仓库 Actions secrets 需要配置：

- `SUPABASE_PUBLISHABLE_KEY`
- `GOEASY_APP_KEY`

两者都是客户端使用的公开级 key，但仍通过 Actions secrets 注入，避免写进公开仓库历史。

推送到 `main` / `codex/**` 且修改 `frontend/**` 后会自动构建；也可在 Actions 页面手动运行。成功产物名：

`synday-android-arm64-debug`

下载后安装到一加 Ace 5：

```bash
adb install -r app-arm64-v8a-debug.apk
```

若未配置 secrets，原生编译仍可完成，但安装包内登录和实时服务不会可用，因此不能作为最终验收包。

## iOS release 无签名构建

工作流：`.github/workflows/ios-nosign.yml`

该工作流使用 release 模式，只证明 iOS arm64 原生代码和 Xcode 工程能够完整编译，不产生可直接安装的签名 IPA。最终真机版本仍需本机 Apple Developer Team 签名。

成功产物名：

`synday-ios-arm64-unsigned`
