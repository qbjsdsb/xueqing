# Phase 0B.0-C｜Case Core Command Loop

## 目标

把第一条真实教学闭环落成可验证的数据库命令边界：

\`new → confirmed → intervening → pending_verification → stable → closed\`

本阶段只使用虚构开发数据。它不是 Production migration，也不授权导入真实学生、教师或家长资料。

## 本次落地

- \`learning_cases\`：Case 当前快照、状态、owner、version；
- \`case_evidence\`：带 \`observed_at\` 的 finalized append-only 证据；
- \`interventions\`：教学动作历史；
- \`assessments\`：验证结果历史；
- \`case_actions\`：当前与历史下一行动，数据库唯一约束保证每个 Case 最多一个 pending primary；
- \`case_events\`：不可静默修改的命令/生命周期事实；
- \`operation_receipts\`：高风险命令的 exactly-once 结果登记。

## 命令与事务

对外只暴露受控的 authenticated RPC：

- \`quick_capture_case\`
- \`confirm_case\`
- \`add_case_evidence\`
- \`record_intervention\`
- \`record_assessment\`
- \`stabilize_case\`
- \`close_case\`
- \`reschedule_case_action\`
- \`complete_case_action\`

每个命令：

1. 验证 live Supabase session → App User → active membership → teacher role → active teaching scope → active Profile → legal teacher assignment；
2. 以 Profile/Case 行锁和 expected version 防止陈旧状态覆盖；
3. 先 claim \`(organization_id, operation_id)\`，重试返回第一次 committed result；
4. 在同一事务写入事实、Action、Case event 和 operation receipt；
5. 最后检查 Case 的 owner/primary Action/closed 状态不变量。

普通 Evidence append 不机械增加 Case version；会改变 Case current snapshot 的命令才递增 Case version。完成当前 primary Action 时，服务端在同一事务中把旧 Action 标记为 `done`、写入不可变事件并创建 successor Action，避免 active formal Case 出现没有后续行动的半状态。Finalized Evidence、Intervention、Assessment、Action progress 和 Case Event 没有客户端 UPDATE/DELETE 权限，并由 append-only / 受控 command 边界保护历史含义。

## 安全验证

\`case_core_access_test.sql\` 覆盖：

- anonymous 读取/执行拒绝；
- Teacher A 只能操作并读取自己的学生；
- Teacher B 看不到 A 的 Case，也不能跨学生 Quick Capture；
- 无机构用户不能创建 Case；
- stale \`expected_case_version\` whole rollback；
- Quick Capture、Evidence、Intervention operation retry 不重复副作用；
- Assessment passed 只进入 \`pending_verification\`，不自动变成 stable；
- stable → closed 写入一个 immutable \`case_closed\` event，且没有 pending primary Action；
- complete Action 必须通过 teaching gate、Case/Action expected versions，并 exactly-once 创建下一条 pending primary；
- finalized Evidence 静默 UPDATE 被拒绝。

## 明确未做

- \`reopen_case\` 的 post-close recurrence Evidence freshness/close-boundary 矩阵；
- Lesson、家校沟通、Report、Advisor staff assignment；
- \`reopen_case\` 的完整 Flutter 入口和 Today 更深的批量操作；
- Realtime、离线/CRDT、AI、真实数据和 Production provider/region/session 冻结。

这些留在下一条经过独立测试的 PR，不和本次 Case 写入事务混在一起。
