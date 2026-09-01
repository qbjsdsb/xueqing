# 核心数据模型

## 1. 身份与组织

### organizations
- id
- name
- status
- created_at

### campuses
- id
- organization_id
- name
- status

### users / staff_profiles
账号由认证系统管理；员工资料单独保存。

### organization_memberships
记录用户属于哪个机构、具有什么角色。

## 2. 学生与关系

### students
- id
- organization_id
- name
- status
- grade
- campus_id
- created_at
- updated_at

### student_teacher_assignments
决定哪位老师负责哪个学生的哪一门学科。

建议字段：
- id
- organization_id
- student_id
- teacher_user_id
- subject_id
- assignment_role（lead / collaborator / homeroom）
- active_from
- active_to
- is_active

## 3. 学科学情

### subjects
学科字典。

### student_subject_profiles
学生与某一学科的连续档案，不因换老师而重新创建。

## 4. 学情案例

### learning_cases
- id
- organization_id
- student_id
- subject_id
- owner_teacher_id
- module_id
- title
- description
- status
- priority
- first_observed_at
- next_action_at
- reopened_count
- created_by
- created_at
- updated_at

建议状态：
new / confirmed / intervening / pending_verification / stable / closed

### case_evidence
保存支撑学情判断的证据元数据，例如试卷、作文、作业、课堂练习、小测、观察记录等。

### case_events
学情案例的不可丢失时间轴：发现、确认、干预、检测、状态变化、复发、关闭等。

### interventions
教学干预记录。

### assessments
验证或检测记录，保存结果、评价与关联证据。

## 5. 课程

### lessons
- id
- organization_id
- student_id
- subject_id
- teacher_id
- started_at
- ended_at
- summary
- created_at

### lesson_case_actions
关联某次课处理了哪些学情案例，以及结果：passed / partial / failed。

## 6. 综合观察

### observations
用于跨学科必要共享的客观观察，例如作业完成、专注、畏难、课堂状态等。

原则：优先记录可观察事实，避免人格化标签。

## 7. 家校与报告

### parent_communications
保存正式家校沟通记录与关联事实。

### reports
阶段报告。报告中的统计尽量从原始事实生成，避免重复录入。

## 8. 审计

### audit_logs
关键业务对象的创建、修改、状态变化、交接、停用等都记录：

- actor_user_id
- organization_id
- entity_type
- entity_id
- action
- before_data
- after_data
- occurred_at

## 9. 数据设计原则

- 身份数据、事实数据、状态数据、派生数据分层。
- 原始事实优先追加事件，不轻易覆盖历史。
- 派生统计可以重算，不把 Excel 式重复汇总作为事实源。
- 所有业务表均考虑 organization_id 与 RLS。
- 不在代码仓库保存真实业务数据。
