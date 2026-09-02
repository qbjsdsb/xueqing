# Initial Diagnosis Workflow｜新生 / 新学科初诊工作流

> 状态：Phase 0A.6 领域事实源。本文定义初诊如何进入连续学情闭环；不建立与 Learning Case 平行的永久“初诊问题表”。

## 1. 定位

Initial Diagnosis 是 **Student + Subject scoped 的工作流**：

> 教师第一次系统理解某学生某学科，并把真正值得持续跟进的问题转化为 Learning Case + Next Action。

它不是：
- 一次性“填完即结束”的表单；
- 招生 CRM；
- 第二套 Case 台账；
- 要求试听课当场填完所有字段的行政流程。

目标是让新学生 / 新学科进入系统后不是空白页，同时保持课堂低负担。

---

## 2. 推荐入口

```text
确认 / 建立 Student
→ 建立或恢复 Student Subject Profile
→ Profile = active
→ 建立合法诊断教师关系
→ 记录当前定位 / 优势
→ 捕捉 candidate problems
→ 去重与证据判断
→ 确认真正需要长期跟进的 Cases
→ 建立第一批 primary Actions
```

初诊可以跨一次以上真实教学会话完成，不要求一次点击全部 formalize。

---

## 3. Student identity 先于初诊

创建学科初诊前先确认 Student identity。

最低上下文：
- display name；
- 必要 enrollment / grade / campus context；
- subject；
- 机构实际需要的最小查重字段。

姓名不是唯一键。

如果存在疑似重复：
- 给非阻塞 duplicate hint；
- 确认为同一人 → 复用 Student；
- 确认不是同一人 → 允许继续；
- 真重复 → 以后走受控 `merge_students`。

同一学生同时开语文和数学：只创建一个 Student，建立两个 Subject Profiles。

---

## 4. Subject Profile 是初诊的学科主线

每个 Student + organization subject 只有一个连续 Subject Profile。

### 不存在
受控建立 Profile，并在实际教学开始前使其进入 `active`。

### 已 active
直接进入现有连续学情主线。

### inactive
先完成 `reactivate_student_subject_profile` 所需 reconciliation，再 active。

### archived
禁止直接 active：

```text
archived
→ unarchive_student_subject_profile
→ inactive
→ reactivate_student_subject_profile
→ active
```

初诊不能成为绕过 service lifecycle 的后门。

---

## 5. 谁可以产生初诊中的实际教学事实

如果初诊会追加：
- Intervention；
- Assessment；
- 教学型 Evidence；
- Lesson teacher 行为；

必须完整通过统一 Teaching Fact Gate：

```text
live session
+ active membership
+ teacher capability
+ matching active teaching subject scope
+ target Student Subject Profile = active
+ 合法 active Student Assignment
  或本次由受控 command 建立并验证的合法 Lesson relationship
+ operation-specific permission
```

任何一项缺失都不能写实际教学事实。

### 管理员授权不是 bypass

管理员可以：
- 建立 / 恢复 Profile；
- 按规则激活 Profile；
- 建立可审计的 Lead / Collaborator teacher assignment；
- 执行治理动作。

管理员不能：

> 仅用“允许某老师初诊”这个管理动作，跳过 teacher capability、active Profile 或合法 teacher relationship。

如果需要临时诊断教师，也必须用受控、可审计的 assignment / Lesson relationship 表达。

---

## 6. 当前学情定位

目标是给后续教师一个简洁的当前教学上下文，而不是给学生打能力分。

可以使用：
- 可选粗定位；
- 一两句短摘要。

Excel 中“基础薄弱 / 中等待提升 / 中等稳定 / 培优拔高”可以作为默认产品语言参考，但不是不可变人格标签，也不替代 Evidence / Case。

当前 Foundation 已把 positioning / strengths 语义放入 Student Subject Profile；具体稳定 code 的数据库实现留 migration design，不再把“字段归属”当 Phase 0A.6 未决问题。

---

## 7. Strengths｜优势

允许记录少量真正帮助教学的优势，例如：
- 文言基础较稳；
- 课堂表达积极；
- 能较快根据反馈修改答案。

规则：
- 可选；
- 没有足够证据就不填；
- 不造“潜力分 / 天赋值”；
- 优势与问题同时可见，避免系统退化为“学生缺陷管理器”。

---

## 8. Candidate Problems｜候选问题

课堂 / 试听中可快速捕捉：

```text
student + subject 已知
→ 一句问题标题
→ 可选 Evidence / 补充
→ new Case candidate
```

课后再判断：
- knowledge；
- habit；
- exam_strategy；
- other。

看到一个错题不等于必须创建一个正式 Case。

---

## 9. 哪些问题进入正式 Case

### A｜值得持续跟进
走 `confirm_case`。

Active Profile 下至少需要：
- 清楚问题定义；
- 可解释 Evidence；
- case type / taxonomy；
- 合法 owner；
- priority；
- first pending primary Action。

### B｜证据不足
保留 `new`，继续观察；或按产品规则明确丢弃未形成正式业务事实的草稿。

### C｜一次性错误
不必 formalize Case；若课堂事实仍有价值，可保留合法 Evidence / Lesson note。

---

## 10. Root Cause 的时机

第一次接触学生时，不强迫老师写“确定根因”。

规则：
- new 可无 root cause；
- formalize 时使用“当前原因判断”；
- 后续 Evidence 变化可修正；
- 重要变化留 event / audit；
- 不为了“初诊完成率”编造确定结论。

---

## 11. 初步整改方案如何进入系统

不要把未来几周所有计划塞进一段大文本。

推荐拆成：
- 当前策略方向；
- 第一 pending primary Action。

例如：

```text
策略方向：稳定“先圈依据、后概括”的步骤
下一步：下次课完成 2 道示范练习
```

后续由 Intervention / Assessment / Action 持续演进。

---

## 12. 初诊不是永久真相

以后会发生：
- positioning 更新；
- strengths 更新；
- root-cause judgment 修正；
- Case stable / closed / reopen；
- teacher assignment 变化；
- Subject Profile inactive / archived / unarchive / reactivate。

系统保留连续事实，不把第一次判断改写成“老师当初就知道后来的答案”。

---

## 13. Initial Diagnosis Snapshot｜最终 Phase 0A.6 决策

**V1 / Phase 0B 不新增 `initial_diagnoses` 平行大表，也不把独立 initial snapshot 作为进入 Phase 0B.0 的 Gate。**

已有自然事实源：
- Student；
- Subject Profile 当前 positioning / strengths；
- Evidence；
- Learning Case；
- Action；
- Lesson / actor / timestamps。

仍存在一个合理的未来产品问题：

> 几个月后，领导 / 接手老师是否真的需要“一键查看第一次正式建档时的整体基线快照”？

因此将其明确列为 **P2 DEFER WITH PILOT VALIDATION**：
- Pilot 证明真实需要 → 设计轻量 immutable baseline snapshot / event；
- 不需要 → 不为文档完整性造表；
- 即使未来新增，也只能引用 / 冻结当时事实，不能成为第二套 Learning Case。

这项不会阻塞 Phase 0B.0 Cloud/Auth Spike，也不会在 migrations 中暗中先建表。

---

## 14. 多教师协作初诊

可能：
- Lead 完成主体诊断；
- Collaborator 补本人真实 Evidence / Assessment；
- Subject Lead 做专业 review。

规则：
- 每条实际教学事实保留真实 actor；
- Subject Lead 只有 leadership scope 时只能 review，不能伪造教学行为；
- 所有实际教学 actor 均需完整 Teaching Fact Gate；
- 最终 Case owner / 状态命令仍按 Commands / Role Matrix 控制。

---

## 15. 初诊与 Lesson

试听 / 诊断如果本身是真实教学会话，可以用 Lesson context：

```text
Lesson
→ Evidence
→ Quick Capture Cases
→ post-lesson formalize
```

Lesson 必须通过完整 Teaching Fact Gate。

V1 不因为“试听”扩张成招生 CRM，也不急于增加 `lesson_purpose`，除非真实导航 / 统计需要证明它是新的业务事实。

---

## 16. 初诊与家校

初诊后可以形成第一次家校反馈：
- 当前优势；
- 主要问题；
- 优先整改方向；
- 家庭配合建议。

但：
- 反馈来源必须是已有合法教学事实；
- 家校不是初诊完成的强制阻塞；
- 不要求完整 Guardian 档案才能记录教学 Case；
- Parent Communication 仍遵守 Draft / finalized event 语义。

---

## 17. UX 节奏

### 课堂 / Android
目标：10–20 秒 Quick Capture，不要求完成复杂诊断表。

### 课后 / Windows
整理定位、优势、候选问题并 formalize 真正需要的 Cases。

目标是让老师完成真正有价值的判断，而不是显示：

> 初诊表填写完成率 100%。

---

## 18. Acceptance Scenarios

### A. 第一次试听只发现一个值得跟进的问题
允许只确认一个 Case，不要求三类各填一条。

### B. 第一次课看不出根因
允许保持 new / 当前原因判断不确定，不能编造。

### C. 同名学生已存在
复用真实 Student 或确认不同人；不靠姓名硬唯一。

### D. 已有语文 Profile，新老师接手
不建立第二套初诊档案；做接手复核 / 当前定位更新，旧 Case 连续。

### E. 新开数学
复用 Student；数学 Profile active + 合法 teacher relationship 后再产生实际教学事实。

### F. 初诊发现多个一次性错误
不鼓励全部 formalize。

### G. Profile inactive/archived，管理员点“允许初诊”
拒绝实际 Intervention / Assessment / Lesson 写入；必须按 service lifecycle 恢复到 active，并建立合法 teacher relationship。

### H. 只有 Subject Lead leadership scope，无 teacher relationship
可以按治理权限 review，但不能记录自己实施了 Intervention / Assessment。

### I. Pilot 后仍没人需要“第一次整体基线页”
继续不建 Initial Diagnosis Snapshot 表；不影响正常闭环。

---

## 19. 冻结结论

1. Initial Diagnosis 是 Student + Subject 工作流，不是第二套永久台账。
2. Student identity / Subject Profile 先于教学事实。
3. 定位与优势保留在 Subject Profile 当前上下文。
4. 候选问题不等于全部 formal Case。
5. root cause 是可修正判断，不强迫首次编造。
6. 初步整改转为策略方向 + 第一 primary Action。
7. 实际教学初诊必须完整通过 Teaching Fact Gate；管理员授权不能 bypass。
8. inactive/archived Profile 不能通过“初诊”绕过 service lifecycle。
9. V1 不建 `initial_diagnoses` 平行表。
10. 独立 Initial Diagnosis Snapshot = **P2 Pilot validation**，不是 Phase 0B.0 前置 Gate。
