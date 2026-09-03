# Phase 0B.0-D｜Teacher Workspace 数据接入

## 目标

把已验证的 Case Core 写入命令接到第一条真实教师路径：

```text
登录开发环境 → Today → 学生 → 学生详情 → Quick Capture
```

本阶段仍只使用虚构开发数据。它不是 Production migration，也不授权导入真实学生、教师或家长资料。

## 本次落地

- `teacher_workspace_action_queue`：使用 `security_invoker=true` 的只读 view；由数据库按机构 `time_zone` 计算 `overdue / today / future / undated`；
- `SupabaseLearningRepository`：只查询 canonical foundation、Case Core 和受 RLS 保护的 read model；客户端不读取 `operation_receipts`，也不直接写业务表；
- `TeacherWorkspaceEntryPage`：开发环境登录、退出和配置边界；
- `TeacherWorkspacePage`：Today、学生搜索、学生详情、Case 只读叙事和 Quick Capture；
- Quick Capture 使用一次生成、重试复用的 `operation_id`，服务端成功前不关闭表单；
- 保存失败时保留当前输入，不伪造 timeline、Case 或“已保存”反馈；
- 没有教学范围时只显示无权限说明，不显示隐藏学生、Case 标题或数量。

## Excel 语义承接

- `01_学生档案` 由学生、enrollment、学科 Profile 和 assignment 组成；
- `02_初诊问题` 由 Quick Capture 创建 `new` Learning Case、第一条 finalized Evidence 和下一 Action；
- `03_知识闭环` 继续由后续 Evidence、Intervention、Assessment 命令追加；
- `04/05/07` 不在页面要求老师重复填写，等事实稳定后再做派生查询；
- `06_家校沟通` 不在本切片展开。

## 明确未做

- Action completion command；
- Case 的 Evidence / Intervention / Assessment 编辑 sheet；
- 多学科学生的合并呈现与复杂筛选；
- Realtime、复杂离线同步、CRDT、AI、家校沟通、Lesson；
- Production provider/region/session 冻结和真实数据导入。

这些必须作为独立切片，先补 command、RLS、幂等、并发和平台验收，不能把 UI 的“按钮存在”当作领域能力已经完成。
