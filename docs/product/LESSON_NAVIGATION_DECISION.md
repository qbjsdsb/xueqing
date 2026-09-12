# Xueqing v0.3.x Lesson / 课程导航决策

状态：**Accepted / current v0.3.x contract**
日期：2026-09-12

## 决策

v0.3.x 当前生产 V2 的 Personal Projection 一级入口保持：

```text
今日 / 学生 / 学情
```

**不在 v0.3.x 恢复“课程 / Lesson”一级入口。**

Lesson 仍是 Xueqing 长期领域模型的一部分，但当前主线没有可发布的 Lesson repository、transactional command/read model、真实课堂会话 UI 或与现有 Case / Evidence / Action 闭环完成验证的运行时能力。仅为了满足早期 IA 文档而恢复一个入口，会违反“所有可见功能必须真实可用”和教师优先的产品原则。

## 证据

- 当前 `V2WorkspaceDestination` 只有 `today / students / learning / organization`；Personal 主线真实可用的是今日、学生、学情。
- UI V2 收口阶段已经主动删除未实现的“课程”占位入口，避免假按钮和假能力。
- 当前 Supabase migration 链没有 Lesson migration；现有可发布闭环集中在 Student / Learning Case / Evidence / Intervention / Assessment / Action。
- `DUAL_WORKSPACE_UX.md` 已把当前生产 V2 的个人主线冻结为 `今日 / 学生 / 学情`。

## 对早期文档的解释

Phase 0A.5 / Foundation 文档中“今日 / 学生 / 课程 / 学情”代表**目标态 IA / 领域蓝图**，不再代表 v0.3.x 当前运行时导航。

因此，从本决策起：

- `ROLE_ACCESS_CONTRACT.md`、`RESPONSIBILITY_MODEL.md` 的当前导航合同以三个 Personal 入口为准；
- `INFORMATION_ARCHITECTURE.md` 和 `SCREEN_SPECS.md` 中 Lesson 相关路径视为未来目标态说明；
- 不删除 Lesson 领域概念，也不伪造当前 Lesson 能力；
- Organization scope 仍独立于 Personal，不把机构能力当第四个教师业务页面。

## 何时重新考虑一级入口

只有以下最小能力真实存在并通过双平台验证后，才重新评审“课程”是否值得成为一级入口：

1. 有明确的真实课堂使用场景，而不是排课/收费 ERP；
2. 有可审计的 Lesson 数据与 participant Teaching Fact Gate；
3. 有开始 / 记录 / 完成课堂的事务边界与失败恢复；
4. 能把课堂中的 Evidence / Intervention / Assessment 关联回同一学生成长闭环，而不重复保存 Case 结果；
5. Android 与 Windows 的入口频率足以证明它值得占一级导航；
6. 普通老师的操作复杂度不会因此上升。

若这些条件未满足，课堂中的即时事实继续通过现有学生上下文、Quick Capture、Case Progress 和 Today Action 完成。

## 一句话原则

> Lesson 可以是未来的重要教学事实，但在它成为真实可用能力之前，不让一个占位入口挤进老师每天使用的软件。
