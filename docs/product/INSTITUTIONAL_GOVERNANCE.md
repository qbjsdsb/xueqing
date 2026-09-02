# 机构治理与异常工作流｜Institutional Governance

> 状态：Phase 0A.6 领域事实源。本文定义多人云端系统必须处理的治理、生命周期与异常语义；不建立伪 KPI，不授权进入正式 schema migration。

## 1. 治理目标

多人云端系统不能继续依赖“某个老师记得”：
- 谁接手；
- 哪个 Case 很久没人看；
- 哪个学科已经停读但 Today 仍在冒任务；
- 哪个老师离职/退科前还有责任没交；
- 哪个已归档学生/学科被错误地直接恢复教学；
- 两个同名学生是不是同一个人；
- 家长后来回复的重要信息有没有被处理；
- 哪个 Draft 长期没有整理。

治理层目标是：

> **发现会让教学闭环断掉、历史失真、权限失控或数据无法恢复的真实异常，并给有权限的人明确处理动作。**

不是监控教师，也不是制造管理 Dashboard。

---

## 2. 治理异常不是核心业务状态

Learning Case 仍严格：

`new → confirmed → intervening → pending_verification → stable → closed`

不得为了治理增加：
- stale；
- orphaned；
- stubborn；
- handoff_needed；
- at_risk。

同样：
- 顽固 = 持续/失败/reopen 等事实派生；
- orphan = owner/assignment/scope 当前非法；
- stale draft = new/draft 持续异常；
- follow-up due = communication/action facts 的组合；
- inactive/archived Profile 残留 pending Action = 服务生命周期异常；
- archived→active 直跳尝试 = 生命周期异常。

异常应通过 query/view/function 等派生，处理后自然消失。

---

## 3. 管理入口应是“需要处理”

示例：

```text
需要处理

3 个 active Profile 的正式 Case 没有合法 primary Action
2 个 inactive/archived Profile 仍残留 pending Action
1 名教师将退出政治学科，但仍负责 6 个政治 Case
5 个 Case 长期 pending verification
2 个学生存在疑似重复主档案
1 个 archived Profile 被尝试直接 active
4 条家校 follow-up 已到期
7 个 Quick Capture 长期未 formalize
1 条 finalized outbound 收到家长 inbound 回复，但尚未完成教学判断
```

每条必须：
- 说明为什么出现；
- 能进入原始事实；
- 给出明确处理动作；
- 不转换成教师/学生评分。

禁止默认：教师排名、效能分、成长指数、健康分、红黄绿驾驶舱。

---

## 4. Orphan｜正式责任不能失效

### Active teaching context 必须检测
- active Subject Profile 的 formal open Case owner disabled；
- owner 已失去 matching teaching scope / Student Assignment；
- pending Action assignee disabled/relationship invalid；
- active Student+Subject 没有符合机构规则的 Lead；
- scope revoke 后仍残留 assignment/owner/action；
- active Profile formal open Case 没有 primary Action。

正常 command 应尽量阻止 orphan 被制造；异常检测只是最后防线。

### Inactive / archived Profile 不是 orphan
Profile inactive/archived 后 unresolved Case 可以没有 current primary Action，这是**已知的服务暂停/归档语义**，不是数据损坏。

前提：
- lifecycle command 已受控结束/取消 pending Actions；
- Case 写了 tracking suspended/archived event/reason；
- 不进入普通 Today；
- 不继续产生普通教学事实或 Lesson。

---

## 5. 整人离职 vs 退出某学科

### A. Membership disable
`disable_membership_and_handoff`：
- 全部 teacher/staff assignments；
- Case ownership；
- pending Actions；
- subject scopes；
- 完成交接；
- 验证无 orphan；
- 最后 membership→disabled + Session revoke；
- 历史 actor 保留。

### B. 仍在职但退出某学科
`revoke_teacher_subject_scope_and_handoff`：
- 只 inventory 目标 subject；
- 转移该科 assignments/owner/Actions；
- 验证接手人有 teaching scope + active service relationship；
- 无 orphan 后结束目标 scope；
- 其他学科完全不受影响。

不能用“整人离职”命令代替退科。

---

## 6. Student 与 Subject Profile 服务生命周期

这是 Phase 0A.6 的最终治理规则。

### Case resolution 与 service lifecycle 正交
- Case status：问题解决到哪一步；
- Student / Subject Profile status：当前是否持续提供教学服务 / 是否还在普通当前业务视图。

**停读、停科、归档都不能伪造 closed/已清零。**

### 6.1 Subject Profile 完整状态机

```text
active --deactivate_student_subject_profile--> inactive --archive_student_subject_profile--> archived
active <--reactivate_student_subject_profile-- inactive <--unarchive_student_subject_profile-- archived
```

硬规则：
- 禁止 `active → archived` 直跳；
- 禁止 `archived → active` 直跳；
- archived 可恢复，但只能先 unarchive 到 inactive；
- unarchive 只是恢复可管理状态，不代表恢复教学。

### 单学科暂停｜active → inactive

例如：

```text
Student active
语文 Profile active
数学 Profile inactive
```

`deactivate_student_subject_profile` 必须：
- 处理数学 active assignments；
- 收口数学 pending Actions；
- 保留数学 unresolved Case 的真实 status；
- 写 tracking suspended event；
- 不让这些 Cases 继续进入普通 Today；
- 不允许停科后继续写新的普通教学事实。

### 单学科归档｜inactive → archived

`archive_student_subject_profile` 只允许在：
- Profile 已 inactive；
- active assignments 已结束；
- pending Actions 已收口；
- 无 in-progress Lesson/current obligation；

之后执行。

Archive：
- 不改变 Case resolution status；
- 不创建 Action；
- 让学科主线退出普通当前业务视图；
- 保留完整历史/audit。

### 取消归档｜archived → inactive

`unarchive_student_subject_profile`：
- 只把历史学科主线恢复到可管理状态；
- 不自动创建 teacher assignment；
- 不恢复旧 Case owner；
- 不创建 pending Action；
- 不允许新 Lesson / 教学事实。

### 恢复教学｜inactive → active

`reactivate_student_subject_profile`：
- 建立/恢复合法 teacher assignment；
- inventory unresolved Cases；
- 每个仍需跟进的 Case 建合法 owner + new primary Action；
- 真能解决的 Case 走真实 closure command；
- 全部满足 active invariants 后才 profile→active。

如果来源是 archived，必须先 unarchive→inactive，再执行上述 reactivate。

### 6.2 Student 完整状态机

```text
active --deactivate_student--> inactive --archive_student--> archived
active <--reactivate_student-- inactive <--unarchive_student-- archived
```

`merged` 是独立终态，不进入这条恢复链。

规则：
- `deactivate_student` 逐 active Subject Profile 做等价 reconciliation；
- `archive_student` 只允许 inactive Student，并确保不存在 active Profile/current obligation；
- archive 时剩余 inactive Profiles 按受控语义进入 archived；
- `unarchive_student` 只 archived→inactive，不恢复 Enrollment/Profiles/teachers/Actions；
- 真正回归通过 `reactivate_student`，只恢复实际重新开课的学科；
- archived Profile 仍必须先 profile unarchive→inactive 再 reactivate；
- merged Student 不允许 unarchive/reactivate。

### 治理异常重点
- inactive/archived Profile 仍有 pending Action；
- inactive/archived Profile 仍可开始 Lesson/写教学事实；
- active Profile formal open Case 无 primary Action；
- archived→active 直跳；
- unarchive 后自动复活旧 assignment/Action；
- reactivation 后 unresolved Case 没有 next step；
- archived Student 仍有 active Enrollment/Profile/assignment。

---

## 7. 长期 Overdue / Pending Verification

Overdue 本身是工作队列；长期才可能进入治理提示。

阈值不写死成产品真理，可后续机构轻量配置。

长期 pending verification 可能源于：
- verify action 未执行；
- 学生没来；
- assignment 失效；
- 实际验证过但漏记；
- 本应停科却没有正确 deactivate Profile。

治理层只提示事实，不自动 stable/closed/顽固。

---

## 8. 多次失败 / Reopen / 长期重点

从事实派生：
- failed/partial assessment 次数；
- reopened_count；
- Case 持续时间；
- 多轮 Intervention；
- stable 后 reopen；
- 跨多个教学周期。

治理目标是推动：

> 重新分析原因 / 调整 Intervention / 必要时协调其他教师或家庭。

不是制造红色“顽固”标签或风险分。

---

## 9. Quick Capture / New Case 长期未 Formalize

`new` 允许快速保存，因此长期 new 不是立即错误，但可能代表闭环断裂。

可派生：
- 创建多久；
- 来源 Lesson；
- 是否有相似 active Case；
- 创建教师是否仍 active；
- 所属 Subject Profile 是否仍 active。

处理：
- formalize；
- 合并到已有 Case并保留来源；
- 明确 archive/discard；
- 判断不值得长期跟进。

不自动 confirmed。

Profile inactive/archived 时不能通过 Quick Capture 绕过 service state 制造新的普通教学 Case。

---

## 10. Duplicate Student / Merge

姓名不是唯一键。

创建前提供非阻塞 duplicate hint；真正重复走 `merge_students`：
- 同机构；
- 无 merge 环；
- Enrollment/Profile/Assignment/Case 冲突有策略；
- source→merged；
- source 不物理删除；
- 旧 ID 可解释；
- audit + merge record；
- 重试不重复迁移。

Finalized Communication/Report 仍须能解释原 student history。

`merged` 与 `archived` 不同：archived 可受控恢复，merged 在 V1 是身份终态。

---

## 11. Concurrency / Draft / Sync

关键 aggregate：version/expected_version。

冲突时：
- 不 silent last-write-wins；
- 不清空用户输入；
- 展示最新云端变化；
- 用户重新应用/放弃；
- 高风险 command 重新确认。

Online-first：
- 未保存；
- 保存中；
- 云端确认；
- 失败；
- encrypted local draft；
- version conflict；

必须明确区分。

Local draft：user/org/entity scoped、加密、TTL、同步成功清理，不进入正式 timeline。

---

## 12. Attachment / Evidence 治理

需要治理：
- private Storage；
- object 与 DB metadata 一致性；
- upload 成功但 DB 失败；
- DB 成功但 object 缺失；
- orphan objects；
- retention；
- backup/restore；
- 不保存永久 public URL。

依法需要真正删除个人信息时走治理流程，不等同于普通业务删除按钮。

---

## 13. Parent Communication follow-up 与 reply

### Follow-up
最终模型：
- Case-related → `Case Action(action_type=communicate)`；
- Non-case → communication 自身轻量 owner/due/status/completed；
- **不建立通用第二套 staff Todo。**

可派生异常：
- follow-up 到期未完成；
- follow-up assignee disabled/无权限。

### 异步家长回复
Parent Communication 是不可变 event。

老师 outbound finalized 后家长后来回复：
- 新增 inbound communication；
- `reply_to` 原 event；
- 不回写旧 outbound guardian_response。

治理可以提示：
- inbound reply 存在但尚未由授权教师判断是否需形成 Evidence/Case/Action；
- reply_to 指向非法 cross-student/cross-org（数据库应先阻止）。

电话/面谈同一 interaction 可以一条 conversation event，不强拆。

---

## 14. Stage Review due

如果机构明确某 period 需要复盘，可提醒：
- 哪个 Student/Subject；
- period；
- 谁负责；
- 未生成 / draft 未 finalize。

第一轮短周期 Pilot 不强迫所有学生完成阶段报告，也不以数量评价教师。

---

## 15. Audit 的目的

Audit 用于：
- role/scope 变化；
- handoff；
- Student/Profile deactivate/archive/unarchive/reactivate；
- merge；
- finalized communication/report correction；
- 高风险 commands；
- 必要治理责任追溯。

Audit 不应该：
- 复制完整敏感正文；
- 保存 Password/Token；
- 记录每次普通页面浏览形成监控海洋；
- 转成教师绩效评分。

---

## 16. 治理阈值

诸如：
- overdue > N 天；
- pending verification > N 天；
- new > N 天；
- failed assessment ≥ N 次；

必须视为**运营阈值**，不是教育学真理。

Phase 0A.6 不写死伪科学阈值；Pilot 后用真实工作节奏调整。

---

## 17. 当前冻结结论

- 治理异常优先派生，不新增核心状态/评分。
- Active context 的 orphan 应尽量由 command/DB 先阻止。
- Subject Profile inactive/archived 是合法服务暂停/归档，不等于 Case 解决。
- 停科/停读/归档绝不伪造 closed。
- `archived` 可受控恢复，但只能 `unarchive → inactive`；真正服务恢复再 `reactivate → active`。
- unarchive 不自动复活 Enrollment/assignment/owner/Action/Lesson 权限。
- 恢复服务前 unresolved Cases 必须重新建立下一步。
- Student merged 是终态，与 archived 分开。
- 整人离职与退单科是两个 handoff workflow。
- 家校 follow-up 不引入第二套 Todo；异步回复是新 communication event。
- 历史 actor、finalized snapshot、merge/archive 来源必须长期可解释。
