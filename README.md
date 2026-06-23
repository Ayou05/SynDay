# SynDay 朝夕同序

一体化刚性自律学习管理系统，包含单人学习、每日复盘、连续打卡、情侣只读监督和陪伴式联机专注。

当前处于 24 小时完整交付挑战的实施阶段。

## 文档

- [24 小时执行计划](docs/PLAN.md)
- [产品与技术决策](docs/DECISIONS.md)
- [远期完整产品白皮书](docs/FUTURE_PRODUCT_WHITEPAPER.md)
- [产品范围与需求追踪](docs/PRODUCT_SCOPE_MATRIX.md)
- [Agent 交接板](docs/HANDOFF.md)
- [GitHub Actions 构建](docs/GITHUB_ACTIONS.md)
- [实时实施状态](docs/STATUS.md)
- [V1 验收清单](docs/ACCEPTANCE.md)
- [部署手册](docs/DEPLOYMENT.md)
- [双端构建与真机验收](docs/MOBILE_BUILD.md)
- [隐私与数据边界](docs/PRIVACY.md)

## 目录

- `backend/`：Go API、业务规则、定时任务和数据库迁移
- `frontend/`：Tauri 2 + Vanilla JS iOS/Android 客户端
- `deploy/`：服务器、Nginx、systemd 和发布配置
- `docs/`：计划、决策、部署和验收文档
- `scripts/`：开发环境与一键质量检查脚本

## 本地质量检查

```bash
chmod +x scripts/check.sh
./scripts/check.sh
```

生产与原生检查：

```bash
./scripts/production-check.sh
./scripts/native-build.sh android
./scripts/native-build.sh ios
```
