# 架构与产品决策记录（ADRs）

本文件记录已经做出的关键选择。后续开发如果要推翻其中某项，应说明原因、影响和迁移方案，而不是在代码中悄悄改变方向。

## ADR-001｜客户端采用 Flutter，Windows + Android 优先

**状态：Accepted**

原因：
- 教师办公端需要 Windows；
- 课中/课后快速记录需要 Android；
- 希望共享主要业务代码与领域模型；
- Supabase Flutter SDK 支持 Windows 与 Android。

不代表未来必须拒绝 Web/iOS，只是 V1 不同时铺开所有平台。

## ADR-002｜Supabase 作为 V1 云端基础设施

**状态：Accepted**

使用：
- PostgreSQL
- Auth
- Storage
- Row Level Security
- Edge Functions

理由：项目本质是强关系型、多角色、多租户业务，PostgreSQL 比“每个老师一份本地数据”更符合事实源要求。

## ADR-003｜普通业务客户端直连 Data API，高权限操作受控执行

**状态：Accepted**

普通教师在 RLS 保护下访问有权数据。

需要 Auth Admin、Secret 或越权维护的操作走 Edge Functions；数据密集且需要事务一致性的合并/交接等操作可以使用受控 Database Functions。

Flutter 不持有 Secret Key / service_role。

## ADR-004｜系统是多租户，但 V1 不做复杂 SaaS 计费

**状态：Accepted**

从第一天有 organization 边界和 RLS 隔离，以免未来从“单机构数据库”迁移时重写所有表。

V1 不做套餐、计费、订阅和自助开通。

## ADR-005｜一个学生一份机构主档案

**状态：Accepted**

同一学生不会因为不同老师、不同学科、不同年级、不同校区而重复创建主档案。

姓名不是唯一键，重复学生通过提示 + 受控合并解决。

## ADR-006｜年级与负责人必须保存历史

**状态：Accepted**

因此：
- 年级/校区/班级使用 `student_enrollments`；
- 任课教师使用 `student_teacher_assignments`；
- 学管/班主任等非学科责任关系使用 `student_staff_assignments`。

不允许仅覆盖 students.grade 或 students.teacher_id。

## ADR-007｜“顽固问题”不是第二份业务台账

**状态：Accepted**

顽固/长期问题是 learning_case 根据失败、复发、持续时间等规则得到的提示/标签。

原因：避免“初诊已清零，但顽固台账仍跟进中”等多事实源冲突。

## ADR-008｜周度跟进与阶段指标优先派生

**状态：Accepted**

教师不重复填写周表。周度/阶段信息从原始教学事实计算生成。

## ADR-009｜学情案例采用事件历史 + 当前快照

**状态：Accepted**

`learning_cases` 保存当前状态，`case_events` 保存关键生命周期变化。

这样既保证查询效率，又能追溯发生过什么。

## ADR-010｜下一步行动是一等对象

**状态：Accepted**

使用 `case_actions`，而不是只在 learning_cases 上放一个日期字段。

一个案例允许存在辅助行动，但通常最多只有一个 pending 主行动；若没有主行动必须能说明暂停原因。

## ADR-011｜课程支持一对多学生，但课程不是排课 CRM

**状态：Accepted**

使用 `lessons + lesson_students`，一对一只是只有一个 lesson_student。

`lesson` 表示真实教学会话/记录容器，不在 V1 顺势扩张成收费、课消、复杂排课产品。

## ADR-012｜V1 online-first，但必须保护未提交输入

**状态：Accepted**

云端 PostgreSQL 是正式事实源，V1 不做复杂离线多主同步。

但网络失败不能让教师白填，因此高频表单必须：
- 有本地临时草稿；
- 有清楚保存状态；
- 失败可重试；
- 云端确认后才视为正式保存。

## ADR-013｜不做没有验证依据的“学情健康分”

**状态：Accepted**

V1 展示透明事实，不把人为加权数字包装成科学结论。

## ADR-014｜AI 是副驾驶，不是事实源

**状态：Accepted**

AI 可以生成草稿、摘要、相似案例提示；正式学生学情变化必须由授权教师确认并落成结构化事实。

## ADR-015｜完整产品可以有 6 个主入口，但 V1 首发只保 4 个

**状态：Accepted**

完整目标：今日 / 学生 / 课程 / 学情 / 家校 / 报告。

V1 首发：今日 / 学生 / 课程 / 学情。

家校和报告在 V1.1 进入正式导航，避免第一版范围失控。

## ADR-016｜“今日”由行动驱动，不以完整排课为前提

**状态：Accepted**

V1 “今日”主要聚合：
- 到期/逾期 case_actions；
- 待验证案例；
- 高优先级案例；
- 最近负责学生。

教师可快速开始一次课程，不需要先维护一套排课表。

## ADR-017｜受控分类 + 自由表达双轨

**状态：Accepted**

为了长期统计和教研，学情案例引用轻量 taxonomy；为了保留真实教学表达，案例 title/description 仍为自由文本。

不在 V1 建庞大知识图谱。

## ADR-018｜业务层不得到处直接依赖 Supabase SDK

**状态：Accepted**

Flutter 通过 Repository / Service 边界访问后端。

原因：
- 可测试；
- 可替换 fake；
- 避免页面知道表结构；
- 若未来因网络、部署、合规或成本调整后端，不重写全部 UI。

这不意味着现在建设多后端抽象平台。

## ADR-019｜V1 正确性不依赖 Realtime

**状态：Accepted**

提交后刷新、页面进入刷新、App resume 和手动刷新必须足以保证正确。

Realtime 只做变更提示和体验增强，避免在第一版增加不必要的连接与授权复杂度。

## ADR-020｜Development 与 Production 从第一天分离

**状态：Accepted**

至少使用两个独立远程环境语义：
- Remote Development：虚构数据与集成测试；
- Production：真实机构数据。

此外使用本地 Supabase CLI 作为数据库结构与 RLS 的主要开发/测试环境。

数据库、Storage、Secret、测试账号不混用。

## ADR-021｜首位机构管理员使用一次性受控 Bootstrap

**状态：Accepted**

邀请制无法自己产生第一个管理员，因此通过受信任运维/一次性流程初始化首位 org_admin，完成后关闭该入口。

绝不在 Flutter 中内置超级管理员 Secret。

## ADR-022｜学情状态和验证结果是两类事实

**状态：Accepted**

一次 assessment passed 不自动意味着案例 stable/closed。

`stable` 表示已有证据支持改善但仍观察；`closed` 表示退出主动跟进。复发后 reopen 原案例。

## ADR-023｜暴露的派生 View 必须显式处理 RLS 语义

**状态：Accepted**

客户端可访问的 View 优先使用 `security_invoker = true` 或通过不暴露 schema/受控函数提供。

不允许因为“只是统计 View”而成为绕过 RLS 的后门。

## ADR-024｜Git migrations 是数据库结构的正式事实源

**状态：Accepted**

Schema、RLS、View、Function、Trigger、Index 的正式变化必须进入版本化 migration。

本地 Supabase CLI 用于从空库重建和数据库测试；Remote Development 用于 Auth、Storage、Edge Functions、双平台和公网集成验证。

不允许长期形成“Git 一套 schema、Dashboard 另一套 schema”。

## ADR-025｜数据库支持多机构账号，V1 UX 不强行实现复杂跨机构加入

**状态：Accepted**

Auth User 与 Organization Membership 分离，所以长期模型允许一个账号属于多个机构。

但 Supabase 标准 invite 对已确认用户不是“再次加入另一个机构”的通用入口。V1 首机构试运行优先保证单机构账号流程清晰；真正出现跨机构共享账号需求后，再实现受控 link-existing-user 流程。

不通过重复创建 Auth User 来伪造多机构支持。

## ADR-026｜分类 schema 先稳定，复杂分类管理 UI 后置

**状态：Accepted**

V1 数据模型保留 `organization_subjects` 与轻量 taxonomy，以保证长期统计口径。

但首版不建设复杂知识图谱或庞大分类配置后台：
- 先提供少量稳定 seed/default；
- 允许“其他/暂未分类”；
- 机构只需要最小启用/停用能力；
- 复杂分类治理在真实数据证明有需要后再扩展。

这样既避免自由文本污染统计，也避免教师在录入前先维护一套庞大字典。