# Disaster Recovery｜零成本 Pilot 恢复手册

> 这份文档定义 **未来 gated Production Pilot 在 P0 Gate A/B 与 Go/No-Go 后才可使用的恢复流程**。它不是“备份提醒”，而是恢复演练检查表。任何真实密码、连接串、Backup 文件都不得提交 GitHub。
> **Phase 0B.0 provider / production hard boundary**
>
> 当前仅将 Supabase 视为 V1 reference / preferred implementation candidate；尚未无条件冻结为 production provider。正式 production business migrations、Production Auth/RLS/CRUD 与真实学生/教师/家长数据之前，必须先完成并通过：
> 1. **P0 Gate A — Auth Identity Portability Spike**；
> 2. **P0 Gate B — Revoked Session / Old Token Security Spike**。
>
> 在两项 Gate 之前，只允许用虚构数据进行 provider-specific compatibility/security spike；Spike 不构成 production migration 授权。两 Gate 通过后，才可冻结 provider、region、identity 与 session strategy，再另行执行正式 migrations、Auth/RLS/CRUD 与 Go/No-Go。

## 1. Pilot 恢复目标

V1 Free Pilot 默认目标：

- **RPO**：不超过一个教学日；
- **RTO**：不承诺商业 SLA，但必须通过实际恢复演练得到现实值；
- 真实数据上线前至少完整恢复一次；
- 之后按机构使用强度定期恢复演练。

如果机构不能接受一个教学日左右的数据损失窗口，Free Pilot 不满足要求，应重新做成本/基础设施 ADR。

---

## 2. 需要恢复的不是只有 PostgreSQL

完整恢复集合：

1. **GitHub**
   - source
   - 若 P0 Gate A/B 通过且最终选定 Supabase，才纳入其 `supabase/migrations`
   - Edge Functions source
   - docs / recovery runbook

2. **Database**
   - roles
   - schema
   - data
   - 必要 migration history
   - 若最终选定 Supabase，Auth user data（按恢复当日官方 backup/restore 流程验证）

3. **Storage**
   - bucket/object files
   - object manifest
   - DB metadata 与文件对应关系

4. **Project configuration**
   - Auth 配置
   - JWT/API key 切换步骤
   - Realtime 配置
   - Database extensions/settings
   - Edge Function Secrets 名单（**只列 key 名，不在 Git 写值**）
   - Storage bucket/policy 配置
   - Function region/config

数据库恢复成功，不代表整个 Xueqing 已恢复。

---

## 3. Database Backup

Supabase Free 没有付费级自动日备份保障。使用官方 CLI 逻辑 dump。

在受控管理员环境设置 DB connection string，不把密码写入脚本/历史日志。

### Roles

```bash
supabase db dump \
  --db-url "$SUPABASE_DB_URL" \
  -f roles.sql \
  --role-only
```

### Schema

```bash
supabase db dump \
  --db-url "$SUPABASE_DB_URL" \
  -f schema.sql
```

### Data

```bash
supabase db dump \
  --db-url "$SUPABASE_DB_URL" \
  -f data.sql \
  --use-copy \
  --data-only \
  -x "storage.buckets_vectors" \
  -x "storage.vector_indexes"
```

如果项目以后使用 vector bucket，按当时 Supabase 官方恢复文档重新核对排除项。

### Migration History（需要保留时）

```bash
supabase db dump \
  --db-url "$SUPABASE_DB_URL" \
  -f history_schema.sql \
  --schema supabase_migrations

supabase db dump \
  --db-url "$SUPABASE_DB_URL" \
  -f history_data.sql \
  --use-copy \
  --data-only \
  --schema supabase_migrations
```

### 每次 backup metadata

单独保存：
- backup timestamp（UTC + 本地日期）
- gated Production project ref（仅在 P0 Gate A/B 后；不要写 Secret）
- app version / git commit
- latest migration version
- Supabase/Postgres version（可获取时）
- 文件 SHA-256
- Storage manifest version
- 执行人

---

## 4. Backup 存放

备份必须：
- **加密**；
- 存在 Supabase 之外；
- 不进入 GitHub，包括 Private repo；
- 不放在所有人都能访问的个人共享目录；
- 至少保留多个时间点；
- 至少有一份不与 Production 同故障域的副本。

零成本优先使用机构已经拥有、允许承载该类数据的加密存储/受控设备。不要为了“免费”把未成年人数据随意塞到未经机构批准的个人网盘。

---

## 5. Storage Backup

数据库 dump 只有 Storage metadata，不等于文件本体。

V1 需要实现一个可重复的 Storage backup 工具/脚本：

1. 列出所有受管 bucket；
2. 导出对象：
   - bucket
   - object path
   - size
   - content type
   - updated_at/version（可获得时）
   - checksum（本地计算）
3. 下载文件到加密备份目录；
4. 生成 manifest；
5. 校验本地文件 checksum；
6. 记录下载失败对象；
7. backup 只有所有必要对象成功后才标记 complete。

不要把 signed URL 当长期备份地址；它是短时 bearer credential。

---

## 6. Project Configuration Checklist

仓库保存“怎么配置”，Secret 值存受控 Secret 管理位置。

恢复时逐项核对：

### Auth
- Password provider enabled
- public sign-up 关闭/符合 V1 策略
- JWT expiry
- URL/redirect 设置（如后续需要）
- Auth hooks/config（如有）

### Database
- extensions
- Data API exposed schemas
- custom auth/storage schema changes（若未来有）

### Storage
- bucket names
- private/public 状态
- file-size/type policies
- RLS policies

### Edge Functions
- deployed functions
- function region
- Secret **names**
- required environment variables

### Realtime
- publications/settings（若使用）

### Client
- Production URL
- Publishable Key
- minimum supported app version

API/JWT/Secret 值在新 Project 可能改变，恢复后客户端配置必须更新。

---

## 7. 恢复演练：新项目

**永远先恢复到新的非 Production 项目，不直接拿 Production 做实验。**

### 7.1 创建新测试 Project
- 选择与未来 gated Production 兼容的 region；（实际 Production 选择仍须在 P0 Gate A/B 后冻结）
- 获取新的 DB connection string；
- 记录新的 API keys，但不要提交 Git。

### 7.2 Restore Database

按 Supabase 当前官方 Backup/Restore 文档执行。典型流程：

```bash
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file roles.sql \
  --file schema.sql \
  --command 'SET session_replication_role = replica' \
  --file data.sql \
  --dbname "$NEW_SUPABASE_DB_URL"
```

如果当时官方文档已改变，**以恢复当天官方文档为准**，并在 runbook 记录差异。

恢复 migration history（如需要）。

若项目对 `auth` / `storage` managed schemas 做过自定义修改，按官方流程另外恢复/迁移，不手工猜。

### 7.3 Restore Storage

1. 重建/核对 bucket；
2. 上传 manifest 中所有对象；
3. 核对 size/checksum；
4. 抽样打开文件；
5. 比较 DB object path ↔ Storage object。

### 7.4 Rebuild Configuration

按 Project Configuration Checklist：
- Auth
- Extensions
- Storage policies
- Edge Functions
- Secrets
- Realtime
- Client config

### 7.5 Smoke Test

至少：
- 管理员登录；
- 普通教师登录；
- live-session RLS；
- active/onboarding/disabled 权限；
- 学生列表；
- 一个完整 case 时间线；
- case action / Today；
- lesson；
- Storage 下载；
- Edge Function；
- 两个机构的 cross-org 负面测试。

---

## 8. 恢复演练记录

每次恢复保存一份**不含敏感业务正文**的记录：

```text
Backup ID:
Backup timestamp:
Git commit:
Migration version:
Restore target:
Restore start/end:
Measured RTO:
Estimated RPO:
DB row-count checks:
Storage object checks:
Auth smoke:
RLS negative tests:
Failures:
Fixes:
Result: PASS / FAIL
```

FAIL 不是“下次再看”，必须修流程后重新演练。

---

## 9. Backup 频率

Pilot 默认：
- 每个有真实教学数据变化的教学日后至少一次逻辑备份；
- 重要 migration / release 前后追加备份；
- 长假/可能 pause 前确认最新完整备份；
- 频率根据机构可接受 RPO 调整。

以后真实使用量扩大，可自动化，但自动化仍必须有 restore drill。

---

## 10. Project Pause / Region Migration

### Free Project Pause
若未来 gated Free Production 因低活动暂停：
- 不慌张直接乱改 schema；
- 先确认最新 off-site backup；
- 按 Supabase 当前恢复流程恢复/唤醒；
- 恢复后 smoke test。

### Region Migration
Project 不能原地更换 region。迁移流程视同灾难恢复：
- 新 project；
- DB restore；
- Storage transfer；
- config rebuild；
- client config 更新；
- smoke / permission / network tests；
- P0 Gate A/B、provider/identity/session strategy 与 Go/No-Go 全部通过后，最后才切换真实用户。

---

## 11. 不能做

- 把 backup 提交到 GitHub；
- 只备份 schema 不备份 data；
- 只备份 DB 不备份 Storage；
- 只保留一个 backup 文件；
- backup 从未实际 restore；
- 连接串/DB 密码写进脚本仓库；
- 用真实 gated Production 做第一次 restore 试验；
- 假定“Supabase Free 会替我们自动保留可下载日备份”。

---

## 12. 何时升级基础设施

如果：
- RPO ≤ 一个教学日不再可接受；
- 系统成为日常关键基础设施；
- 恢复时间无法接受；
- 备份人工运营成本过高；

则重新做成本 ADR，评估付费自动备份/PITR/更高 SLA。不要为了“永远 0 元”赌真实学生数据。
