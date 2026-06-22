# SynDay 部署手册

## 1. 外部资源

1. 腾讯云香港 Ubuntu 24.04 轻量服务器，2 核 2GB。
2. Supabase 新加坡项目。
3. DNS：`api.synday.catclaw.cloud` 指向香港服务器公网 IP。
4. GoEasy 应用。
5. DeepSeek API Key。
6. Apple APNs `.p8` 密钥。
7. OPPO PUSH 应用凭据；FCM 凭据作为备用。

## 2. Supabase

在 Supabase SQL Editor 中按顺序执行：

1. `backend/migrations/001_initial_schema.sql`
2. `backend/migrations/002_business_functions.sql`
3. `backend/migrations/003_policy_constraints.sql`
4. `backend/migrations/004_idempotent_operations.sql`
5. `backend/migrations/005_focus_auto_completion.sql`

随后在 Authentication 中：

- 启用 Email + Password。
- 首轮双人自用可关闭邮箱确认；正式分发时建议开启。
- Site URL 可设为 `synday://auth`。
- Redirect URL 添加 `synday://auth/callback`。

## 3. 服务器

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 nginx certbot python3-certbot-nginx
sudo usermod -aG docker "$USER"
```

将仓库部署到 `/opt/synday`，复制环境变量：

```bash
cp deploy/.env.example deploy/.env
chmod 600 deploy/.env
```

填入真实密钥后：

```bash
cd /opt/synday/deploy
docker compose up -d --build
curl http://127.0.0.1:8080/healthz
```

先安装仅 HTTP 的启动配置并签发证书，避免 Nginx 在证书尚不存在时加载失败：

```bash
sudo mkdir -p /var/www/certbot
sudo cp nginx-synday-bootstrap.conf /etc/nginx/sites-available/synday
sudo ln -s /etc/nginx/sites-available/synday /etc/nginx/sites-enabled/synday
sudo nginx -t
sudo systemctl reload nginx
sudo certbot certonly --webroot -w /var/www/certbot -d api.synday.catclaw.cloud
```

证书签发成功后替换为正式 HTTPS 配置：

```bash
sudo cp nginx-synday.conf /etc/nginx/sites-available/synday
sudo nginx -t
sudo systemctl reload nginx
curl https://api.synday.catclaw.cloud/healthz
```

## 4. 客户端环境变量

复制 `frontend/.env.example` 为 `frontend/.env.production`：

```dotenv
VITE_API_BASE_URL=https://api.synday.catclaw.cloud
VITE_SUPABASE_URL=https://PROJECT.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=...
VITE_GOEASY_HOST=hangzhou.goeasy.io
VITE_GOEASY_APP_KEY=...
```

发布包内只能放 Supabase publishable/anon key，不能放 service role、数据库密码、DeepSeek、APNs 或厂商推送密钥。

## 5. 健康检查

- `GET /healthz`：数据库连通状态。
- `GET /v1/time`：服务端时间、北京时间时区与业务日期。
- 每日 04:00：结算昨日、刷新复盘、生成今日任务。
- 每日 23:30：生成复盘草稿并进行 AI 增强。
- 每月 1 日 04:10：生成上月情侣联合简报。

## 6. 备份

Supabase 托管项目应开启平台备份。每次迁移前额外执行逻辑备份：

```bash
pg_dump "$DATABASE_URL" --format=custom --file="synday-$(date +%F-%H%M).dump"
```

恢复演练：

```bash
pg_restore --clean --if-exists --no-owner --dbname="$RESTORE_DATABASE_URL" backup.dump
```
