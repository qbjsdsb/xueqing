# 架构与产品决策记录（ADRs）

本文件记录已经做出的关键选择。后续开发如果要推翻其中某项，应说明原因、影响和迁移方案，而不是在代码中悄悄改变方向。

## ADR-001｜客户端采用 Flutter，Windows + Android 优先

**状态：Accepted**

原因：教师办公端需要 Windows，课中/课后快速记录需要 Android，希望共享主要业务代码与领域模型。V1 不同时铺开 Web/iOS。

## ADR-002｜Supabase 作为 V1 云端基础设施

**状态：Accepted**

使用 PostgreSQL、Auth、Storage、RLS、Edge Functions。项目本质是强关系型、多角色、多租户业务。

## ADR-003｜普通业务 Data API，高权限/事务操作受控执行

**状态：Accepted**

普通业务在 RLS 保护下访问；需要 Secret/Auth Admin 的操作走 Edge Functions；数据密集且要求事务一致性的命令可使用受控 Database Functions。Flutter 不持有 Secret/service_role。

## ADR-004｜系统从第一天多租户，但 V1 不做 SaaS 计费

**状态：Accepted**

保留 organization 边界与 RLS；V1 不做套餐、订阅、计费、自助开通。

## ADR-005｜一个学生一份机构主档案

**状态：Accepted**

不同老师、学科、年级、校区不重复建 Student。姓名不是唯一键，重复通过提示 + 受控合并治理。

## ADR-006｜年级与负责人保存历史

**状态：Accepted**

- 年级/校区/班级：`student_enrollments`
- 任课教师：`student_teacher_assignments`
- 学管/班主任：`student_staff_assignments`

不覆盖 students.grade / teacher_id。

## ADR-007｜“顽固问题”不是第二份台账

**状态：Accepted**

长期/顽固问题从 learning_case 的失败、复发、持续时间等事实派生，避免多台账冲突。

## ADR-008｜周度与阶段指标优先派生

**状态：Accepted**

教师不重复填周表，统计从原始教学事实生成。

## ADR-009｜案例采用事件历史 + 当前快照

**状态：Accepted**

`learning_cases` 保存当前状态，`case_events` 保存关键生命周期变化。

## ADR-010｜下一步行动是一等对象

**状态：Accepted**

使用 `case_actions`。正式跟进案例通常最多一个 pending 主行动；无主行动必须有暂停理由。

## ADR-011｜课程支持一对多，但不是排课 CRM

**状态：Accepted**

使用 `lessons + lesson_students`。lesson 是实际教学会话/记录容器，不顺势扩张为收费、课消、复杂排课。

## ADR-012｜V1 online-first，但必须保护未提交输入

**状态：Accepted**

云端 PostgreSQL 是正式事实源；不做复杂离线多主同步，但高频表单有本地临时草稿、保存状态和幂等重试。

## ADR-013｜不做无验证依据的“学情健康分”

**状态：Accepted**

V1 展示透明事实，不把人为加权分包装成科学结论。

## ADR-014｜AI 是副驾驶，不是事实源

**状态：Accepted**

AI 可生成草稿、摘要、相似案例提示；正式学情变化必须由授权教师确认。

## ADR-015｜完整产品 6 主入口，V1 首发 4 主入口

**状态：Accepted**

完整目标：今日 / 学生 / 课程 / 学情 / 家校 / 报告。

V1：今日 / 学生 / 课程 / 学情。家校和报告进入 V1.1。

## ADR-016｜“今日”由行动驱动，不依赖完整排课

**状态：Accepted**

今日主要聚合到期/逾期 case_actions、待验证、高优先级案例、最近负责学生。教师可直接开始课程。

## ADR-017｜受控分类 + 自由表达双轨

**状态：Accepted**

轻量 taxonomy 用于统计；title/description 保留教师自然表达。不建庞大知识图谱。

## ADR-018｜业务层不得到处直接依赖 Supabase SDK

**状态：Accepted**

Flutter 通过 Repository / Service 访问后端，以便测试、替换 fake、降低 UI 与表结构耦合。

## ADR-019｜V1 正确性不依赖 Realtime

**状态：Accepted**

提交后刷新、页面进入、App resume、手动刷新必须足以保证正确。Realtime 只增强体验。

## ADR-020｜Local / Remote Development / Production 明确分离

**状态：Accepted**

Local Supabase CLI 用于 schema/RLS 开发测试；Remote Development 用虚构数据做 Auth/Storage/双平台公网联调；Production 承载真实机构数据。

## ADR-021｜首位 org_admin 使用一次性受控 Bootstrap

**状态：Accepted**

由受信任流程初始化首位 org_admin，完成后关闭入口；不在 Flutter 内置超级管理员 Secret。

## ADR-022｜学情状态和验证结果是两类事实

**状态：Accepted**

一次 assessment passed 不自动意味着 stable/closed。stable 表示改善并观察；closed 表示退出主动跟进。

## ADR-023｜暴露派生 View 必须显式处理 RLS

**状态：Accepted**

客户端 View 优先 `security_invoker = true`，或放不暴露 schema/通过受控函数提供。

## ADR-024｜Git migrations 是数据库结构正式事实源

**状态：Accepted**

Schema、RLS、View、Function、Trigger、Index 的正式变化进入 migration。Local 从空库重建；Remote Development 不是第二 schema 源。

## ADR-025｜基于 Supabase Invite Link 的跨机构账号方案

**状态：Superseded**

早期方案依赖 `inviteUserByEmail` + deep link。后续先被 Email OTP 方案替代，最终 V1 又因零额外付费约束切换到 ADR-030。

## ADR-026｜分类 schema 先稳定，复杂分类 UI 后置

**状态：Accepted**

保留 `organization_subjects` + 轻量 taxonomy；首版只提供少量默认节点、“其他/暂未分类”和最小启用/停用能力，复杂治理后置。

## ADR-027｜V1 首选 Passwordless Email OTP

**状态：Superseded by ADR-030**

OTP 能统一 Windows/Android、新旧 Auth User 和多机构登录体验，但真实机构使用需要可靠邮件投递。Supabase 默认 SMTP 并非 Production 登录基础设施。

用户明确要求本阶段**不额外花钱**后，继续把 Custom SMTP/域名作为 V1 硬依赖不再合理，因此 OTP 降为未来可替换登录 UX。

## ADR-028｜Invitation 与 Membership 是两个不同领域对象

**状态：Deferred for V1**

Invitation 与正式 Membership 的概念区分仍然正确；但 ADR-030 的封闭内部账号开通流程不需要 V1 先维护 invitation 表。

未来如果启用 Email OTP / 自助加入，再重新引入 `organization_invitations`，不能把 pending invitation 当成正式权限。

## ADR-029｜课堂问题采用“快速捕捉 → 课后确认”两段式

**状态：Accepted**

课中 `new` 只需极少字段，目标 10–20 秒；正式 `confirmed` 再要求 taxonomy、owner、最小 evidence、主行动或 pause reason。

## ADR-030｜V1 零额外付费认证：管理员受控开通 + 临时密码 + Onboarding

**状态：Accepted**

V1 面向少量、已知、内部教师，不开放公网注册。

流程：

```text
org_admin
  ↓
provision_member（可信服务端）
  ↓
Auth Admin createUser(email + 随机临时密码 + email_confirm)
  ↓
membership = onboarding + roles
  ↓
教师用临时密码登录
  ↓
complete_member_onboarding 设置自己的新密码
  ↓
membership = active
```

理由：
- 不需要 SMTP、短信、域名或第三方登录；
- Supabase Auth Admin 创建用户不会强制发送确认邮件；
- 临时凭据可通过机构已有可信渠道一次性交付；
- onboarding membership 不得读取学生业务数据；
- 忘记密码先由管理员核验后受控重置，再回 onboarding；
- 旧 Session 是否立即失效不作为唯一安全保证，因为非 active membership 会被 RLS 拒绝。

临时密码不得落数据库、日志、审计或 GitHub，只在创建/重置成功时返回一次。

Email OTP 保留为未来可替换登录层；更换登录方式不得重写 membership / roles / assignments。

## ADR-031｜V1 采用零额外付费 Pilot 基础设施，不假装具备商业 SLA

**状态：Accepted**

本阶段默认：
- GitHub Free private repository；
- GitHub Actions 免费额度内的精简 CI；
- Supabase Local CLI；
- 一个 Free Remote Development；
- 一个 Free Production Pilot；
- 不购买额外 Work/Codex credits、SMTP、域名、短信、AI API 或商业 SaaS。

Supabase Free 当前容量足以小规模内部 Pilot，但 Free 项目可能因低活动暂停，且没有与付费计划相同的自动备份保障。因此：
- 定期 `db dump` / `pg_dump`；
- Storage 单独备份；
- 恢复演练；
- 使用量接近免费额度前先评审，不自动升级/付费。

“0 元”是 V1 约束，不是承诺永远不为生产可靠性付费。真实机构高度依赖系统后应重新做风险/成本评审。

## ADR-032｜ChatGPT Project + Work 是云端主控，GitHub/CI 是事实与执行证据

**状态：Accepted**

长期云端开发采用：
- 一个 ChatGPT Project：`Xueqing｜学情闭环开发`；
- 如果需要在 Project 内使用 Work，使用当前支持 Work 的 memory 配置，不启用会禁用 Work 的 Project-only memory；
- GitHub connector 读取/修改真实仓库；
- 一个可验收目标通常对应一条 Work 会话和一个 PR；
- GitHub 是源码事实源；聊天记忆不是代码事实源；
- migrations 是数据库结构事实源；
- 需要真正运行命令/构建时由 Codex 或 GitHub Actions 提供执行证据。

Work/Codex 达到方案内包含用量后等待重置，不购买额外 credits。

模型策略：Luna 用于高频云端工作；用户界面若提供 Luna + Max reasoning，则把 Max 优先留给 RLS、migration、事务、并发、安全和 Milestone 终审，不用高推理预算做机械改名/格式化。

## ADR-033｜开源项目借鉴“模式”，不 Fork 大型学校 ERP

**状态：Accepted**

主要参考：
- Flutter 官方 `flutter/samples/compass_app`：多环境、Repository/Service、测试；
- `supabase/supabase-flutter`：Local stack 与 `supabase_testing`；
- AppFlowy：真实 Flutter 跨平台、隐私、发行维护；
- Frappe Education / Gibbon：教育领域历史关系、角色、长期模块化运营。

不直接 fork 大而全教育 ERP，也不把收费、排课、招生、财务等能力带入 Xueqing V1。

详细边界见 `docs/OPEN_SOURCE_REFERENCES.md`。