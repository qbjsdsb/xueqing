# Foundation v0.3｜最终全面审计与冻结门槛

> 目的：结束“继续写理论”的阶段。这里记录 Foundation 冻结前最后一轮产品、权限、数据、设备、云端 Agent、免费基础设施和恢复审计。**只有这里列出的 Phase 0 假设被真实执行验证后，才进入真实学生数据。**

## 结论

Foundation v0.3 已经可以作为 **Freeze Candidate**。

后续继续提高质量的主要方式不再是增加架构文档，而是：
- Flutter 真正 build；
- Supabase migrations/RLS tests；
- Windows/Android 真机/真实网络；
- 旧 JWT 攻击式测试；
- encrypted draft / secure Session；
- backup restore drill。

没有执行证据的部分继续标记为“设计已收敛、尚未验证”。

---

# A. 产品审计

## 已通过
- 产品核心仍是“学生连续档案 + 学情 case + 证据 + 干预 + 验证 + 下一步”；
- V1 只保留 Today / 学生 / 课程 / 学情；
- 不复制 Excel 的周表/顽固问题第二台账；
- lesson 没扩成排课收费 CRM；
- AI 没成为正式事实源；
- 管理端不以填表量做核心 KPI。

## 最终修正：暂停 Case
旧规则允许“primary action 或 pause_reason”，可能让一个问题永久失踪。

冻结规则：
- new 可没有 action；
- confirmed/intervening/pending_verification/stable 始终有 pending primary action；
- 暂缓 = `review` action + `due_at`；
- pause_reason 只解释；
- closed 无 pending primary action。

**不新增 `next_review_at`**，避免第二套日期事实源。

---

# B. 账号 / 身份 / 多租户审计

## 最终 Auth 流程

```text
provision
→ onboarding + expiry
→ 临时密码登录
→ 设置新密码
→ global sign-out all sessions
→ membership active
→ 强制重新登录
```

reset：**先 onboarding，再更新 Auth 密码**。

Credential 响应丢失：reissue 新 secret，不保存旧明文。

## Live Session
业务访问要求：

```text
JWT session_id 仍存在于 auth.sessions
+ membership active
+ organization
+ role/assignment
```

Phase 0 必须保存一个旧 JWT，完成 global sign-out 后直接调用业务 API，证明立即拒绝。

## 最终新增边界：V1 不开放跨机构同账号

密码属于全局 Auth User。若同一 user 同时属于两个机构，A 机构 org_admin 重置其密码会影响 B 机构，这是不合理的跨租户身份治理。

因此 V1：
- 数据库仍从第一天多租户；
- **同一个 Auth User 同一时点最多一个 `onboarding/active` membership**；
- 可以保留其他机构 disabled 历史；
- `provision_member` 发现目标 Auth User 已在另一机构 onboarding/active 时拒绝，并提示 V1 不支持跨机构账号；
- 不做“机构 A 管理员可以重置一个跨机构用户的全局密码”。

未来如果要支持同一个教师加入多个机构，先新增 ADR，改成中央身份恢复、Email OTP/SSO 或其他不会让单一机构管理员控制全局 credential 的方案，再移除限制。

---

# C. 管理员单点故障审计

无 SMTP 自助恢复时，唯一管理员是单点故障。

真实 Pilot 至少：
- 2 个独立可信 active org_admin；或
- 已演练 Project Owner break-glass。

并增加规则：
- 不能通过普通 UI 停用最后一个可恢复 org_admin；
- 重置另一个 org_admin 也要有审计；
- break-glass 不是公开 API。

---

# D. Flutter 设备安全审计

## Session
`supabase_flutter` 默认用 SharedPreferences 系列持久化 Session。Production 必须：
- custom `LocalStorage`；
- Windows/Android OS secure storage；
- Password 不持久化。

## Startup Gate
Flutter v2 初始化不保证本地 Session 已完成远端刷新。业务 Shell 只有在：
- Session valid/refreshed；
- live session；
- active membership；
- current organization

全部解析后才挂载。

禁止旧/disabled Session 闪现学生页面。

## Draft
跨重启敏感 draft：
- encrypted at rest；
- key 在 OS secure storage；
- user/org scope；
- TTL；
- sync 后删除；
- account switch 不串数据；
- logout 明确同步/丢弃；
- disabled/revoked 后不继续解锁；
- 不存 Token/Password。

---

# E. Realtime 审计

V1 **不在学生敏感业务表依赖或默认开启 Realtime**。

理由：
- 正确性本来就要求 refresh/App resume 能恢复；
- Session revoke 对已有长连接的语义需要单独测试；
- 为“看起来实时”不值得增加额外攻击面和调试复杂度。

V1 使用：
- 页面进入刷新；
- 保存后刷新；
- App resume 刷新；
- 手动刷新。

以后要开启 Realtime，新增 ADR + revoked-session / reconnect / cross-org 测试。

---

# F. Storage 审计

- private bucket；
- `storage.objects` RLS 与 organization / assignment 同步；
- signed URL 只在授权后生成、短时、视作 bearer credential；
- signed URL 不进日志/聊天/长久缓存；
- 文件大小/类型限制；
- DB metadata 与 Storage object 生命周期一致；
- Storage 文件单独 backup。

Phase 0 必须有跨机构直接下载攻击测试。

---

# G. Supabase Region / 中国大陆网络审计

当前没有中国大陆 region；APAC 可选 Singapore/Tokyo/Seoul 等，且 project region 不能原地修改。

最终流程：
1. Remote Development 只用虚构数据；
2. 实际机构 Wi‑Fi，无代理/VPN；
3. 普通移动网络，无代理/VPN；
4. Auth/Data API/Storage/Functions/重连；
5. 不合格就重建 Dev 换 APAC region；
6. 测试合格后再建 Production；
7. 机构单独评估未成年人信息的数据驻留/跨境合规。

---

# H. GitHub / AI Agent 治理审计

## 当前必须手工调整的 repo 设置
- [ ] Public → **Private**
- [ ] 取消 **Template repository**（本项目不是模板）
- [ ] 关闭 GitHub **Wiki**，避免形成 repo/docs 之外的第二文档事实源
- [ ] 可选：合并后自动删除 feature branch
- [ ] Foundation PR 最终优先 **Squash merge**，把大量评审中间 commit 收敛成一个清晰基线

## GitHub Free private 的限制
私有 branch protection/rulesets 需要更高 GitHub 计划，所以零成本阶段不能假装平台会强制 PR。

流程替代：
- Work/Codex 禁止直推 main；
- branch + Draft PR；
- 真实执行证据；
- 人工合并。

## Actions 成本
- budget 开启 `Stop usage when budget limit is reached`；
- PR 只跑 Linux 快速检查；
- Windows/Android heavy build 只在 Milestone/Release；
- 不用 larger runner。

## Agent 连接原则
- GitHub 可作为常规 Work 默认连接；
- Supabase 开发连接默认只指向 Local/Remote Development；
- **Production 不作为普通 Work 会话的默认可写环境**；
- Production migration/repair 应是单独 Release/Incident 任务，有明确范围、备份和 smoke test；
- Agent 没执行命令必须写“未执行”。

---

# I. 免费备份 / 恢复审计

Free 不等于有自动日备份。

恢复集合：
- roles.sql
- schema.sql
- data.sql
- 必要 migration history
- Storage objects + manifest
- Auth/Realtime/Extensions/Secrets/project config checklist
- Git 中的 Edge Functions/migrations

目标：
- Pilot RPO ≤ 一个教学日；
- 真 restore 到非 Production 新项目；
- smoke + RLS 负面测试；
- backup 不进 GitHub。

详细见 `DISASTER_RECOVERY.md`。

---

# J. 数据模型审计

已确认：
- Student 不因学科/教师/年级重复；
- enrollment/assignment 历史；
- advisor 与 teacher 分表；
- case current snapshot + events；
- evidence/intervention/assessment/action 分事实；
- lesson 一对多，不重复保存 case 结果；
- merged student 保留映射；
- operation id 不存 credential secret。

Phase 0/Milestone 1 需新增数据库限制：
- `(organization_id, user_id)` unique；
- V1 对 `user_id` 的 onboarding/active membership 再加 partial unique，禁止同一用户同时跨机构活跃；
- active owner/assignee membership；
- primary action partial unique；
- cross-org composite FK / function validation。

---

# K. 删除 / 离职 / 交接审计

- 不删除教师历史；
- handoff 完成后才 disabled；
- case owner / pending actions 不 orphan；
- student merge 不物理抹掉 source；
- 最后一个可恢复 org_admin 不允许普通流程停用。

---

# L. 仍然明确不做

- 收费/课消/招生 CRM
- 完整排课 ERP
- 大型题库
- 学情综合分/预测
- 复杂 offline-first / CRDT
- 同时维护 Password/OTP/Magic Link 多套主登录
- Realtime 作为 V1 正确性前提
- 公开自助 SaaS 注册
- AI 自动修改正式学情
- 为“免费”牺牲恢复/权限/隐私

---

# M. Foundation Freeze Checklist

只有以下都完成，Foundation PR 才从 Draft 进入可合并状态：

### 文档一致性
- [x] PRODUCT
- [x] ARCHITECTURE
- [x] AUTH_AND_PERMISSIONS
- [x] DATA_MODEL
- [x] COMMANDS_AND_INVARIANTS
- [x] SECURITY_AND_PRIVACY
- [x] RISKS_AND_OPERATIONS
- [x] DEVELOPMENT_WORKFLOW
- [x] ZERO_COST_CLOUD_DEVELOPMENT
- [x] ROADMAP
- [x] DISASTER_RECOVERY
- [x] AGENTS
- [x] ADRs

### GitHub 手工设置
- [ ] repo Private
- [ ] Template repo 关闭
- [ ] Wiki 关闭
- [ ] Actions zero-overage budget 设置

### PR 事实
- [ ] 最终 diff 人工/Agent 再审一次
- [ ] 没把 Foundation 占位源码描述成“可运行 App”
- [ ] PR 明确：当前没有正式 Flutter/Supabase CI，所以**没有 CI green 可声称**

完成后建议 **Squash merge** Foundation v0.3。

---

# N. Phase 0 的第一条真正验收链

最值得先证明的不是“学生列表页面”，而是：

```text
Private repo
→ Flutter 双平台可 build
→ Local Supabase 可 reset
→ RLS live session tests
→ secure Session + Startup Gate
→ encrypted drafts
→ Remote Dev 无代理网络/region
→ provision teacher
→ onboarding expiry
→ set new password
→ global sign-out
→ old JWT direct API denied
→ new login active
→ admin reset
→ old access denied
→ DB + Storage backup/restore
```

这条链真正跑通后，再开始学生/学情 UI，后面的返工风险会大幅下降。
