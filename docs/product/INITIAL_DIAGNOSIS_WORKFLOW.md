# Initial Diagnosis Workflow｜新生/新学科初诊工作流

状态：Phase 0A.6 product foundation draft  
目标：把领导 Excel 的“试听初诊 · 三类问题总台账”升级为机构多人软件中的自然入口，同时避免建立一套与 Learning Case 平行的重复台账。

---

## 1. 初诊的角色

Initial Diagnosis 不是一张永久表，而是：

> **教师第一次系统理解某学生某学科，并把重要问题正式转化为后续闭环的工作流。**

它解决：
- 新学生第一次进入系统后不是空白档案；
- 新老师接手时知道当前依据；
- 试听/诊断发现的问题不会留在纸面或聊天里；
- 优势与问题同时被理解；
- 真正值得跟进的问题进入 Learning Case + Next Action。

---

# 2. 初诊不是“完整填表”

禁止设计：

```text
新建学生
→ 强制填 20 个字段
→ 填完整家长资料
→ 填完整三类问题
→ 每个问题写根因
→ 每个问题建三阶计划
→ 才能保存
```

这会把试听/第一次课变成行政填表。

推荐分层：

```text
最低身份
→ 进入教学
→ 快速捕捉事实
→ 课后整理初诊
→ 正式 Case / Action
```

---

# 3. Initial Diagnosis 的上下文

初诊是 **Student + Subject** scoped。

同一学生可能：

```text
张三
├─ 语文：已完成初诊
├─ 数学：已完成初诊
└─ 英语：尚未开始
```

不能只有一个全学生通用“初诊完成”。

---

# 4. 前置：先解决 Student identity

建立初诊前先确认 Student identity。

最低输入建议：
- display name；
- 必要的当前 enrollment/grade context；
- subject；
- 必要时 student_code/校区等用于查重的机构字段。

### 查重

姓名不能硬唯一。

创建前显示非阻塞 duplicate hint，例如：

> “机构内已有 2 名同名学生，请确认是否为同一人。”

如果是同一学生：
- 复用已有 Student；
- 新建/启用该 Subject Profile。

如果确认不同学生：
- 允许继续；
- 使用稳定 ID 区分。

---

# 5. Subject Profile 建立

初诊针对的学科应有唯一 `student_subject_profile`。

如果不存在：
- 由受控 workflow 建立；
- 不要求老师先理解数据库概念。

如果已经存在：
- 不重复建立；
- 初诊进入现有连续学情主线。

---

# 6. 谁可以执行初诊

执行者至少需要：
- live session；
- active membership；
- teacher capability；
- matching active teaching subject scope；
- 对该 student+subject 有合法 assignment 或由管理员明确授权的初诊/接手流程。

### 新学生尚未分配老师怎么办

推荐业务顺序：

```text
创建/匹配 Student
→ 建立 Subject Profile
→ 指定 Lead teacher（或明确临时诊断负责人）
→ 初诊
```

不建议为了初诊而绕开 assignment-level 权限，让任意同科老师看到所有新学生。

---

# 7. 初诊信息结构

## 7.1 Current Positioning / 当前学情定位

目标：一句到几句让接手老师快速理解当前教学位置。

示例：

> 基础较扎实，现代文信息提取稳定；作文审题和结构是当前主要提升点。

Excel 的四档：
- 基础薄弱；
- 中等待提升；
- 中等稳定；
- 培优拔高；

可以作为输入辅助，但 Phase 0A.6 建议**不把它单独作为足以代表学生的最终结论**。

### 推荐产品方式

```text
可选粗定位 + 必要时短摘要
```

例如：

```text
当前定位：中等待提升
补充：阅读基础尚可，作文结构是主要卡点。
```

最终数据模型是否保存 enum + summary 在 Data Model revision 决定。

---

## 7.2 Strengths / 当前优势

建议允许记录 1–3 个有教学价值的优势。

示例：
- 文言基础较稳；
- 课堂表达积极；
- 修改反馈接受度高。

### 不强制

如果第一次课尚无足够证据，可以暂不写，不得为了“档案完整”编造优势。

---

## 7.3 Candidate Problems / 候选问题

课堂/诊断过程中可以快速记录多个 `new` Case candidates：

```text
问题标题
+ 可选 Evidence/备注
```

课后再整理：
- knowledge；
- habit；
- exam_strategy；
- other。

---

# 8. 初诊问题不是全部都要 confirmed

试听/诊断可能出现很多一次性失误。

系统不应鼓励：

> “看到一个错题 = 一个正式 Case”。

formalize 时教师判断：

### A. 值得正式跟进

`new → confirm_case`

要求：
- 清楚问题定义；
- Evidence；
- case type；
- owner；
- priority；
- first primary Action。

### B. 证据不足

保留 new，安排补充观察；或合理丢弃未形成正式业务事实的本地草稿。

### C. 一次性错误/无需长期跟进

不必创建正式 Case；如果作为课堂事实有价值，可保留 Evidence/lesson note，但不把 Case 列表塞满。

---

# 9. 初诊的优先级

Excel 使用：
- 高；
- 中；
- 低。

Foundation 当前 Case priority：
- low；
- medium；
- high；
- urgent。

Phase 0A.6 决策：继续以 Foundation priority 为领域事实源，不再新建“初诊优先级”第二套 enum。

UI 可以对普通教师主要展示：
- 重点；
- 常规；
- 较低；
- 紧急（少用且需明确含义）。

Priority 是工作排序辅助，不是学生严重程度评分。

---

# 10. Root Cause / 根本原因的时机

Excel 初诊要求“问题根本原因”。

但第一次接触学生时，教师未必已有可靠证据。

因此：
- `new` 不要求 root cause；
- confirmed 时可允许“当前原因判断”；
- 不得强迫教师为了完成初诊编造确定原因；
- 后续 Evidence 变化时可以修正判断并留下事件历史。

推荐文案：

> **当前原因判断**

比“根本原因（必填）”更符合真实教学认识过程。

---

# 11. Initial Remediation / 初步整改方案

Excel 初诊要求“初步整改方案”。

Xueqing 应把它拆成：
- 教师判断/策略方向；
- **第一个 primary Action**。

避免一个大文本里同时写：

> 先讲一遍，然后做三道题，下周小测，如果不会再联系家长。

推荐：

```text
策略方向：先稳定“先圈依据、后概括”的步骤
第一行动：下次课完成 2 道示范练习
```

后续由 Action/Intervention/Assessment 自然演进。

---

# 12. 初诊完成的建议工作流

```text
1. 确认 Student / Subject
2. 确认 Lead/诊断教师关系
3. 记录当前学情定位（可简）
4. 记录已观察优势（可选）
5. 收集候选问题
6. 去重/合并相近问题
7. 将真正需要跟进的问题分类
8. 补必要 Evidence
9. 教师写当前原因判断
10. 设置 priority / owner
11. 建立 first primary Action
12. confirm Cases
13. 显示“当前最重要的事”
```

初诊可以跨一次以上教学会话完成，不要求一次点击把所有 Case 都 formalize。

---

# 13. 初诊完成 ≠ 所有字段永久不变

Initial Diagnosis 是起点。

以后：
- 当前学情定位会变化；
- 优势会增加；
- 原因判断会修正；
- Case 会 stable/closed/reopen；
- teacher assignment 会变化。

系统必须保留连续性，而不是把初诊表当永久真相。

---

# 14. 初诊是否需要独立 `initial_diagnoses` 表？

Phase 0A.6 当前建议：**V1 不急于新增一张与 Case 平行的“初诊主表”。**

原因：
- 大部分初诊事实已有自然归属：Student、Subject Profile、Case、Evidence、Action；
- 新建专门表容易让教师以后同时维护“初诊问题”和“当前 Case”；
- 领导真正需要的是初诊工作流与最初判断可解释，不是必须有一张叫 initial_diagnoses 的表。

### 仍需解决的真实事实

现有 `student_subject_profiles` 只有 status 等基础字段，尚不能直接表达：
- 当前学情定位；
- 当前优势摘要；
- 该学科首次正式接手/建档时间。

因此 Data Model revision 必须进一步决定这些事实的归属。

---

# 15. Subject Profile 增强候选

Phase 0A.6 建议评估：

```text
student_subject_profiles
  current_positioning_code?     // 可选粗定位
  current_positioning_summary?  // 可选文字
  strengths_summary?            // 当前简要优势
  teaching_cadence_note?        // 可选；若真实有用
  started_at / started_on?      // 该学科进入机构教学主线的业务时间
  version                       // 若这些是关键可变快照
  updated_at
```

### 风险

这些是“当前摘要”，会被覆盖。

因此重要改变是否需要 profile-level event/audit 必须在 Data Model audit 讨论。

不能为了省事让“初诊时的判断”完全无历史可解释性。

---

# 16. 是否增加 Initial Diagnosis Snapshot

有两个候选方向：

### Option A｜只保留当前 Subject Profile summary + underlying facts

优点：
- 简单；
- 低录入负担；
- 不新增表。

缺点：
- 难直接还原“第一次接手时整体判断”。

### Option B｜初诊完成时生成一个轻量 snapshot/event

保存：
- diagnosed_at；
- diagnosed_by；
- positioning snapshot；
- strengths snapshot；
- source cutoff / related Cases。

优点：
- 交接时能解释“初始基线”；
- 领导的“试听/建档日期”有明确事实。

缺点：
- 新增领域对象；
- 需避免变成第二套 Case 表。

### 当前决策

本文件**不立即冻结 Option A/B**。

要求后续 Data Model/Product Completeness Audit 用以下问题决定：

> 真实机构是否需要在几个月后明确看到“第一次试听/建档时，老师当时如何定位这个学生”？

如果需要，轻量 initial diagnosis snapshot 是新的真实历史事实；如果不需要，就不为文档完整性造表。

---

# 17. 多学科初诊

如果同一学生同时报语文和数学：

```text
Student 只创建一次
↓
语文 Subject Profile + 语文初诊
数学 Subject Profile + 数学初诊
```

不得创建两个 Student。

家长联系方式等身份/guardian 数据只保存一次。

---

# 18. 多教师协作初诊

可能出现：
- Lead teacher 完成主体诊断；
- Subject Lead 参与复核；
- Collaborator 补 Evidence。

系统应记录各自真实 actor，而不是所有记录都显示 Lead teacher。

最终 Case owner/专业结论确认仍按授权命令处理。

---

# 19. 初诊与 Lesson

如果初诊来自试听课，推荐把这次实际教学会话记录为 Lesson context。

例如：

```text
Lesson
→ Evidence
→ Quick Capture Cases
→ post-lesson formalize
```

是否新增 `lesson_purpose = diagnosis / regular / review` 暂不冻结；只有真实导航/统计需要时才加入。

不要因为叫“试听初诊”就扩张成招生 CRM。

---

# 20. 初诊与家长

初诊后可能需要首次家长反馈：
- 当前优势；
- 主要问题；
- 优先整改方向；
- 家庭配合建议。

但：
- 家长反馈从已确认教学事实生成；
- 不应让家长反馈成为初诊完成的阻塞条件；
- 不要求完整 guardian 资料才能记录教学 Case。

---

# 21. 初诊 UI 目标

Windows：适合课后整理、比较、确认多个 Case。

Android：适合试听/课堂中快速捕捉，不适合要求在手机上完成复杂诊断大表。

### 推荐节奏

课堂：

```text
10–20 秒 Quick Capture × 若干
```

课后：

```text
5–10 分钟内完成初诊整理
```

不是要求课堂内边教边完成所有诊断字段。

---

# 22. 完成后的 Student Detail

初诊整理完成后，学生页应能快速回答：

```text
当前定位是什么？
优势是什么？
现在最重要的 1–3 件事是什么？
每件事下一步是什么？
```

而不是显示：

> “初诊表填写完成率 100%”。

---

# 23. Acceptance scenarios

### A. 第一次试听只发现一个问题

允许只确认一个 Case，不要求三类问题各填一条。

### B. 第一次课看不出根因

允许 new / 当前原因判断为空或低确定性；不能编造。

### C. 同名学生已经存在

查重提示；确认同一人后复用 Student。

### D. 张三已有语文 Profile，新老师接手

不重新初诊建一套平行档案；可以做“接手复核/当前定位更新”，历史 Case 保留。

### E. 同时新开数学

新增数学 Subject Profile，独立学科初诊；Student 不重复。

### F. 初诊发现 8 个一次性错误

不鼓励全部 confirmed；教师筛选真正值得持续追踪的问题。

### G. 初诊后一个月定位改变

更新当前 Subject Profile context，并按最终选定历史策略保留可解释性；不修改旧 Case 事实来伪装当初就知道。

---

# 24. 决策结论

Phase 0A.6 当前冻结：

1. Initial Diagnosis 是 Student+Subject 工作流，不是机构级一次性字段；
2. 初诊不建立与 Learning Case 平行的永久问题台账；
3. 学情定位与优势必须保留产品位置；
4. 初诊候选问题不等于全部 confirmed Case；
5. root cause 允许随着 Evidence 修正，不强迫第一次课编造；
6. 初步整改方案应转化为策略方向 + 第一 primary Action；
7. 多学科复用同一 Student identity；
8. 初诊过程尊重 teacher subject scope / assignment 权限；
9. 当前 Subject Profile 需要增强以承载教学上下文，具体字段/历史策略待 Data Model audit；
10. 是否需要独立 Initial Diagnosis snapshot 作为唯一尚未冻结的关键模型决策，必须在进入 Phase 0B 前给出结论。
