# 开发、数据库与发布工作流

> 目标：任何新 Work/Codex 会话或新电脑都能从 GitHub 重建真实开发状态；不依赖某次聊天记忆、某台电脑或 Remote Dashboard 的隐性修改。

## 1. 四个事实源

- **GitHub**：源码、文档、migrations、测试、CI；
- **`supabase/migrations`**：数据库 schema / RLS / View / Function / Trigger / Index 的正式结构事实源；
- **Supabase Production Pilot**：真实业务数据事实源；
- **ChatGPT Project / Work**：协作/执行上下文，不是代码或数据库事实源。

Remote Dashboard 与聊天历史都不能覆盖 Git。

---

## 2. 三种环境

### Local Development
- Supabase CLI local stack；
- 虚构 seed/Auth；
- migrations、constraints、RLS、DB functions 测试；
- 可 reset/reseed；
- 不承载真实机构数据。

### Remote Development
一个 Supabase Free Project，仅虚构数据，用于 Local 无法证明的：
- Windows + Android 同后端；
- Password Auth / Session；
- provision/onboarding/reset Edge Functions；
- live-session 行为；
- Storage；
- 网络切换；
- 两教师共享数据；
- region/网络 Spike。

它不是 schema 第二事实源，可以重建/删除。

### Production Pilot
第二个 Supabase Free Project：
- 真实数据；
- 不执行 development seed/reset；
- 只部署已在 Local + Remote Development 验证的 migrations；
- 独立 Auth/Storage/Secrets；
- 定期 DB + Storage 离站备份；
- 进入真实数据前通过全部 Go/No-Go。

---

## 3. Region 先测试，后建 Production

Supabase project 绑定 region，换 region 需要建新项目迁移。因此：

1. Remote Development 先选一个合理 APAC region；
2. 使用虚构数据，在实际机构 Wi‑Fi、普通移动网络、无代理/VPN下测试；
3. 覆盖 Auth、Data API、Storage、Edge Functions、网络切换；
4. 不合格则重建 Remote Development 到另一 APAC region；
5. 只有测试结论稳定后，才创建 Production Pilot；
6. 真实未成年人数据的数据驻留/跨境处理另做机构合规评估。

不要为了省一次重建，把错误 region 固化进 Production。

---

## 4. 新环境从零开始

正式工程初始化后，目标流程：

```text
git clone
→ checkout 当前 branch
→ 安装仓库锁定 Flutter/Dart/Supabase CLI
→ flutter pub get
→ supabase start
→ supabase db reset
→ DB/RLS tests
→ flutter analyze
→ flutter test
→ 用虚构 config 启动 Development app
```

把稳定命令写成 README / script / CI，不让 Agent 每次猜。

---

## 5. Git / Work / PR

一个较大任务：
1. 一个可验收目标；
2. 一个 feature/review branch；
3. 一条主要 Work 会话；
4. 开始先读 `AGENTS.md` + 相关 docs + 当前仓库；
5. 小步提交；
6. Draft PR；
7. CI/真实执行；
8. review；
9. 合并。

### GitHub Free private 的现实限制

为了隐私，仓库必须 Private；但 GitHub Free 的 private repo 没有 Pro/Team 才有的私有 branch protection/ruleset 强制能力。

零成本阶段因此采用**流程治理**：
- Work/Codex 不直接 push main；
- main 只接受人工审阅后的 PR；
- PR 没有真实执行证据不合并；
- 不把“mergeable=true”理解为“质量已通过”；
- 以后 GitHub 计划升级再开启 required PR/status checks。

---

## 6. 数据库修改唯一正式路径

1. `supabase/migrations` 新 migration；
2. Local `db reset`；
3. fake seed；
4. DB/RLS tests；
5. Flutter Repository/Service 测试；
6. PR review；
7. Remote Development deploy；
8. 集成验证；
9. Production migration + smoke test。

禁止：
- 只改 Dashboard Table Editor；
- 只在 SQL Editor 建 policy/function；
- Remote 先跑通却不回写 migration；
- Production 直接试 SQL 再补文件。

Production migrations 一律向前滚动；已部署 migration 不靠本地重写历史“回滚”。破坏性修改采用 expand → migrate → contract 或明确恢复方案。

---

## 7. RLS / View / Function

每个业务表至少测试：
- unauthenticated；
- Auth User 无 membership；
- revoked session；
- onboarding；
- active；
- disabled；
- same org/no assignment；
- cross-org；
- cross-subject；
- admin/teacher 不同能力。

### live-session helper
Phase 0 验证 JWT `session_id` 与 `auth.sessions`：
- helper 放非 exposed schema；
- `security definer` 固定 `search_path = ''`；
- schema-qualified；
- 最小 grant；
- revoked JWT 直接调用 Data API 必须失败；
- 用 EXPLAIN 验证 RLS 性能。

View 优先 `security_invoker = true`。

---

## 8. Auth / Credential 开发

### Local
明显虚构测试账号/固定测试密码可以存在 local seed/test，但不得复制到 Remote Production。

### Remote Development 必测
- org_admin provision；
- onboarding expiry；
- 临时密码只显示一次；
- onboarding 业务拒绝；
- complete onboarding：改密码 → global sign-out → active → 强制新登录；
- 保存旧 JWT，完成接管后直接请求业务 API，必须失败；
- reset：先 onboarding 再更新密码；
- provision/reset 成功但响应超时 → reissue；
- disabled 旧 Session；
- 无 membership / cross-org；
- 两个客户端同时测试。

### Startup Gate
Supabase Flutter v2 可能先读出本地 Session；业务 Shell 必须等待 session validity/live-session/membership 解析，不允许隐私闪现。

### Session LocalStorage
Production 不使用默认 SharedPreferences Session 存储作为最终方案。Phase 0：
- 实现 Supabase custom `LocalStorage`；
- 使用 Windows/Android OS 安全存储；
- 验证重启、刷新、logout、reset、disabled；
- Password 不持久化。

---

## 9. 本地草稿

高频输入需要 crash/network 恢复，但真实正文必须安全：
- 用户+机构 scope；
- 加密 at rest；
- key 在 OS secure storage；
- TTL；
- sync success 删除；
- account switch 不串数据；
- logout 给出同步/丢弃选择；
- disabled/revoked 后不再解锁相关业务草稿；
- 不存 Token/Password。

先做最小 encrypted draft spike，再扩大使用范围。

---

## 10. Flutter 测试层级

### 每 PR 快速测试
- ViewModel/domain rules；
- Repository fake；
- Service mock / `supabase_testing`（适用时）；
- draft encryption/cleanup 单测；
- startup authorization gate。

### Local Supabase
- migrations；
- RLS；
- DB functions；
- constraints；
- negative authorization。

### Remote Development
只验证公网/真实 Auth Admin/Storage/Edge Functions/跨设备/网络/region。

### Release / Milestone
- Android build；
- Windows build；
- 关键 integration/smoke；
- Production migration compatibility review。

Phase 0A 已用 GitHub-hosted Ubuntu / Windows runner 完成一次 Android debug APK 与 Windows debug app 的真实构建验证；后续 native build workflow 保持手动触发，避免普通 PR 重复消耗。

---

## 11. GitHub Actions 成本控制策略

GitHub Free private 有有限 Actions 额度。用户于 2026-09-02 明确选择**暂不设置 zero-overage budget**，并接受这一账户级计费风险；因此 budget 不再作为 Foundation、Phase 0A 或真实数据 Go/No-Go 的硬阻塞项，详见 ADR-044。

工程侧必须用触发策略控制消耗：
- PR / `main` 默认 Linux：pub get、lockfile consistency、format、analyze、unit/widget tests；Phase 0B 后再加入适合 Linux 的 Local DB/RLS/static checks；
- 不让 feature branch 的 `push` 与 `pull_request` 对同一提交重复跑相同轻量 CI；
- Windows/Android native build 仅 Milestone/Release/手动；
- 不用 larger runner；
- artifact retention 短；
- 无价值中间产物不上传；
- 出现异常 Actions 消耗先停无价值 workflow，再评估后续策略。

如果未来用户改变决定，再启用 budget stop；在此之前不要把它反复列成未完成项。

---

## 12. Supabase Free 运行边界

- 一个 Remote Development；
- 一个 Production Pilot；
- Local CLI 不占云 project；
- 定期看 DB/Storage/Egress；
- 低活动可能 pause；
- Free 没有付费级自动日备份保障。

容量或可靠性不再适合真实业务时，必须重新做成本/风险 ADR。

---

## 13. Backup / Restore

Production Pilot 至少保存：
- `roles.sql`
- `schema.sql`
- `data.sql`
- 必要 `supabase_migrations` history
- Storage objects + manifest
- Project configuration checklist（Auth/Realtime/Extensions/Secrets 等）

备份不进入 GitHub。目标 Pilot RPO 默认 ≤ 一个教学日；若机构无法接受，免费方案不能进入真实数据。

发布/变更后按风险追加备份。定期恢复到非 Production 新项目并做 smoke test。

详见 `DISASTER_RECOVERY.md`。

---

## 14. Storage 开发

- private bucket；
- storage.objects RLS；
- signed URL 短时/授权后生成；
- 不记录 signed URL；
- 文件类型/大小限制；
- DB metadata 与对象生命周期一致；
- Storage backup 独立于 DB。

---

## 15. 配置与 Secret

- Flutter 使用 build-time config（如 `--dart-define-from-file` 等正式方式）；
- Publishable Key 可进入客户端配置；
- Secret/service_role/DB password/backup credential 只在可信环境；
- `.env.example` 只列变量名/虚构值；
- Development/Production Secret 不复用。

---

## 16. 发布策略

### Android
签名包、keystore 离线备份、版本号明确。

### Windows
Pilot 可受控内部发行，不把付费公信代码签名证书列为硬依赖；仍需固定下载来源、版本、校验与升级路径。

数据库 migration 与旧客户端需要兼容窗口；不能先破坏 schema 再要求所有老师立刻升级。

---

## 17. Work/Codex 执行证据

Work 适合研究、跨文件实现、PR/review；Codex/CI 适合真实终端/build/test。

每个 PR 必须区分：
- **已执行**：给出命令/CI 结果；
- **未执行**：明确列出原因和需要在哪里验证。

“模型判断应该通过”不等于 CI green。

如果 Work 容器没有某工具链，但 GitHub-hosted runner 或其他受控环境能提供对应工具链，应优先补真实执行证据，而不是把“当前容器不可用”永久当成项目未验证状态。

---

## 18. Definition of Done

一个 feature/里程碑只有在同时满足以下条件才完成：
- 用户流程正常；
- 空/错/网络失败可恢复；
- 权限负面路径；
- migrations/RLS 同步；
- 本地/云端敏感数据边界；
- 测试有真实执行证据；
- 文档/ADR 同步；
- 不产生未批准付费依赖；
- 不破坏既有端到端闭环。
