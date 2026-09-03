# Phase 0B.0-B｜Identity & Learning Data Foundation

## 这条 PR 做什么

这条 PR 把 Excel 原型背后的最小事实地基落成可测试的数据库边界：

- 一个机构内一个学生主档案；
- 学生可以有多个学科 Subject Profile，但不重复 Student；
- 教师责任通过显式 assignment 表达；
- 教师只有在 active membership、teacher role、teaching scope、active Profile 和合法 assignment 同时成立时才能看到学生基础资料；
- 机构业务日期由 organizations.time_zone 解释；
- 外部认证身份仍通过 ADR-046 的稳定业务 UUID + identity link 解耦。

这条 PR 只开放受 RLS 保护的读取；没有开放客户端写入，也没有实现 Learning Case、Evidence、Intervention、Assessment、Action。

## Excel 到数据库的对应关系

- 01 学生档案 → students + student_enrollments + organization_subjects + student_subject_profiles；
- 02 初诊问题 → 后续 learning_cases，不在本 PR 伪装成学生字段；
- 03 知识闭环 → 后续 case_events / interventions / assessments；
- 04 周度跟进、05 顽固问题、07 阶段复盘 → 由正式事实派生，不创建第二套台账；
- 06 家校沟通 → 后续 parent_communications；
- 00 规则说明 → 稳定字典、约束和产品规则，不导入业务行。

## 关键安全/一致性选择

- identity_links 的 external_subject 是 text，并且唯一键包含 provider、issuer 和 subject；
- 所有跨机构关系使用 organization_id，关键关系使用 composite foreign key 防止跨机构串接；
- active membership 在 V1 对同一 App User 跨机构唯一；
- Profile 和 Assignment 有独立 version/active 状态边界；
- Students 继续保留历史生命周期字段与 version；
- organization timezone 用于业务日期边界，不能用设备时区替代；
- 新基础表的客户端权限是 select-only，写命令留给后续受控事务；
- V1 不开启 Realtime，也不把页面正确性建立在 Realtime 上。

## 验收证据

PR 必须通过：

- 空库 migration + seed；
- foundation_access_test.sql；
- 既有 rls_access_test.sql；
- old-token security test；
- Flutter format/analyze/test。

通过后，下一条 PR 才做 Quick Capture / Learning Case 的正式写入命令，并在服务器事务中实现 Teaching Fact Gate、幂等和 expected_version。
