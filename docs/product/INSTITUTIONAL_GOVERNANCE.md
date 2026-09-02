# 机构治理与异常工作流｜Institutional Governance

> 状态：Phase 0A.6 领域事实源。本文定义多人云端系统必须处理的治理、生命周期与异常语义；不建立伪 KPI，不授权进入正式 schema migration。

## 1. 为什么需要治理层

Excel 时代很多风险依赖“某个老师记得”：
- 谁接手这个学生；
- 哪个问题很久没人看；
- 哪个老师离职前还有事情没交；
- 两个同名学生是不是同一个人；
- 哪个草稿一直没有整理；
- 家长说过的重要信息有没有后续。

多人云端系统不能把这些责任继续留在人脑里。

Xueqing 的治理目标不是监控教师，而是：

> **发现会让教学闭环断掉、历史失真、权限失控或数据无法恢复的真实异常，并让有权限的人能够处理。**

---

## 2. 治理异常不是业务状态

禁止为了治理方便往核心生命周期里增加：
- `stale`
- `orphaned`
- `stubborn`
- `handoff_needed`
- `at_risk`

例如 Learning Case 仍然只有：

`new → confirmed → intervening → pending_verification → stable → closed`

“长期未验证”是由 status + action + 时间派生的治理提示，不是第七/第八个 Case status。

同样：
- 顽固问题 = 失败/持续/复发等事实派生；
- orphan = owner/assignment 当前无效的异常；
- stale draft = new/draft 持续时间异常；
- teacher handoff needed = 人员/assignment 状态组合异常。

---

## 3. 管理入口应是“待处理异常”，不是 Dashboard

管理者最需要看到的是：

```text
需要处理

3 个正式 Case 当前没有有效负责人
5 个 Case 超过机构阈值仍未完成下一次验证
2 个学生存在疑似重复主档案
1 名教师计划停用，但仍有 12 个事项未完成交接
4 条家校沟通已到 follow-up 时间但无后续记录
7 个 Quick Capture 草稿长期未 formalize
```

每条都必须：
- 能解释为什么出现；
- 能点进去看到事实；
- 能执行明确处理动作；
- 处理后自然消失。

禁止默认展示：
- 教师排名；
- 教师效能分；
- 学生成长指数；
- “健康分”；
- 为了管理感而制造的环形图/红黄绿驾驶舱。

---

## 4. Orphan：正式闭环不能无人负责

### 必须检测
- confirmed/intervening/pending_verification/stable Case 的 owner membership 已 disabled；
- owner 与学生/学科 assignment 已失效；
- pending Case Action assignee 已 disabled；
- assignee 已不具备相应业务关系；
- active Student Subject Assignment 已无 lead（若机构规则要求 lead）；
- 撤销 Teacher Subject Scope 后仍存在对应 active assignment/Case owner/action。

### 硬规则
正常受控命令必须尽量**阻止 orphan 被制造出来**。

治理异常检测是最后防线，不是用来替代数据库不变量。

例如 `disable_membership_and_handoff` 必须先交接、最后 disabled；不能先停账号再等管理员慢慢补。

---

## 5. 教师整人离职 vs 退出某学科

这是两个不同场景。

### A. Membership disable / 离职
现有 `disable_membership_and_handoff` 继续负责：
1. teacher/staff assignments；
2. active Case ownership；
3. pending Actions；
4. 必要的责任转移；
5. audit/events；
6. 验证无 orphan；
7. 最后 membership → disabled。

### B. 仍在职，但退出一个 Subject Scope
例如老师继续教语文，但不再教政治。

不能：
- 直接删除 subject scope；
- 让原政治 assignments 静默失效；
- 留下政治 Case owner/action 仍指向该老师。

推荐评估一个领域命令：

`revoke_teacher_subject_scope_and_handoff`

语义：
1. inventory 该 membership + subject 下 active student assignments；
2. inventory Case owner；
3. inventory pending Actions；
4. 指定/验证接手人；
5. 完成交接；
6. 验证无 orphan；
7. 最后结束 subject scope；
8. 写 audit/events。

这不是普通 DELETE。

---

## 6. 长期 Overdue

Overdue 本身是正常工作队列语义；长期 overdue 才可能需要治理提示。

阈值不能写死成产品真理。例如：
- 超过 3 天；
- 超过 7 天；
- 超过 14 天。

应由机构后续轻量配置或产品默认值决定。

异常需要显示：
- overdue 多久；
- action 是什么；
- 学生/学科；
- 当前 owner/assignee；
- 为什么没有处理（若有记录）；
- 可执行下一步。

不能把“逾期天数”转化为教师评分。

---

## 7. 长期 Pending Verification

Case 在 `pending_verification` 很久可能意味着：
- verify action 没有合理 due_at；
- 到期后未执行；
- 学生长期未上课；
- 验证条件尚未出现；
- action/assignment 已失效；
- 实际验证过但老师忘记记录。

治理层应提示事实，不自动改变 status。

不能：
- 超过 N 天自动 stable；
- 超过 N 天自动 closed；
- 超过 N 天自动判“顽固”。

---

## 8. 多次验证失败 / Reopen / 长期重点

“顽固问题”继续由事实派生，例如组合：
- failed/partial assessment 次数；
- reopened_count；
- Case 持续时间；
- 多次 Intervention 后仍失败；
- stable 后再次 reopen；
- 跨多个教学周期仍 active。

治理提示应该推动：

> **重新分析原因 / 调整 Intervention / 必要时协调其他教师或家庭。**

而不是只显示一个红色“顽固”标签。

阈值需要后续用真实使用验证，Phase 0A.6 不发明伪科学分数。

---

## 9. Quick Capture / New Case 长期未 Formalize

`new` 允许课堂 10–20 秒快速保存，因此长期 new 不是数据错误，但可能意味着闭环中断。

系统可以派生：
- 创建多久；
- 是否来自某 Lesson；
- 是否存在相似 active Case；
- 是否一直没有 owner/evidence/action；
- 原创建教师是否仍 active。

处理动作：
- formalize → confirmed；
- 合并到已有 Case（必须保留来源/历史）；
- 明确丢弃/archived（需定义审计语义）；
- 判断不是值得跟进的问题。

不能为了“清空数字”自动 confirmed。

---

## 10. Student Duplicate / Merge

姓名永远不是唯一键。

创建 Student 时应提供非阻塞重复提示，参考：
- 同名；
- 年级/校区；
- 已存在联系方式关联（如合法且必要）；
- 其他最小必要匹配信息。

用户仍可能确认是不同学生。

真正重复时走受控 `merge_students(source, target)`：
- 同机构；
- 无 merge 环；
- enrollment/profile/assignment/case 冲突有策略；
- source → merged；
- source 不物理删除；
- 旧 ID 可解释；
- audit + merge record；
- 重试不重复迁移。

### 特别注意
Finalized Parent Communication / Report 中的历史 student snapshot/引用必须仍可解释，不能因为 merge 后把历史变成不可读记录。

---

## 11. Student 生命周期

Student 主状态：
- active；
- inactive；
- archived；
- merged。

不要把“升年级”改成新 Student。

### 升年级 / 换校区
使用 `student_enrollments` 历史：
- 结束旧 enrollment；
- 建新 enrollment；
- Student、Subject Profile、Case 历史保持连续。

### 暂停学习 / 停读
可进入 inactive，但要决定：
- active Case 如何处理；
- pending Action 是否取消/改 review；
- 是否需要未来复查日期；
- staff assignment 是否保留。

不能只是把 Student status 改 inactive，而留下 Today 永久 overdue。

### 回归 / Restart
重新建立新的 enrollment/assignment；历史 Student、Subject Profile、Cases 不重建。

### Archive
用于真正退出日常业务视图的学生。Archive 不是删除；历史报告、沟通、Case 仍保留。

Phase 0A.6 后续 Commands Audit 需决定是否需要 `deactivate_student_with_case_plan` 一类受控工作流，而不是普通 status update。

---

## 12. Concurrency / Version Conflict

多人协作后必须显式处理：

> 王老师刚刚更新了这个 Case；你当前看到的是旧版本。

关键快照继续使用 `version / expected_version`。

冲突时：
- 不 silently last-write-wins；
- 不清空用户尚未提交的输入；
- 展示最新云端变化；
- 用户决定重新应用/放弃自己的编辑；
- 高风险 command 重新确认。

Append-only Evidence/Observation 等简单事实如果业务上可以并存，可通过预生成 UUID + 幂等 insert 减少冲突。

状态变更、primary action replacement、Lesson completion、handoff、merge 等必须受控事务。

---

## 13. 保存失败 / Draft / Sync

Xueqing 是 online-first，不建立第二个本地正式数据库。

必须区分：
- 未保存；
- 保存中；
- 云端已确认；
- 保存失败；
- 可恢复本地 draft；
- version conflict。

本地 draft：
- user/org 隔离；
- 加密；
- TTL；
- 不包含不必要附件副本；
- 云端成功后清理；
- 不显示成正式 timeline/event；
- logout/account switch 时有明确清理策略。

“同步中”不能被误写为“已保存”。

---

## 14. Attachment / Evidence 生命周期

附件不是越多越好。

需要治理：
- 私有 Storage；
- DB metadata 与 object 一致性；
- 上传成功但 DB 失败；
- DB 成功但 object 不存在；
- orphan objects；
- 删除/更正权限；
- retention；
- backup/restore；
- 不使用公开永久 URL。

正式 Case history 引用的 Evidence 附件不能因为普通 UI 删除而失去解释能力。

如果依法/按机构规则需要真正删除个人数据，要走治理流程，并处理历史引用/审计最小化，不等同于普通业务“删除附件”。

---

## 15. Parent Communication follow-up anomaly

如果 finalized communication 有明确 follow-up：
- 到期；
- 未有完成事实；
- 负责人仍有效；

则可以进入治理/工作提醒。

但必须先解决 follow-up 的领域模型：
- 教学相关 → Case Action；
- 非教学沟通 follow-up → 可能需要轻量 staff task。

在此之前不要用一个 `follow_up_at` 日期制造“看起来有提醒、实际上没人负责”的假闭环。

---

## 16. Stage Review overdue

如果机构明确要求某阶段需要复盘，可以提醒：
- 哪个学生/学科；
- 哪个 period；
- 应由谁 review；
- 当前是未生成还是 draft 未 finalize。

但产品默认不通过“每位老师每月必须完成 N 份报告”评价教师。

---

## 17. Audit 的目的

Audit 用于：
- 高风险权限变更；
- handoff；
- merge；
- finalized report/communication correction；
- 角色/subject scope 变化；
- 重要命令；
- 必要的治理责任追溯。

Audit **不应该**：
- 复制完整敏感正文；
- 保存密码/Token；
- 记录每次普通页面浏览形成监控海洋；
- 被转成“老师行为评分”。

---

## 18. 治理异常优先派生

推荐优先通过安全 query/view/function 派生：
- orphan Case/Action；
- stale new Case；
- long overdue；
- long pending verification；
- repeated failure/reopen；
- handoff remaining；
- duplicate candidate；
- communication follow-up due；
- stage review due；
- attachment inconsistency。

除非存在真实的治理处理生命周期（例如管理员明确 acknowledge/assign/resolve 一个异常），否则不要为每种异常建独立表。

如果未来确实需要“异常工单”，应单独设计 Governance Case，而不是把它塞回 Learning Case。

---

## 19. 权限

### Teacher
看到与自己负责学生/学科相关的工作异常，例如自己的 overdue/stale draft；不需要看到全机构治理清单。

### Subject Lead
本科范围内必要治理视角。

### Advisor
负责学生范围内的跨学科协调异常，但不因此获得改写学科结论权限。

### Academic Admin
机构教学完整性、交接、跨学科协调。

### Org Admin
成员/权限/主档案/高风险治理。

角色是能力基础，最终数据范围仍需 subject/student relationship 与 RLS。

---

## 20. Commands Audit 候选

现有受控命令继续保留：
- `disable_membership_and_handoff`
- `merge_students`
- `reassign_teacher`

Phase 0A.6 建议进一步评估：
- `revoke_teacher_subject_scope_and_handoff`
- 学生 inactive/archive 前是否需要受控 case/action reconciliation command；
- finalized Parent Communication correction command；
- finalized Report correction/supersede command。

只有真正跨多个事实/存在不变量风险的动作才升级为 command；不要把所有按钮都函数化。

---

## 21. Acceptance scenarios

Product Completeness Audit 至少验证：

1. 老师离职时存在 8 个 Case owner + 5 个 pending Actions，不能先 disabled 再慢慢交接。
2. 老师仍在职但退出政治学科，语文 assignment 不受影响，政治事项必须完整交接。
3. Case pending verification 超过阈值，系统提醒但不自动 stable/closed。
4. Case 三次 failed，系统提示重新分析而不是生成“风险 87 分”。
5. Quick Capture 两周未 formalize，可以被找回处理，不自动 confirmed。
6. 两个“张伟”实际不同，不因同名强制 merge。
7. 真重复学生 merge 后，旧历史仍可解释 source ID。
8. 学生升年级后仍是同一 Student/Subject Profile 历史。
9. inactive 学生原有 pending Actions 不继续无限污染 Today。
10. 两位老师同时改变 Case，旧版本保存被拒绝且本地输入不丢。
11. 上传附件中间失败不会留下无法治理的大量 orphan object。
12. 管理员能处理真实异常，但看不到无意义教师排名。

---

## 22. 当前冻结结论

- 治理层服务闭环完整性、安全与交接，不服务教师监控。
- 异常优先派生，不污染核心业务状态机。
- 正常命令应阻止 orphan；异常检测只是最后防线。
- Membership disable 与 Subject Scope revoke 必须区分两种 handoff。
- Student 生命周期保持一份主档案，升年级/回归不重建 Student。
- 并发冲突必须显式，不允许 last-write-wins。
- 本地 draft 不是第二数据库。
- 管理端优先显示可处理事实，不做伪 KPI Dashboard。
