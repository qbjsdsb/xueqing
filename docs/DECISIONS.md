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

## ADR-003｜普通业务客户端直连 Data API，高权限操作走服务端

**状态：Accepted**

普通教师在 RLS 保护下访问有权数据。

以下默认走 Edge Functions/受信任后端：
- 邀请成员；
- 高权限角色变化；
- 学生合并；
- 批量交接；
- 受控删除/导出；
- 需要高权限凭据的第三方服务。

Flutter 不持有 Secret Key / service_role。

## ADR-004｜系统是多租户，但 V1 不做复杂 SaaS 计费

**状态：Accepted**

从第一天有 organization 边界和 RLS 隔离，以免未来从“单机构数据库”迁移时重写所有表。

V1 不做套餐、计费、订阅和自助开通。

## ADR-005｜一个学生一份机构主档案

**状态：Accepted**

同一学生不会因为：
- 不同老师；
- 不同学科；
- 不同年级；
- 不同校区

重复创建主档案。

姓名不是唯一键，重复学生通过提示 + 受控合并解决。

## ADR-006｜年级与教师负责人必须保存历史

**状态：Accepted**

因此：
- 年级/校区/班级使用 `student_enrollments`；
- 教师负责关系使用 `student_teacher_assignments`。

不允许仅覆盖 students.grade 或 students.teacher_id。

## ADR-007｜“顽固问题”不是第二份业务台账

**状态：Accepted**

顽固/长期问题是 learning_case 根据失败、复发、持续时间等规则得到的提示/标签。

原因：避免“初诊已清零，但顽固台账仍跟进中”等多事实源冲突。

## ADR-008｜周度跟进与阶段指标优先派生

**状态：Accepted**

教师不重复填写周表。

周度/阶段信息从：
- lessons
- learning_cases
- case_events
- interventions
- assessments
- case_actions
- observations
- parent_communications

计算生成。

## ADR-009｜学情案例采用事件历史 + 当前快照

**状态：Accepted**

`learning_cases` 保存当前状态，`case_events` 保存关键生命周期变化。

这样既保证查询效率，又能追溯发生过什么。

## ADR-010｜下一步行动是一等对象

**状态：Accepted**

使用 `case_actions`，而不是只在 learning_cases 上放一个日期字段。

理由：真正的产品价值是“告诉老师接下来做什么”，今日工作台必须有稳定的数据来源。

## ADR-011｜课程支持一对多学生

**状态：Accepted**

使用 `lessons + lesson_students`，一对一只是只有一个 lesson_student。

原因：教培机构存在小班/多人课，如果把 student_id 写死进 lessons，后期必然迁移。

## ADR-012｜V1 online-first

**状态：Accepted**

云端 PostgreSQL 是事实源。

V1 不做复杂离线写入与冲突合并；本地缓存只能改善体验。

原因：离线多主同步会显著增加复杂度和数据冲突风险，不属于第一版核心价值。

## ADR-013｜不做没有验证依据的“学情健康分”

**状态：Accepted**

V1 展示透明事实：
- 当前重点案例数；
- 待验证；
- 逾期行动；
- 最近解决；
- 复发情况。

不把人为加权数字包装成科学结论。

## ADR-014｜AI 是副驾驶，不是事实源

**状态：Accepted**

AI 可以生成草稿、摘要、相似案例提示；正式学生学情变化必须由授权教师确认并落成结构化事实。
