# 开发路线

## 总原则

**先证明关键风险可控 → 再搭业务底座 → 先完成一条垂直闭环 → 最后扩功能。**

> **Phase 0B.0 provider / production hard boundary**
>
> P0 Gate A / B 的 compatibility/security spike 已完成开发验证，但不等于 Production provider、正式业务 migration 或真实数据授权。
>
> 在 provider、region、identity 与 session strategy 最终冻结，并完成安全处置、备份恢复、真实设备 / 网络验收和 Go / No-Go 之前，只允许使用虚构或严格脱敏数据。


不按页面数量衡量进度。V1 内部 Pilot 默认不额外购买服务器、数据库套餐、SMTP、域名、短信、AI API、CI 或 Work / Codex credits。

---

# Phase 0｜工程与风险验证

目标：在任何真实学生数据进入前，先以 Supabase reference candidate 验证 Windows + Android + 零成本认证 + 本地安全 + 恢复方案；Supabase 不是无条件 production provider，正式 production business migrations/Auth/RLS/CRUD 仍受 P0 Gate A/B 阻止。

## 0A. GitHub / ChatGPT 云端底座

- [x] GitHub repository 已改为 Private
- [ ] 创建 ChatGPT Project：`Xueqing｜学情闭环开发`
- [ ] 使用兼容 Work 的 memory 配置
- [x] GitHub 是代码事实源的规则已写入 AGENTS / docs
- [x] 一目标 / 一 Work 会话 / 一 branch / 一 PR 的开发规则已定义
- [x] Work / Codex 禁止直推 main 的规则已定义
- [x] GitHub Free private 缺少付费级强制保护的流程替代已记录
- [x] Wiki 已关闭
- [x] Template repository 已关闭
- [x] Actions zero-overage budget 已做明确决策：用户选择暂不设置，作为已知账户级计费风险接受，不作为 Foundation / Phase 0A 阻塞项
- [x] 零额外付费阶段不购买 extra Work / Codex credits 的规则已定义

### CI 成本控制

因 zero-overage budget 未配置，仓库通过执行策略降低误耗风险：
- 普通 PR / main：Linux 轻量 format / lockfile / analyze / test；
- Windows / Android native build：Milestone / Release / 手动；
- 不用 larger runner；
- 不在 PR + branch push 上重复执行同一轻量 workflow。

### 验收
- 新任务只靠 GitHub + AGENTS + docs 能理解当前规则；
- PR 没执行证据不合并；
- 不依赖付费 branch protection 才能遵守流程。

---

## 0B. Flutter 正式工程

> 文档映射：本仓库当前执行任务书中的 **Phase 0A** 对应本节 Flutter 工程基线；后续 Local Supabase 属于 Phase 0B。保留原有 0A / 0B / 0C 编号以避免 Foundation 文档历史引用断裂。

### Phase 0A 当前实现状态

- [x] Flutter project metadata、Android 与 Windows platform source 已加入既有分支
- [x] `xueqing` package 与 `com.xueqing.app` application id 已固定
- [x] typed environment、bootstrap、router、theme、responsive、error / loading foundation 已加入
- [x] 最小 unit / widget tests 与轻量 GitHub Actions workflow 已加入
- [x] 提交 `pubspec.lock`
- [x] CI 在 `flutter pub get` 后验证 lockfile 没有未提交变化
- [x] typed AppConfig / Development / Production 配置
- [x] 以 Bootstrap / Widget 边界保持轻量；业务 data / service / repository 在需要时再出现
- [x] 基础 theme / router / error boundary / logging
- [x] Widget 中没有 Supabase 表查询、权限或事务逻辑
- [x] Phase 0A 没有提前开发 Student / Case / Lesson / Today 正式页面
- [x] 最终 UX/UI 明确后置到 Phase 0A.5

### 真实执行证据

- [x] Flutter `3.47.1` / Dart `3.13.1` GitHub Actions 工具链
- [x] `flutter pub get`：PASS / EXECUTED
- [x] lockfile consistency：PASS / EXECUTED
- [x] format：PASS / EXECUTED
- [x] `flutter analyze`：PASS / EXECUTED
- [x] `flutter test`：PASS / EXECUTED
- [x] Android `flutter build apk --debug`：PASS / EXECUTED，run `33606216237`
- [x] Windows `flutter build windows --debug`：PASS / EXECUTED，run `33606216237`
- [x] 最终轻量 CI：run `33606400363` PASS

详见 `docs/PHASE0A_EXECUTION_RECORD.md`。

### Phase 0A 完成后

先做本 PR 最终审计；通过后进入 **Phase 0A.5 UX/UI Design Foundation**，不是立即批量开发业务页面。

---

## Phase 0B.0（原 0C）. Local Supabase Compatibility / Security Spikes

### 当前 Gate 证据

以下 `[x]` 表示当前开发线或 CI 已有可复核证据，不表示 Production 已获批：

- [x] P0 Gate A — Auth Identity Portability（PR #17，18/18 identity contract assertions）
- [x] P0 Gate B — Revoked Session / Old Token（PR #15 remote harness + device evidence）
- [x] 业务身份解耦契约已由 ADR-046 冻结
- [x] `supabase/`、migrations、fictional seed、DB / RLS / function tests 已在开发线建立并通过冷重建
- [x] workspace read model、custom case types、organization leadership / invites、invitation expiry / re-invite 已在开发线建立；远端当前应用到 migration J
- [x] 普通业务的 live-session / membership / role / assignment 授权回归已存在
- [x] PR #28 增加 invitation acceptance 的 live-session guard；SQL 冷重建和 pgTAP 已通过，K migration 仍待审阅、合并和远端应用
- [x] PR #29 增加 production endpoint 配置 / HTTPS fail-closed 和开发入口隔离；Flutter CI 已通过
- [ ] PR #28 → PR #29 审阅、合并和远端 migration drift 复核
- [ ] 逐函数复核 SECURITY DEFINER、开启 leaked password protection、解释 3 个 intentional no-policy 表
- [ ] 根据真实规模虚构数据和执行计划决定是否补外键索引；不机械处理 38 个 Advisor INFO
- [ ] Production provider / region / session strategy 最终冻结
- [ ] 无代理机构网络、Storage、backup/restore 与 Go/No-Go
### 第一批基础 schema（以当前 migrations / 实际 schema 名称为准）
- [x] `app_users` + `identity_links` provider-neutral identity
- [x] `organizations` + `organizations.time_zone`（IANA timezone）
- [x] `organization_memberships` + `membership_roles`
- [x] `subjects` + `organization_subjects`
- [x] `membership_subject_scopes`
- [x] `student_enrollments`
- [x] `student_subject_profiles`
- [x] `student_teacher_assignments`
- [ ] Production schema completeness、迁移冻结和正式数据授权

### 时间语义必测
- [ ] system timestamps 保存 UTC
- [ ] Today 按 organization timezone
- [ ] action due / overdue 按 organization timezone
- [ ] lesson 所属业务日期按 organization timezone
- [ ] 设备时区错误不改变机构业务日期
- [ ] 跨午夜边界测试

### 授权必测
- [ ] unauthenticated
- [ ] Auth User 无 membership
- [ ] revoked session
- [ ] onboarding
- [ ] active
- [ ] disabled
- [ ] cross-org
- [ ] same-org / no assignment
- [ ] cross-subject

### live-session 性能
- [ ] helper 不在结果每行无意义重复昂贵求值
- [ ] 相关列有合理 index
- [ ] Today / Student / Case 核心查询检查执行计划

---

## 0D. 设备端安全 Spike

### Session
- [ ] Supabase custom `LocalStorage`
- [ ] Windows OS secure storage
- [ ] Android OS secure storage
- [ ] Session / Refresh Token 不落普通 Preferences
- [ ] Password 不本地持久化
- [ ] 重启后 Session 正确恢复
- [ ] logout / reset / disabled 后本地状态正确清理

### Startup Authorization Gate
- [ ] Auth init
- [ ] Session validity / refresh
- [ ] live Session
- [ ] membership state
- [ ] current organization
- [ ] 以上完成前不挂业务 Shell
- [ ] expired / revoked / disabled Session 不闪现业务页

### Encrypted Draft
- [ ] user / organization scope
- [ ] ciphertext at rest
- [ ] key 在 OS secure storage
- [ ] key 与密文分离
- [ ] TTL
- [ ] sync success 删除
- [ ] account switch 不串数据
- [ ] logout 时明确同步 / 丢弃
- [ ] disabled / revoked 后清理或锁定
- [ ] 草稿不含 Token / Password

---

## 0E. Free Remote Development + Region Spike

- [ ] 创建一个 Supabase Free Remote Development，仅使用虚构数据
- [ ] 记录初始 region
- [ ] Windows + Android 连接同一后端
- [ ] 实际机构 Wi-Fi 测试
- [ ] 普通移动网络测试
- [ ] **无代理 / VPN**测试
- [ ] Password Auth
- [ ] Data API CRUD
- [ ] Storage upload / download
- [ ] Edge Functions
- [ ] 网络切换 / 恢复
- [ ] 若质量不合格，重建 Dev 到另一 APAC region 重测
- [ ] 在 P0 Gate A/B 后完成 gated Production region 决策并有测试记录

> Gated Production Pilot 在 region/network 结论稳定、P0 Gate A/B 通过且 provider/identity/session strategy 冻结前不创建。

---

## 0F. 零成本账号开通 Spike

### `provision_member`
- [ ] Auth Admin createUser / 受控处理
- [ ] 强随机临时密码
- [ ] membership = onboarding
- [ ] `onboarding_expires_at`
- [ ] 临时密码只显示一次
- [ ] 不写 DB / log / audit
- [ ] Auth 成功 / DB 失败有恢复路径
- [ ] 响应成功但客户端超时 → delivery unknown → reissue
- [ ] V1 同 user 第二机构 onboarding / active 被拒绝

### `complete_member_onboarding`
- [ ] onboarding 未过期
- [ ] 更新当前用户新密码
- [ ] global sign-out 所有 Sessions
- [ ] sign-out 成功后才 membership → active
- [ ] 强制用新密码重新登录
- [ ] 保存旧 Access Token，接管后直接请求业务 API，live-session guard 必须拒绝

### `reset_member_credential`
- [ ] **先 membership → onboarding**
- [ ] 再更新临时密码
- [ ] 新 expiry
- [ ] 响应丢失走 reissue
- [ ] 旧业务访问立即拒绝

### 管理员恢复
- [ ] 两个 active org_admin；或
- [ ] Project Owner break-glass 已演练
- [ ] 普通流程不能停用最后一个可恢复 org_admin

---

## 0G. 保存可靠性

- [ ] 未保存 / 保存中 / 已保存 / 失败 UI
- [ ] 网络失败不清空输入
- [ ] 简单 insert 重试复用 UUID
- [ ] DB command operation id / 幂等
- [ ] credential command 不保存明文来做幂等
- [ ] 请求成功但响应丢失场景
- [ ] 超时后可查询最终状态
- [ ] 云端未确认前不伪装“已保存”

---

## 0H. CI 基线

### 每个普通 PR
- [x] Flutter format
- [x] `pubspec.lock` consistency
- [x] Flutter analyze
- [x] Flutter unit / widget tests
- [x] Local DB / migration / RLS tests（开发线 CI 已执行；Production 仍未授权）
- [ ] basic secret / static checks

### Milestone / Release / 手动
- [x] Windows debug build 基线已验证
- [x] Android debug build 基线已验证
- [ ] release / integration matrix（后续 Milestone / Release）

### 成本边界
- [x] 不用 larger runner
- [x] native build workflow 改为手动触发
- [x] 普通 Phase 0A PR 不再同时用 branch push + pull_request 重复跑同一轻量检查
- [x] Actions zero-overage budget：用户明确选择不设置，风险已记录并接受

---

## 0I. Recovery Spike

### Database
- [ ] `roles.sql`
- [ ] `schema.sql`
- [ ] `data.sql`
- [ ] migration history（需要时）

### Auth
- [ ] Auth user / identity 按当前 Supabase 官方流程恢复
- [ ] 恢复环境实际管理员登录
- [ ] 恢复环境实际普通教师登录
- [ ] 不假定旧 JWT / Session 可继续使用

### Storage / Config
- [ ] Storage objects + manifest
- [ ] checksum / object path 校验
- [ ] Project config checklist（Auth / Realtime / Extensions / Edge Functions / Secret names）
- [ ] 新项目 Publishable Key / client config 更新

### Drill
- [ ] 加密离站保存
- [ ] 从实际 backup 恢复到新的非 Production 环境
- [ ] smoke test
- [ ] RLS negative tests
- [ ] Pilot RPO 目标 ≤ 一个教学日，机构确认可接受

详见 `DISASTER_RECOVERY.md`。

---

## Phase 0 总验收

- [ ] 新环境可从 GitHub 启动
- [x] Flutter Windows / Android 可真实 build
- [x] Local DB 可从空库重建（开发线 CI）
- [ ] organization timezone 行为正确
- [ ] revoked Session 业务访问立即拒绝
- [ ] live-session guard 性能可接受
- [ ] onboarding / active / disabled 边界正确
- [ ] onboarding expiry / reissue / response-loss 可恢复
- [ ] Session secure storage 双平台通过
- [ ] Startup Gate 无业务闪现
- [ ] encrypted draft 通过
- [ ] Region 经真实无代理网络验证
- [ ] DB + Auth + Storage 实际恢复通过
- [ ] 仓库无真实数据与 Secret

**Phase 0 未通过，不进入真实学生数据，也不批量开发业务页面。**

---

# Milestone 1｜机构、成员与租户隔离

目标：两名虚构教师用独立账号加入同一机构，另一机构严格不可见。

- [ ] profiles / organizations / roles
- [ ] organization timezone
- [ ] memberships / membership_roles
- [ ] bootstrap 首位 org_admin
- [ ] provision / onboarding / reset / disable
- [ ] current organization context
- [ ] live-session + active membership RLS
- [ ] 单 Auth User V1 跨机构 active / onboarding 禁止
- [ ] 两名 org_admin / break-glass

### 验收
1. A 机构管理员开通教师甲、乙；
2. 两人完成安全接管并重新登录；
3. 两人共同访问 A 机构授权数据；
4. B 机构数据完全不可见；
5. reset / disable 后旧 JWT 直接请求也失败；
6. 设备时区变化不改变 A 机构 Today 的业务日期规则。

---

# Milestone 2｜学生统一主档案与关系历史

- [ ] students（含 merged）
- [ ] academic_terms / student_enrollments
- [ ] subjects / organization_subjects
- [ ] 轻量 taxonomy + “其他 / 暂未分类”
- [ ] student_subject_profiles
- [ ] student_teacher_assignments
- [ ] student_staff_assignments
- [ ] active lead 唯一性
- [ ] 学生搜索 / 重复提示
- [ ] 当前 / 历史负责人
- [ ] 教师交接
- [ ] student merge record

验收：同一真实学生只有一个 student_id；升年级 / 换老师不丢历史；学管不伪装成学科教师。

---

# Milestone 3｜第一条完整学情闭环

- [ ] learning_cases
- [ ] case_events append-only
- [ ] evidence / interventions / assessments
- [ ] case_actions
- [ ] `new` 10–20 秒草稿
- [ ] confirm / transition / reopen
- [ ] expected_version
- [ ] command 幂等

### 行动不变量
- [ ] confirmed / intervening / pending_verification / stable 都有 pending primary action
- [ ] 暂缓使用 `review + due_at`；pause_reason 只解释
- [ ] closed 无 pending primary action
- [ ] passed 不自动 stable / closed

### 端到端

```text
new
→ confirm + evidence + primary action
→ intervention
→ verify assessment
→ stable + review action
→ closed
→ recurrence → reopen 原 Case
```

---

# Milestone 4｜课程与“今日”

> 不做完整排课系统。

- [ ] lessons / lesson_students
- [ ] 从学生 / Today 快速开始课程
- [ ] Today：到期 / 逾期 action、无日期待安排 action、待验证、重点 Case
- [ ] Today 使用 organization timezone
- [ ] 课前遗留摘要
- [ ] 课中 action / intervention / assessment / new
- [ ] `complete_lesson` 事务命令
- [ ] 30–60 秒课后流程
- [ ] encrypted draft / network recovery
- [ ] 长期未整理 new 提醒

验收：2 教师 + 5 虚构学生连续模拟一周，课后中位 ≤60 秒，断网不丢，暂停 Case 不失踪，设备时区错误不改变 Today 边界。

---

# Milestone 5｜权限、审计、交接与治理加固

- [ ] 本科详细权限
- [ ] 跨学科有限共享
- [ ] advisor 综合视角
- [ ] subject_lead
- [ ] audit_logs
- [ ] live-session helper 性能 / 安全复审
- [ ] Storage RLS / signed URL 审计
- [ ] handoff
- [ ] merge_students
- [ ] 负面权限自动化测试

---

# Milestone 6｜内部发行与可运维性

- [ ] Windows 内部分发 / 升级
- [ ] Android 签名包 / 升级
- [ ] 签名密钥备份
- [ ] Production region / network final check
- [ ] Free usage checklist
- [ ] DB + Storage 周期备份
- [ ] Auth / DB / Storage 恢复演练
- [ ] 最低支持客户端版本
- [ ] Production migration + smoke test（仅 P0 Gate A/B、provider/region/identity/session strategy 与 Go/No-Go 全部通过后）
- [ ] 故障应急

---

# V1｜机构内部 Pilot

只有 Phase 0–6 核心门槛达成后才接入真实数据。

教师导航：
- 今日
- 学生
- 课程
- 学情

核心成功标准：
- 两位教师共同管理同一学生且权限边界正确；
- 快速记录真实可用；
- 所有正式未关闭 Case 有下一步；
- 网络 / 设备异常不丢、不泄露；
- 教师交接不丢历史；
- DB / Auth / Storage 可恢复；
- Free Pilot 的成本风险处于用户明确接受且可监控的范围。

---

# V1.1｜家校与阶段输出

- guardians / student_guardians
- parent_communications
- 周度自动摘要
- report draft / finalized snapshot
- 家校 / 报告一级入口

# V1.5｜机构协作与教学洞察

- observations
- 跨学科综合观察
- 长期 / 超期提醒
- 高频问题分析
- taxonomy 轻量治理
- 管理端教学异常

不做教师填表量排行榜。

# V2｜教研资产与 AI 副驾驶

- 自然语言转结构化 draft
- 相似 / 重复 Case 提示
- 自动摘要
- 家校反馈草拟
- 同类方案检索
- AI 来源 + 人工确认

# Schema 稳定后｜Excel 导入

- 预览
- 字段 / 分类映射
- 学生查重
- 验证
- 导入报告
- 回滚

# 仍不做

- 收费 / 课消 / 招生 CRM
- 完整排课 ERP
- 大型题库
- 学情健康分 / 成绩预测
- 家长 / 学生独立 App（V1）
- Google Docs 式协同
- 复杂 offline-first / CRDT
- 多套主登录方式并存
- 庞大知识图谱
