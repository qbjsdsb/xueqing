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

由受信任流程初始化首位 active membership，完成后关闭入口；不在 Flutter 内置超级管理员 Secret。

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

**状态：Superseded by ADR-027**

早期方案依赖 `inviteUserByEmail` + deep link，并对已确认 Auth User 的第二机构加入单独设计 link-existing-user。

反向评审后发现 Email OTP 可以把新/旧 Auth User 统一成同一登录流程，因此该方案不再作为 V1 首选。

## ADR-026｜分类 schema 先稳定，复杂分类 UI 后置

**状态：Accepted**

保留 `organization_subjects` + 轻量 taxonomy；首版只提供少量默认节点、“其他/暂未分类”和最小启用/停用能力，复杂治理后置。

## ADR-027｜V1 首选 Passwordless Email OTP，机构授权与 Auth 登录分离

**状态：Accepted（Phase 0 必须实测）**

V1 首选：

```text
管理员创建 organization_invitation(email)
           ↓
教师 App 输入邮箱 → Email OTP
           ↓
verifyOtp 建立 Auth Session
           ↓
系统按 verified email 匹配 pending invitation
           ↓
accept_invitation 创建 active membership + roles
```

理由：
- Windows / Android 登录 UX 一致；
- 不依赖自定义 deep link；
- 不需要 V1 密码设置/恢复主流程；
- 新 Auth User、已有 Auth User 使用同一登录方式；
- 同一 Auth User 被第二机构邀请时也能用同一 membership 模型处理；
- 业务权限仍严格由 active membership/RLS 控制。

有意识接受的代价：
- `shouldCreateUser=true` 时，无邀请用户也可能创建一个没有机构权限的 Auth User；
- Production 必须配置 rate limiting / CAPTCHA 或等价防滥用；
- Production 登录邮件需要可靠 Custom SMTP/等价服务，不依赖默认 best-effort 邮件服务。

如果 Phase 0 在真实机构邮箱投递、成本或体验上证明 OTP 不可接受，再新增 ADR 评估 Password/Magic Link/SSO；不并行维护多套登录方案。

## ADR-028｜Invitation 与 Membership 是两个不同领域对象

**状态：Accepted**

`organization_invitations` 只表示某邮箱被机构预授权加入；pending invitation 没有业务数据权限。

`organization_memberships` 只表示已经加入机构的 Auth User，状态主要为 active/disabled。

接受 invitation 是受控、幂等事务：verified email 匹配 → membership + roles → invitation accepted。

这样邮件/OTP/Auth 的生命周期不会污染正式成员权限状态。

## ADR-029｜课堂问题采用“快速捕捉 → 课后确认”两段式

**状态：Accepted**

课中 `new` 只需极少字段，目标 10–20 秒；正式 `confirmed` 再要求 taxonomy、owner、最小 evidence、主行动或 pause reason。

这是数据质量与教师填写负担之间的核心平衡，后续实现不得把完整表单重新塞回课堂捕捉流程。