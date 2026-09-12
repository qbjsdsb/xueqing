# Xueqing 显式教学责任交接合同

## 目的

任课关系、Learning Case 主责和 Case Action 执行人是不同的业务事实。

当老师离开某个学生学科、或机构需要更换主责老师时，系统不能只结束任课关系，也不能因为负责人/管理员有管理权限就静默改写教学责任。交接必须是一个教师看得懂、可以预览、可以明确确认、失败时不留下半成品的业务动作。

## 核心原则

1. **先预览，再提交。** 服务端先返回这次交接会影响的当前任课关系、进行中 Case 和待执行 Action；用户确认的是这一份具体计划，而不是一个模糊的“换老师”。
2. **事实发生变化就重新确认。** 从预览到提交期间，只要 Assignment、相关 Case 或 Action 版本发生变化，提交必须 `fail closed`，提示重新核对，不能静默扩大或缩小交接范围。
3. **一次事务完成当前责任迁移。** 成功提交时，同一事务内结束原任课关系、建立接收老师的任课关系，并迁移本次确认范围内的当前 Case owner 和 pending Action assignee。
4. **历史永远不重写。** Evidence、Intervention、Assessment、既有 Case Event 及其 Actor 保持原样。交接只改变“现在谁继续负责”，不改变“过去是谁做的”。
5. **管理权限不等于教学责任。** 发起交接的负责人/管理员作为本次 `responsibility_handoff` 事件的 Actor 留痕；接收老师成为新的当前责任人，两者不能混为一谈。
6. **接收老师必须具备真实教学资格。** 接收成员必须在岗、具有 teacher 角色，并拥有该学科当前有效的 teaching scope。
7. **幂等且可恢复。** 成功提交使用 operation id 保证重复请求返回同一结果，不重复创建任课关系或重复迁移责任。

## 产品交互

管理端的任课交接应采用两段式流程：

1. 先选择接收老师；
2. 加载服务端交接预览，明确显示学生、学科、原老师、接收老师、将迁移的进行中问题和待完成行动；
3. 明确提示“历史记录不会修改”；
4. 用户点击“确认交接”后提交预览计划；
5. 若返回 `teacher_handoff_plan_stale`，关闭旧确认结果并重新加载事实，不自动重试。

建议确认文案：

> 将「学生 · 学科」从「原老师」交接给「接收老师」。
>
> 将同时迁移：进行中问题 N 个、待完成行动 M 个。
>
> 历史证据、教学处理、检查结果和历史记录不会修改。

## “设置主责老师”与“教学责任交接”不是同一个动作

学生学科服务仍处于 active，但当前没有 active Lead Assignment 时，系统面对的是**责任空缺**，而不是“从 A 交接给 B”。这时应使用独立的“设置主责老师”动作：只为该学生学科建立新的当前 Lead，不伪造一个不存在的原负责人，也不借机迁移其他事实。

两种动作的边界必须稳定：

- **当前没有 Lead → 设置主责老师。** 只建立新的 active Lead Assignment；必须校验学生、学科、成员、teacher 角色和当前有效 teaching scope；如果别人刚刚已经补上 Lead，则 fail closed。
- **当前已有 Lead A，需要改为 B → 教学责任交接。** 必须先预览再提交，并显式迁移确认范围内的当前 Case owner 与 pending Action assignee。
- “设置主责老师”**不得**自动修改已有 Learning Case owner、Case Action assignee 或历史 Actor。若这些旧事实本身需要修复，应通过明确、可审计的后续业务动作处理，不能成为补 Lead 的隐藏副作用。

因此，管理端在责任空缺时应直接显示“暂未明确主责老师 / 设置主责老师”；已有主责时才提供“交接老师”。这也避免把 collaborator 的存在误判成“已有主责”。

## 不做什么

- 不把负责人/管理员自动设置为 Case owner；
- 不批量改写历史 Actor；
- 不通过客户端拼凑需要迁移的 Case / Action；
- 不为了交接新增第二套 Case 或责任模型；
- 不在交接时自动关闭问题、伪造验证结果或清空待办。

## 当前实现边界

服务端提供 `preview_organization_student_teacher_handoff` 与 `commit_organization_student_teacher_handoff` 两个 RPC；Flutter repository 提供对应的 preview / commit 合同。管理端可视化确认流程作为其上的独立 UX 层实现，不能绕过预览直接迁移仍有关联责任的任课关系。

责任空缺由独立的 `set_organization_student_subject_lead` RPC 处理。它只允许对 active 且当前不存在 active Lead 的学生学科建立一个新的 Lead Assignment，并依赖数据库“一门学生学科最多一个 active Lead”的约束作为并发安全底线；它不承担已有 Case / Action 的责任迁移。