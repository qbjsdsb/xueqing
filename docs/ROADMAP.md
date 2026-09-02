# 开发路线

## 总原则

**先证明关键风险可控 → 再搭业务底座 → 先完成一条垂直闭环 → 最后扩功能。**

不按页面数量衡量进度。V1 内部 Pilot 默认不额外购买服务器、数据库套餐、SMTP、域名、短信、AI API、CI 或 Work/Codex credits。

---

# Phase 0｜工程与风险验证

目标：在任何真实学生数据进入前，证明 Windows + Android + Supabase + 零成本认证 + 本地安全 + 恢复方案可以成立。

## 0A. GitHub / ChatGPT 云端底座
- [ ] repo 改 Private
- [ ] 创建 ChatGPT Project `Xueqing｜学情闭环开发`
- [ ] 使用兼容 Work 的 memory 配置
- [ ] GitHub 是代码事实源
- [ ] 一目标 / 一 Work 会话 / 一 branch / 一 PR
- [ ] Work/Codex 禁止直推 main
- [ ] 记录 GitHub Free private 无强制 branch protection 的流程性替代
- [ ] Actions budget 启用 **Stop usage when budget limit is reached**
- [ ] 不购买 extra Work/Codex credits

### 验收
- 新任务只靠仓库即可理解当前规则；
- PR 没执行证据不能合并；
- 不依赖平台付费 branch protection 才能遵守流程。

---

## 0B. Flutter 正式工程
- [ ] 用当前 stable Flutter 初始化 Windows + Android
- [ ] 提交 `pubspec.lock`
- [ ] typed AppConfig / Development / Production 配置
- [ ] View / ViewModel / Repository / Service 职责分层
- [ ] format / analyze / test 基线
- [ ] 参考 Flutter 官方 `compass_app` 的多环境/Repository/Service/测试
- [ ] 不在 Widget 散落 Supabase 表查询

---

## 0C. Local Supabase
- [ ] 初始化 `supabase/`
- [ ] migrations
- [ ] fake seed
- [ ] DB/RLS/function tests
- [ ] `supabase db reset` 从空库重建
- [ ] 评估 `supabase_testing` 用于 Flutter Service 测试
- [ ] live-session helper Spike：JWT `session_id` ↔ `auth.sessions`

### 必测授权
- [ ] unauthenticated
- [ ] no membership
- [ ] revoked session
- [ ] onboarding
- [ ] active
- [ ] disabled
- [ ] cross-org
- [ ] same-org/no-assignment
- [ ] cross-subject

---

## 0D. 设备端安全 Spike
- [ ] Supabase custom `LocalStorage`
- [ ] Windows OS secure storage
- [ ] Android OS secure storage
- [ ] Session/Refresh Token 不落普通 Preferences
- [ ] Password 不持久化
- [ ] App Startup Authorization Gate
- [ ] expired/revoked/disabled 本地 Session 不闪现业务页

### 加密草稿
- [ ] user/org scope
- [ ] ciphertext at rest
- [ ] key 在 OS secure storage
- [ ] TTL
- [ ] sync success 删除
- [ ] account switch 不串数据
- [ ] logout 同步/丢弃提示
- [ ] disabled/revoked 后清理/锁定
- [ ] 草稿不含 Token/Password

---

## 0E. Free Remote Development + Region Spike
- [ ] 创建一个 Supabase Free Dev Project，仅虚构数据
- [ ] 记录初始 region
- [ ] Windows + Android 同后端
- [ ] 实际机构 Wi‑Fi 测试
- [ ] 普通移动网络测试
- [ ] **无代理/VPN**测试
- [ ] Password Auth
- [ ] Data API CRUD
- [ ] Storage upload/download
- [ ] Edge Functions
- [ ] 网络切换/恢复
- [ ] 若质量不合格，重建 Dev 到另一 APAC region 重测
- [ ] 最终 Production region 决策有记录

> Production Pilot 在 region/network 结论稳定前不创建。

---

## 0F. 零成本账号开通 Spike

### Schema
- [ ] profiles
- [ ] organizations
- [ ] roles
- [ ] organization_memberships(status onboarding/active/disabled)
- [ ] `onboarding_expires_at`
- [ ] membership_roles

### `provision_member`
- [ ] Auth Admin createUser/受控处理
- [ ] 强随机临时密码
- [ ] membership=onboarding
- [ ] 临时密码只显示一次
- [ ] 不写 DB/log/audit
- [ ] Auth 成功/DB 失败恢复
- [ ] 响应成功但客户端超时 → credential delivery unknown → reissue

### `complete_member_onboarding`
- [ ] onboarding 未过期
- [ ] 更新当前用户密码
- [ ] global sign-out 所有 Sessions
- [ ] sign-out 成功后才 membership→active
- [ ] 强制新密码重新登录
- [ ] 保存旧 Access Token，接管后直接请求业务 API，live-session guard 必须拒绝

### `reset_member_credential`
- [ ] **先 membership→onboarding**
- [ ] 再更新临时密码
- [ ] 新 expiry
- [ ] 响应丢失走 reissue
- [ ] 旧业务访问立即拒绝

### 管理员恢复
- [ ] 两个 active org_admin；或
- [ ] Project Owner break-glass 已演练

---

## 0G. 保存可靠性
- [ ] 未保存 / 保存中 / 已保存 / 失败 UI
- [ ] 网络失败不清空输入
- [ ] 简单 insert 重试复用 UUID
- [ ] DB command operation id / 幂等
- [ ] credential command 不保存明文来做幂等
- [ ] 请求成功但响应丢失场景

---

## 0H. CI 基线

### 每 PR
- [ ] format
- [ ] analyze
- [ ] Flutter unit tests
- [ ] Local DB/migration/RLS tests
- [ ] secret/basic static checks

### Milestone / Release 才跑
- [ ] Windows build
- [ ] Android build
- [ ] 重 integration matrix

- [ ] 不用 larger runner
- [ ] artifact retention 短
- [ ] Actions 零超额 budget 生效

---

## 0I. Recovery Spike
- [ ] `roles.sql`
- [ ] `schema.sql`
- [ ] `data.sql`
- [ ] migration history（需要时）
- [ ] Storage objects + manifest
- [ ] Project config checklist（Auth/Realtime/Extensions/Secrets）
- [ ] 加密离站保存
- [ ] 从实际备份恢复到非 Production 新环境
- [ ] smoke test
- [ ] Pilot RPO 目标 ≤ 一个教学日，机构确认可接受

详见 `DISASTER_RECOVERY.md`。

---

## Phase 0 总验收
- [ ] 新环境可从 GitHub 启动
- [ ] Local DB 可从空库重建
- [ ] revoked Session 业务访问立即拒绝
- [ ] onboarding/active/disabled 边界正确
- [ ] onboarding expiry/reissue/response-loss 可恢复
- [ ] Session secure storage 双平台通过
- [ ] Startup Gate 无业务闪现
- [ ] encrypted draft 通过
- [ ] Region 经真实无代理网络验证
- [ ] DB + Storage 实际恢复通过
- [ ] 全程没有新增现金支出
- [ ] 仓库无真实数据与 Secret

**Phase 0 未通过，不进入真实学生数据，也不批量开发业务页面。**

---

# Milestone 1｜机构、成员与租户隔离

目标：两名虚构教师用独立账号加入同一机构，另一机构严格不可见。

- [ ] profiles / organizations / roles
- [ ] memberships / membership_roles
- [ ] bootstrap 首位 org_admin
- [ ] provision / onboarding / reset / disable
- [ ] current organization context
- [ ] live-session + active membership RLS
- [ ] 两名 org_admin / break-glass

验收：
1. A 机构管理员开通教师甲乙；
2. 两人完成安全接管并重新登录；
3. A 数据互通；
4. B 数据完全不可见；
5. reset/disable 后旧 JWT 直接请求也失败。

---

# Milestone 2｜学生统一主档案与关系历史

- [ ] students（含 merged）
- [ ] academic_terms / student_enrollments
- [ ] subjects / organization_subjects
- [ ] 轻量 taxonomy + “其他/暂未分类”
- [ ] student_subject_profiles
- [ ] student_teacher_assignments
- [ ] student_staff_assignments
- [ ] active lead 唯一性
- [ ] 学生搜索/重复提示
- [ ] 当前/历史负责人
- [ ] 教师交接
- [ ] student merge record

验收：同一学生只有一个 student_id；升年级/换老师不丢历史；学管不伪装成学科教师。

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

### 最终行动不变量
- [ ] confirmed/intervening/pending_verification/stable 都有 pending primary action
- [ ] 暂缓使用 `review` action + due_at；pause_reason 只解释
- [ ] closed 无 pending primary action
- [ ] passed 不自动 stable/closed

端到端：

```text
new
→ confirm + evidence + primary action
→ intervention
→ verify assessment
→ stable + review action
→ closed
→ recurrence → reopen 原 case
```

---

# Milestone 4｜课程与“今日”

> 不做完整排课系统。

- [ ] lessons / lesson_students
- [ ] 从学生/今日快速开始课程
- [ ] Today：到期/逾期 action、无日期待安排 action、待验证、重点 case
- [ ] 课前遗留摘要
- [ ] 课中 action/intervention/assessment/new
- [ ] complete_lesson 事务命令
- [ ] 30–60 秒课后流程
- [ ] encrypted draft/network recovery
- [ ] 长期未整理 new 提醒

验收：2 教师 + 5 虚构学生连续模拟一周，课后中位 ≤60 秒，断网不丢，暂停 case 不失踪。

---

# Milestone 5｜权限、审计、交接与治理加固

- [ ] 本科详细权限
- [ ] 跨学科有限共享
- [ ] advisor 综合视角
- [ ] subject_lead
- [ ] audit_logs
- [ ] live-session helper 性能/安全复审
- [ ] Storage RLS / signed URL 审计
- [ ] handoff
- [ ] merge_students
- [ ] 负面权限自动化测试

---

# Milestone 6｜内部发行与可运维性

- [ ] Windows 内部分发/升级
- [ ] Android 签名包/升级
- [ ] 签名密钥备份
- [ ] Production region/net final check
- [ ] Free usage dashboard/checklist
- [ ] DB + Storage 周期备份
- [ ] 恢复演练
- [ ] 最低支持客户端版本
- [ ] Production migration + smoke test
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
- 两位教师共同管理同一学生但权限边界正确；
- 快速记录真实可用；
- 所有正式未关闭 case 有下一步；
- 网络/设备异常不丢、不泄露；
- 教师交接不丢历史；
- DB/Storage 可恢复；
- Free Pilot 不自动产生额外费用。

---

# V1.1｜家校与阶段输出
- guardians / student_guardians
- parent_communications
- 周度自动摘要
- report draft/finalized snapshot
- 家校 / 报告一级入口

# V1.5｜机构协作与教学洞察
- observations
- 跨学科综合观察
- 长期/超期提醒
- 高频问题分析
- taxonomy 轻量治理
- 管理端教学异常

不做教师填表量排行榜。

# V2｜教研资产与 AI 副驾驶
- 自然语言转结构化 draft
- 相似/重复 case 提示
- 自动摘要
- 家校反馈草拟
- 同类方案检索
- AI 来源 + 人工确认

# Schema 稳定后｜Excel 导入
- 预览
- 字段/分类映射
- 学生查重
- 验证
- 导入报告
- 回滚

# 仍不做
- 收费/课消/招生 CRM
- 完整排课 ERP
- 大型题库
- 学情健康分/成绩预测
- 家长/学生独立 App（V1）
- Google Docs 式协同
- 复杂 offline-first/CRDT
- 多套登录方式并存
- 庞大知识图谱
