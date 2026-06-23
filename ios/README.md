# SynDay iOS 工程

## 快速开始
1. 打开Xcode，新建项目 → iOS → App
2. 项目名称：SynDay
3. Team：5R7CUPKMAZ（Kyle Liao）
4. Bundle Identifier：cloud.catclaw.synday
5. 界面：SwiftUI
6. 语言：Swift
7. 不要勾选Core Data、Include Tests
8. 创建完成后，删除Xcode自动生成的`ContentView.swift`和`Assets.xcassets`中的默认内容
9. 将本目录下的`SynDay/`文件夹内所有文件拖入Xcode项目，选择"Copy items if needed"，勾选"Create groups"
10. 最低部署目标设置为iOS 17.0
11. 后续添加SPM依赖：
    - GRDB.swift（数据库）
    - Nuke（图片缓存）
    - GoEasySwift（WebSocket）
    - Supabase Swift（认证/API）

## 目录结构
```
SynDay/
├── App/            # 入口、全局主题、Tab配置
├── Core/           # 核心层：API、Auth、WebSocket、缓存、离线队列
├── Features/       # 业务模块
│   ├── Focus/      # 专注页
│   ├── Couple/     # 情侣页
│   ├── Planner/    # 排程页（含课表编辑器、Agent卡片）
│   ├── Chat/       # IM页
│   └── Profile/    # 我的页（含登录认证）
├── Shared/         # 共用组件、设计扩展、震动反馈
└── Resources/      # 资源：Assets、声音文件
```
