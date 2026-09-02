# Foundation v0.3｜最终全面审计与冻结结论

> 这是 Foundation 冻结前的最终审计记录。目的不是继续增加理论，而是区分“设计已收敛”和“必须由 Phase 0 真实执行证明”的事项。

## 最终结论

**Foundation v0.3 已达到 Freeze Candidate。**

继续提高质量的主要手段应切换为：Flutter build、Supabase migrations / RLS tests、旧 JWT 攻击测试、secure Session、encrypted draft、真实机构网络 / Region 测试，以及 DB + Auth + Storage restore drill。

没有真实执行证据的部分不得写成“已经验证”。

---

# 1. GitHub / PR 当前事实

- repository：`qbjsdsb/xueqing`
- visibility：**Private**
- Wiki：**已关闭**
- Template repository：**仍开启（`is_template=true`）**
- Foundation branch：`review/foundation-v0.3`
- PR #1：open + Draft
- branch 相对 `main`：ahead，behind = 0
- 当前没有正式 Flutter / Supabase workflow run，因此**没有 CI green 可声称**
- Foundation 最终建议 Squash merge

### 仍需人工处理的 GitHub 设置

- [ ] 关闭 **Template repository**
- [x] Wiki 已关闭
- [x] repository 已 Private
- [ ] 确认 GitHub Actions billing budget 为超额停止

Template 开关不影响代码正确性，但本项目不是模板，继续开启没有收益，容易造成后续误操作。

---

# 2. 产品审计：通过

V1 继续围绕：

```text
Student continuous profile
→ Learning Case
→ Evidence
→ Intervention
→ Assessment
→ Next Action
→ Lesson / Today
```

冻结边界：
- V1 主导航：Today / 学生 / 课程 / 学情；
- 家校 / 报告进入 V1.1；
- lesson 不是收费 / 课消 / 完整排课 CRM；
- 周度、阶段、顽固问题从事实派生，避免第二台账；
- AI 只生成 draft / 建议，不成为正式事实源；
- 管理端不以“填表数量”作为核心 KPI。

### 正式 Case 永远有下一步

- `new` 可没有 action；
- `confirmed / intervening / pending_verification / stable` 必须有 pending primary action；
- 暂缓 / 观察 = `review + due_at`；
- `pause_reason` 只解释原因；
- `closed` 无 pending primary action。

---

# 3. 时间语义审计：已修正

最终审计补入：`organizations.time_zone`（IANA timezone，例如 `Asia/Shanghai`）。

冻结规则：
- 系统事件时间保存 UTC / `timestamptz`；
- Today、action 到期 / 逾期、lesson 所属业务日期、周度和 report period 按 organization timezone 解释；
- 不直接相信手机 / 电脑设备时区；
- V1 不做 campus 独立时区。

这避免“教师出差 / 设备时区错误”污染 Today 和统计边界。

---

# 4. Auth / Session 审计：设计通过，Phase 0 必须实测

最终账号接管：

```text
provision_member
→ onboarding + onboarding_expires_at
→ 临时密码登录
→ 设置新密码
→ global sign-out all Sessions
→ membership active
→ 强制重新登录
```

reset：

```text
先 membership → onboarding
→ 再更新临时密码
→ 刷新 onboarding expiry
→ 重新完整接管
```

Credential 响应丢失：reissue 新 secret，不持久化旧明文。

普通学生业务至少要求：

```text
JWT session_id 对应 live auth.sessions
+ membership active
+ organization
+ role / capability
+ assignment（如需要）
```

### Phase 0 必测

- 保存旧 JWT；
- complete onboarding / reset / disable 后直接请求业务 API；
- 即使旧 Access Token 自身尚未过 `exp`，也必须被拒绝。

### 性能边界

live-session guard 不能以“安全”为名写成每行重复昂贵查询。Phase 0 要检查 helper、索引和 Today / Student / Case 核心查询执行计划。若成为瓶颈，通过 ADR 优化实现，不静默删除安全条件。

---

# 5. V1 多租户身份边界：通过

数据库从第一天支持多个 organization，但 V1 不允许同一个 Auth User 同时跨机构 onboarding / active。

原因：Password 属于全局 Auth User，单一机构 org_admin 的 reset 不能影响另一机构。

因此：
- 同一 user 同一时点最多一个 onboarding / active membership；
- 其他 organization 只保留 disabled 历史；
- provision 发现另一机构非 disabled membership 时拒绝；
- V1 不做跨机构账号切换器。

未来确有需求，再用中央身份恢复 / OTP / SSO 等方案并新增 ADR。

---

# 6. 管理员恢复：设计通过，待演练

真实 Pilot 至少满足一个：
- 两名独立可信 active org_admin；
- 或经过演练的 Project Owner break-glass。

普通 UI 不能停用最后一个可恢复 org_admin。

---

# 7. Flutter 设备安全：设计通过，Phase 0 必须实测

### Session
- Supabase custom `LocalStorage`；
- Windows / Android OS secure storage；
- Password 不本地持久化。

### Startup Gate
业务 Shell 只能在 Session valid / refreshed、live Session、active membership、current organization 全部解析后挂载。

### Encrypted Draft
跨重启敏感草稿：
- encrypted at rest；
- key 在 OS secure storage；
- user / org scope；
- TTL；
- sync 后删除；
- account switch 不串数据；
- logout / disabled 有明确处理；
- 不存 Token / Password。

---

# 8. Realtime：V1 后置

V1 学生敏感表默认不启用 Realtime，也不让业务正确性依赖 Realtime。

页面进入、保存后、App resume、手动刷新必须足够保证正确性。

以后开启 Realtime 前新增 ADR，并测试 revoked Session / reconnect / cross-org。

---

# 9. Storage：设计通过，真实文件前验证

- private bucket；
- `storage.objects` RLS 与 organization / assignment 一致；
- signed URL 只在授权后生成且短 TTL；
- signed URL 不进日志 / 长期缓存；
- 文件大小 / 类型限制；
- DB metadata 与 object 生命周期一致；
- Storage 文件单独 backup。

必须有 cross-org 直接下载攻击测试。

---

# 10. Region / 中国大陆网络：必须真实验证

Production region 不提前指定。

Remote Development 只用虚构数据，在实际机构 Wi-Fi、普通移动网络、无代理 / VPN 环境测试 Auth / Data API / Storage / Edge Functions / 网络恢复。不合格就换 Dev region 重测，结论稳定后才创建 Production。

Region 选择不是未成年人数据驻留 / 跨境合规结论，后者单独评估。

---

# 11. 数据模型审计：通过

已稳定：
- Student 不因学科 / 教师 / 年级重复；
- enrollment 保存年级 / 班级 / 校区历史；
- teacher 与 advisor / homeroom assignment 分开；
- Case = current snapshot + append-only events；
- Evidence / Intervention / Assessment / Action 分事实；
- Lesson 一对多，不重复 Case 结果；
- merged student 保留 mapping；
- credential secret 不进入 operation receipt；
- organization timezone 是业务日期事实源。

真正 migration 仍需实现约束：cross-org consistency、V1 单 user 跨机构双活禁止、active owner / assignee、primary action、paused review due_at、非法状态跳转等。

---

# 12. Disaster Recovery：设计通过，必须实际演练

完整恢复集：
- roles；
- schema；
- data；
- 必要 migration history；
- Auth user / identity 按恢复当日官方流程恢复并实际登录验证；
- Storage objects + manifest；
- Auth / Realtime / Extensions / Edge Functions / Secret names / Project config checklist；
- Git 中 migrations / Function source。

重要边界：
- 新 Project 的 JWT / API 配置可能变化，不假定旧 Token 有效；
- DB backup 不包含 Storage 文件本体；
- backup 永不进入 GitHub；
- “文件存在”不算完成，必须 restore 到新的非 Production Project 并跑 smoke + RLS negative tests。

Pilot 默认 RPO ≤ 一个教学日。不能接受则重新评估免费基础设施。

---

# 13. GitHub / Work / Luna：通过

- GitHub = code truth；
- migrations = DB structure truth；
- chat memory 不是代码事实源；
- 一个可验收目标通常一条 Work 会话 + 一个 PR；
- Work / Codex 禁直推 main；
- Agent 没真实执行命令必须标注未执行；
- Luna / Max 高推理优先 RLS、migration、Auth / Session、事务、并发、安全、Milestone 终审；
- 机械 UI / 改名 / 重复 CRUD 不无脑 Max；
- 不把“LunaMax”写成稳定 API model id。

---

# 14. 明确不做

V1 不做：收费 / 课消 / 招生 CRM、完整排课 ERP、大型题库、学情综合分 / 预测、复杂 offline-first / CRDT、多套主登录方式并存、Realtime 作为正确性前提、公开自助 SaaS 注册、AI 自动修改正式学情。

---

# 15. Freeze Checklist

## Foundation 已完成

- [x] 产品边界统一
- [x] V1 / V1.1 边界统一
- [x] Auth / Membership / Role / Assignment 语义统一
- [x] Case 状态与 Next Action 不变量统一
- [x] 数据模型 / Excel 映射统一
- [x] organization timezone 进入基础模型
- [x] Session / Draft 设备安全边界明确
- [x] Realtime V1 后置
- [x] zero-cost Pilot 边界明确
- [x] disaster recovery runbook
- [x] Work / Codex / GitHub 事实源规则
- [x] open-source 借鉴边界
- [x] repository Private
- [x] Wiki 关闭
- [x] branch behind main = 0
- [x] 当前无 CI green 可声称这一事实明确
- [x] README / ROADMAP / SECURITY / RISKS / PR 描述同步到最新规则

## 仍需人工设置

- [ ] 关闭 Template repository
- [ ] 确认 Actions zero-overage budget

## Phase 0 才能证明

- [ ] Flutter 双平台 build
- [ ] Local Supabase 从空库重建
- [ ] time zone 边界测试
- [ ] live-session / RLS 攻击测试
- [ ] live-session 性能
- [ ] secure Session storage
- [ ] Startup Gate
- [ ] encrypted draft
- [ ] Remote Dev 无代理网络 / Region
- [ ] DB + Auth + Storage restore drill

这些事项不能通过继续写 Foundation 文档获得真实证据。

---

# 16. Phase 0 第一条验收链

```text
Flutter Windows / Android build
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
→ DB + Auth + Storage restore drill
```

## 最终判断

除 **Template repository** 与 **Actions budget** 这两个 GitHub 设置项外，Foundation 设计审计已经没有继续扩写理论的高价值空间。

完成最后只读 diff / keyword scan 后，如无新的硬冲突，Foundation v0.3 应冻结并进入 Phase 0，而不是继续增加架构文档。
