# Foundation v0.3｜最终全面审计与冻结结论

> 本文是 Foundation 冻结前的最终审计记录。目标不是继续增加理论，而是明确：哪些设计已经收敛、哪些只能靠 Phase 0 的真实执行来证明。

## 结论

**Foundation v0.3 已达到 Freeze Candidate。**

当前最有价值的下一步不再是增加架构文档，而是：
- Flutter Windows / Android 真正 build；
- Supabase migrations + RLS tests；
- Auth / Session 攻击式测试；
- secure Session storage + Startup Gate；
- encrypted draft；
- 实际机构网络 / Region 测试；
- DB + Storage 恢复演练。

没有真实执行证据的部分，只能称为“设计已收敛”，不能称为“已经验证”。

---

# 1. 当前 GitHub / PR 事实

- 仓库：`qbjsdsb/xueqing`
- 仓库已改为 **Private**；
- Foundation 分支：`review/foundation-v0.3`；
- PR #1 仍为 Draft；
- 当前 Foundation 分支相对 `main` 只有 ahead，没有 behind；
- 当前没有正式 Flutter / Supabase CI workflow run，因此不能声称 CI green；
- Foundation 仍应优先 Squash merge，避免把大量评审过程 commit 当成长期主线历史。

当前连接无法可靠确认的仓库设置，不写成已完成事实：
- Template repository 是否关闭；
- Wiki 是否关闭；
- Actions billing budget 是否已经设置为超额停止。

这些属于 GitHub 设置项，不影响设计冻结，但在正式 CI / Pilot 前应人工确认。

---

# 2. 产品审计：通过

V1 核心仍然是：

```text
Student continuous profile
→ Learning Case
→ Evidence
→ Intervention
→ Assessment
→ Next Action
→ Lesson / Today
```

已确认：
- 不把 Excel 的 8 张表变成 8 个软件模块；
- V1 主导航只保留 Today / 学生 / 课程 / 学情；
- 家校 / 报告进入 V1.1；
- lesson 不是完整排课 / 收费 / 课消 CRM；
- 周度、阶段、顽固问题尽量从原始事实派生；
- AI 只做 draft / 建议，不成为正式事实源；
- 管理端不以“老师填了多少条”作为核心 KPI。

### 正式 Case 永远有下一步

冻结规则：
- `new` 可以没有 action；
- `confirmed / intervening / pending_verification / stable` 必须有一个 pending primary action；
- 暂缓 / 观察 = `review` action + `due_at`；
- `pause_reason` 只解释原因；
- `closed` 不存在 pending primary action。

不再允许“只有 pause_reason、没有下一次检查”的正式案例。

---

# 3. 时间语义审计：已修正

最终审计发现原模型缺少机构时区，这会污染 Today、逾期、课程日期和报告周期。

已修正：
- `organizations.time_zone` 使用 IANA timezone，例如 `Asia/Shanghai`；
- 系统事件时间保存 UTC / `timestamptz`；
- Today、action 业务日期、课程属于哪一天、周度 / 报告周期统一按 organization timezone 解释；
- V1 不做 campus 独立时区；
- 不能直接相信教师设备时区。

这项已同步到 `DATA_MODEL.md`。

---

# 4. Auth / Session / Membership 审计：设计通过，Phase 0 必须实测

## 最终账号接管

```text
provision_member
→ membership(onboarding) + onboarding_expires_at
→ 临时密码登录
→ 设置自己的新密码
→ global sign-out all Sessions
→ membership active
→ 强制重新登录
```

管理员 reset：

```text
先 membership → onboarding
→ 再更新 Auth 临时密码
→ 刷新 onboarding expiry
→ 教师重新完整接管
```

Credential 响应丢失时：
- 不保存明文 secret；
- 不尝试“找回原密码”；
- 直接 reissue 新临时密码。

## Live Session

普通学生业务授权至少要求：

```text
JWT session_id 对应仍存在的 auth.sessions
+ active membership
+ organization
+ role / assignment
```

Phase 0 必须保存旧 JWT，在 global sign-out / reset / disable 后直接请求业务 API，证明旧 Access Token 即使尚未过 `exp` 也被拒绝。

### 性能边界

live-session guard 是安全机制，不应被写成每行重复昂贵查询。

Phase 0 必须：
- 封装稳定 helper；
- 让 planner 可尽量按语句级求值，而不是业务结果每行重复无意义计算；
- 为 Today / Student / Case 核心查询检查执行计划；
- 如果成为瓶颈，只能通过 ADR 优化实现，不能静默删除 live-session 安全条件。

---

# 5. V1 多租户边界：通过

数据库从第一天支持多个 organization，但 V1 **不开放同一 Auth User 跨机构同时 active/onboarding**。

原因：Password 属于全局 Auth User。如果一个用户同时属于 A、B 两个机构，A 机构 org_admin 的密码 reset 会影响 B 的登录，这不是合理的租户边界。

因此 V1：
- 同一 `user_id` 同一时点最多一个 `onboarding / active` membership；
- 其他 organization 可以保留 disabled 历史；
- `provision_member` 遇到另一机构非 disabled membership 时拒绝；
- UI 不做跨机构切换器。

未来确有跨机构账号需求时，再采用中央身份恢复、Email OTP、SSO 或等价模型后新增 ADR。

---

# 6. 管理员恢复：通过设计，待演练

没有 SMTP 自助恢复时，唯一 org_admin 是单点故障。

真实 Pilot 至少满足一个：
- 2 个独立可信 active org_admin；
- 或已经演练 Project Owner break-glass。

普通 UI 不能停用最后一个可恢复 org_admin。

---

# 7. Flutter 设备安全：设计通过，Phase 0 必须实测

## Session

Production 不把 `supabase_flutter` 默认 SharedPreferences 系列 Session 存储直接当最终方案。

要求：
- custom `LocalStorage`；
- Windows / Android OS secure storage；
- Password 永不本地持久化。

## Startup Gate

业务 Shell 只有在以下全部解析完成后才能挂载：
- Session valid / refreshed；
- live Session；
- active membership；
- current organization。

禁止旧 / expired / disabled Session 先闪现学生数据再被踢回登录。

## Draft

跨重启敏感草稿：
- encrypted at rest；
- key 存 OS secure storage；
- user / org scope；
- TTL；
- sync 成功删除；
- account switch 不串数据；
- logout / disabled 有明确处理；
- 不存 Token / Password。

---

# 8. Realtime：V1 明确后置

V1 不在学生敏感业务表默认开启 Realtime，也不依赖 Realtime 保证正确性。

V1 正确性必须靠：
- 页面进入刷新；
- 保存后刷新；
- App resume 刷新；
- 手动刷新。

以后开启 Realtime 前必须新增 ADR，并测试 revoked-session / reconnect / cross-org 行为。

---

# 9. Storage：设计通过，Phase 0 / Pilot 前验证

- private bucket；
- `storage.objects` RLS 与 organization / assignment 一致；
- signed URL 只在授权后生成，TTL 短；
- signed URL 视作 bearer credential，不进日志 / 长期缓存；
- 文件类型 / 大小有限制；
- DB metadata 与 Storage object 生命周期一致；
- Storage 文件本体必须单独备份。

必须有跨机构直接下载攻击测试。

---

# 10. Region / 中国大陆网络：必须真实验证

Production region 不提前拍脑袋决定。

流程：
1. Remote Development 只使用虚构数据；
2. 实际机构 Wi-Fi，无代理 / VPN；
3. 普通移动网络，无代理 / VPN；
4. 测 Auth / Data API / Storage / Edge Functions / 网络恢复；
5. 不达标则重建 Dev 并换 APAC region；
6. 测试合格后才创建 Production；
7. 未成年人数据驻留 / 跨境合规由机构单独评估。

Region 选择不是合规结论。

---

# 11. Database / 数据模型：通过

当前核心事实边界已经稳定：
- Student 不因学科 / 教师 / 年级重复；
- enrollment 保存年级 / 班级 / 校区历史；
- teacher assignment 与 advisor / homeroom staff assignment 分开；
- Case 使用 current snapshot + append-only events；
- Evidence / Intervention / Assessment / Action 分事实；
- Lesson 一对多，不重复保存 Case 结果；
- merged student 保留映射；
- credential secret 不进入 operation receipt；
- organization timezone 是业务日期事实源。

Milestone 1 / 3 的 migration 必须真正实现并测试：
- `(organization_id, user_id)` unique；
- V1 单 user 跨机构 active/onboarding partial unique；
- active owner / assignee；
- 一个 pending primary action；
- paused review 必须 due_at；
- cross-org composite FK / Function validation；
- 非法状态跳转拒绝。

---

# 12. 备份 / 恢复：设计通过，必须实际演练

Free Pilot 不把“有 SQL 文件”当成恢复能力。

完整恢复集合至少包括：
- roles；
- schema；
- data；
- 必要 migration history；
- Auth user / identity 数据按当前 Supabase 官方流程恢复并实际登录验证；
- Storage objects + manifest；
- Auth / Realtime / Extensions / Edge Functions / Secrets 名单 / project config checklist；
- Git 中的 migrations / Functions source。

重要边界：
- 新 Supabase Project 通常有新的 JWT secret，因此旧 token 默认不应被假定继续有效；恢复后用户重新登录是可接受且更安全的默认；
- 数据库备份不包含 Storage 文件本体；
- backup 不进入 GitHub。

Pilot 默认目标：**RPO ≤ 一个教学日**。

必须恢复到新的非 Production Project，并跑 smoke + RLS 负面测试。

---

# 13. GitHub / Work / Luna 审计：通过

## GitHub

仓库现在已 Private。

零额外付费阶段：
- Work / Codex 禁止直推 main；
- branch + Draft PR；
- 有真实执行证据才合并；
- 人工合并；
- Foundation 建议 Squash merge。

GitHub 设置仍建议人工确认：
- Template repository 关闭；
- Wiki 关闭；
- Actions budget 超额停止。

## ChatGPT Work / Codex

- GitHub 是代码事实源；
- migrations 是 schema 事实源；
- 聊天记忆不是代码事实源；
- 一个可验收目标通常一条 Work 会话 + 一个 PR；
- Agent 不能运行命令时必须明确“未执行”。

## Luna / Max

不把“LunaMax”写成稳定 API model id。

Max / 高推理优先：
- RLS；
- migration；
- Auth / Session；
- 事务 / 并发 / 幂等；
- 安全审计；
- Milestone 终审。

机械 UI / 重命名 / 已有模式 CRUD 不需要无脑 Max。

---

# 14. 明确不做

V1 不做：
- 收费 / 课消 / 招生 CRM；
- 完整排课 ERP；
- 大型题库；
- 学情综合分 / 预测；
- 复杂 offline-first / CRDT；
- 同时维护 Password / OTP / Magic Link 多套主登录；
- Realtime 作为正确性前提；
- 公开自助 SaaS 注册；
- AI 自动修改正式学情；
- 为“永久免费”牺牲备份、权限、隐私或恢复能力。

---

# 15. Foundation Freeze Checklist

## 已完成

- [x] 产品边界收敛
- [x] V1 / V1.1 边界统一
- [x] Auth / Membership / Role / Assignment 语义统一
- [x] Case 状态与 Next Action 不变量统一
- [x] 数据模型与 Excel 映射统一
- [x] 机构时区进入基础模型
- [x] 设备端 Session / Draft 安全边界明确
- [x] Realtime V1 后置
- [x] zero-cost Pilot 边界明确
- [x] disaster recovery runbook
- [x] Work / Codex / GitHub 事实源规则
- [x] Open-source 借鉴边界
- [x] 仓库已 Private
- [x] 最新分支没有落后 main
- [x] 当前没有 CI green 可声称这一事实已明确

## 仍需人工 / Phase 0 完成

- [ ] Template repository / Wiki 设置人工确认
- [ ] GitHub Actions zero-overage budget 人工确认
- [ ] Flutter 双平台真正初始化并 build
- [ ] Local Supabase 从空库 migrations + seed 重建
- [ ] live-session / RLS 攻击式测试
- [ ] secure Session storage 双平台验证
- [ ] encrypted draft 双平台验证
- [ ] Remote Dev 无代理网络 / Region 测试
- [ ] DB + Storage 实际 restore drill

这些不是继续写 Foundation 文档能证明的事项。

---

# 16. 第一条 Phase 0 验收链

```text
Private repo
→ Flutter Windows / Android build
→ Local Supabase db reset
→ organization.time_zone
→ RLS / live-session tests
→ secure Session + Startup Gate
→ encrypted drafts
→ Remote Dev 无代理 network / region
→ provision teacher
→ onboarding expiry
→ set new password
→ global sign-out
→ old JWT direct API denied
→ new login active
→ admin reset
→ old access denied
→ DB + Storage backup / restore
```

这条链真正跑通以后，才开始大量开发 Student / Learning Case / Lesson / Today UI。

---

# 最终判断

**Foundation v0.3 可以停止继续“理论扩写”。**

如果最终 PR diff 和 PR 描述同步到本文件当前规则，没有新增硬冲突，就可以结束 Foundation 设计阶段。之后质量提升必须来自 Phase 0 的真实执行证据，而不是继续堆文档。
