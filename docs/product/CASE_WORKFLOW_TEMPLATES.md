# Case Workflow Templates｜三类问题的默认教学闭环

状态：Phase 0A.6 product foundation draft  
目标：保留领导“三类问题 + 三阶订正”的教学方法，同时避免把不同问题机械塞进同一套流程或三套重复数据库。

---

## 1. 核心决策

所有问题共享统一领域对象：

```text
Learning Case
+ Evidence
+ Teacher Judgment
+ Intervention
+ Assessment
+ Case Action
+ Case Event
```

但根据 `case_type` 提供不同的**默认教学 Workflow Template**：

1. `knowledge`：知识漏洞；
2. `habit`：学习习惯；
3. `exam_strategy`：考试技巧；
4. `other`：自定义。

### Template 不是 lifecycle

所有 Case 生命周期仍然只有：

```text
new → confirmed → intervening → pending_verification → stable → closed
```

“三阶”“连续观察”“模拟迁移”等是**怎样干预和验证**，不是新的 status。

---

# 2. 为什么必须区分三类 workflow

领导 Excel 明确把问题分类为：
- 知识漏洞；
- 学习习惯；
- 考试技巧。

如果系统只是换一个标签颜色，但后续按钮和验证逻辑完全相同，会丢失真正的教学语义。

例如：

> “阅读原因概括不知道怎么找依据”

可以通过教学、相似题、延迟验证形成类似三阶闭环。

但：

> “答案有两问时经常不分点”

如果硬要求“当堂订正 → 相似题 → 次课满分”就宣布清零，容易产生假闭环。

习惯问题需要在多个自然任务中观察目标行为是否真正出现。

---

# 3. 共通不变量

无论哪种 Case：

1. `new` 可先快速捕捉；
2. confirmed 前必须有可解释 Evidence；
3. confirmed 起必须有一个 pending primary Action；
4. Intervention 表达“已经做了什么”；
5. Action 表达“下一步准备做什么”；
6. Assessment 是一次检查结果，不自动改变最终状态；
7. failed/partial 不删除历史；
8. stable 仍需 review/verify Action；
9. closed 后复发使用 reopen；
10. 不因某模板步骤“完成”而绕过 Case lifecycle command。

---

# 4. Knowledge Workflow｜知识漏洞

## 4.1 适用问题

例如：
- 文言实词理解错误；
- 分数通分步骤不稳定；
- 某语法规则混淆；
- 某题型方法知识缺口。

核心问题通常可以通过：

> 讲解/纠错 → 同构迁移 → 延迟独立验证

获得较清楚的证据。

---

## 4.2 默认“三阶订正”

### 一阶｜当堂订正

目标：

> 学生是否真正理解当前错误，而不是只抄出正确答案？

常见事实：
- Intervention：重新讲解、示范、对比、口头复述；
- Evidence：学生能够说出正确规则/步骤；
- Assessment：即时检查 passed/partial/failed。

推荐产品语言：
- 完成订正；
- 仍未完全理解。

若一阶失败：
- Case 仍 intervening；
- 下一 Action 继续 reteach/review；
- 不进入二阶只是为了“走流程”。

---

### 二阶｜相似题巩固

目标：

> 换一个相似情境后，学生是否能迁移刚学会的方法？

常见：
- Action：practice；
- Evidence：相似题完成结果/过程；
- Assessment：passed/partial/failed。

领导 Excel 的“全部完成 / 部分出错 / 未完成”可以作为 UI 文案/摘要，不需要写成固定数据库枚举。

若 partial/failed：
- 教师可补新的 Intervention；
- 再安排 practice；
- 不强制每个 Case 恰好只有一次二阶。

---

### 三阶｜延迟独立验证

目标：

> 隔一段时间、减少提示后，学生还能否独立完成？

这一步必须尽可能降低即时记忆/教师提示造成的假通过。

常见：
- primary Action：verify；
- Assessment：passed/partial/failed；
- Evidence：小测/课堂新题/作业中的独立表现。

领导 Excel 的：
- 满分通关；
- 仍有漏洞；
- 需要再次跟进；

属于一次 verification 的业务表达。

### 重要

```text
三阶 passed
≠ closed
```

三阶通过后：
- Case 可进入 `pending_verification`；
- 授权教师确认是否有足够证据进入 `stable`；
- stable 后保留后续 review/verify；
- 最终才可能 closed/清零。

---

# 5. Knowledge Failure Loop

知识 Case 不应表现成一次性流程图。

真实路径可能是：

```text
一阶 passed
→ 二阶 partial
→ 新 Intervention
→ 二阶再次 practice passed
→ 三阶 failed
→ 重新分析原因
→ Intervention
→ 三阶 verify passed
→ stable
→ review
→ closed
```

系统必须允许这种历史，不得为了“阶段进度 3/3”强迫老师改事实。

---

# 6. Habit Workflow｜学习习惯

## 6.1 适用问题

例如：
- 阅读答案不分点；
- 作文直接动笔不列提纲；
- 做题不回看题干限制词；
- 订正只改答案不说明原因。

### 禁止的人格化写法

不要记录：
- 懒；
- 不认真；
- 自制力差；
- 态度有问题。

应记录可观察行为：

> 最近 4 次两问型阅读题中，有 3 次未主动分点作答。

---

## 6.2 第一步｜定义目标行为

Habit Case confirmed 前，至少应能回答：

```text
当前可观察行为是什么？
希望出现的目标行为是什么？
在哪些场景观察？
```

示例：

当前：
> 两问及以上阅读题经常连续写成一段。

目标：
> 识别多个得分点时主动用序号分点作答。

---

## 6.3 第二步｜策略干预

Intervention 可能是：
- 审题时圈分值；
- 写答案前先列得分点数量；
- 使用固定答题检查步骤；
- 课堂显性提示。

关键是记录：

> 教师实际用了什么策略。

---

## 6.4 第三步｜多情境连续观察

Habit 的验证不应只依赖一道“专门为它出的测试题”。

更有价值的是多次自然任务：
- 课堂练习；
- 作业；
- 小测；
- 模拟考试。

每次可形成 Evidence/Assessment：

```text
有提醒时做到
无提醒时未做到
无提醒时做到
模拟考试时做到
```

### 不设置伪科学统一阈值

Phase 0A.6 不规定：

> 连续 3 次 = 自动 stable。

不同习惯、频次和课堂情境差异很大。

系统可以汇总：
- 最近 N 次观察；
- 有/无提示；
- 场景；
- 趋势。

最终 stable 仍由授权教师确认。

---

## 6.5 Habit Adjustment Loop

如果多次未改善：

```text
当前策略无效
→ 重新分析原因
→ 调整 Intervention
→ 继续观察
```

这比“再布置一次同样任务”更符合领导的跨周迭代理念。

---

# 7. Exam Strategy Workflow｜考试技巧

## 7.1 适用问题

例如：
- 阅读题不按分值组织答案；
- 作文审题后没有时间规划；
- 考试后半段时间不足；
- 文言文先看选项导致理解被误导；
- 数学大题步骤缺失导致过程分丢失。

它通常不是“知识不知道”，而是：

> 方法是否能在考试约束下真正使用。

---

## 7.2 第一步｜方法显性化

教师明确教学策略：
- 识别题型；
- 识别限制；
- 执行步骤；
- 自检规则。

例如：

```text
审题
→ 圈主体/范围/分值
→ 估计得分点数量
→ 组织答案
→ 回扣题干
```

---

## 7.3 第二步｜Guided Application

在有支持的情况下应用：
- 教师提问；
- 模板提示；
- 分步练习。

验证学生是否理解策略，而不是记住一句口号。

---

## 7.4 第三步｜Timed / Simulated Transfer

逐渐接近真实考试条件：
- 限时；
- 混合题型；
- 减少提示；
- 模拟卷/真实阶段测验。

核心：

> 策略能否迁移到真实考场条件。

---

## 7.5 Independent Verification

最终验证：
- 无即时提醒；
- 真实/近真实任务；
- 有清楚 Evidence。

一次表现好仍不自动 closed。

---

# 8. Other Workflow｜其他

真实教学问题不应为了数据整齐强行塞进前三类。

`other` Case：
- 仍遵守统一 lifecycle；
- 仍需要 Evidence/Action；
- 教师自定义 Intervention/Verification；
- UI 不强制显示“三阶”。

如果大量 Case 长期落入 Other，应在教研/产品审查中评估 taxonomy 是否缺失，而不是在运行时不断增加 enum。

---

# 9. Workflow Template 与数据库的边界

## V1 默认不新增“当前第几阶”作为权威状态

原因：
- 一阶/二阶可能重复；
- 三阶失败会返回干预；
- Habit/Exam Strategy 结构不同；
- Case lifecycle 已是唯一状态机。

如果存：

```text
current_stage = 2
```

很容易与实际 Evidence/Action 不一致。

### 推荐

阶段视图从当前 Case type + Actions + Events + Assessments 派生。

例如 Knowledge UI 可以显示：

```text
三阶订正
一阶｜完成订正        ✓
二阶｜相似题巩固      ✓ / 2 次
三阶｜延迟独立验证    待验证
```

这是工作视图，不是第二套 lifecycle。

---

# 10. 是否需要 workflow_template_version

Phase 0A.6 当前建议：**V1 暂不将 template version 作为 Case 必填业务字段。**

理由：
- 模板首先服务教师引导；
- 历史真实 Evidence/Intervention/Assessment/Action 已足够解释做了什么；
- 过早引入模板版本会增加正式 Case 复杂度；
- 领导方法未来变化时，不应为了模板名变化重写历史事实。

只有当未来需要：
- 不同机构配置不同流程；
- 教研需要统计模板执行；
- 自动生成复杂 action plan；
才重新评估 template entity/version。

---

# 11. Quick Capture 与 Workflow

课堂中 10–20 秒 Quick Capture：

```text
student/subject 已知
→ 一句问题标题
→ 可选补充
→ new Case
```

不要求当场：
- 判断三类；
- 选择 workflow；
- 分析 root cause；
- 创建三阶所有任务。

课后 formalize/confirm 时再选择 case type，系统提供对应默认 workflow 建议。

这样避免领导的方法论反过来增加课堂记录负担。

---

# 12. Confirm Case 时模板如何出现

推荐流程：

```text
new Case
→ 教师确认问题
→ 选择/确认 case_type
→ 系统展示该类型默认下一步建议
→ 教师调整
→ confirm_case
```

例如 Knowledge：

> 建议下一步：完成当堂订正并记录一次即时检查。

Habit：

> 建议下一步：先明确要观察的目标行为和下一次观察场景。

Exam Strategy：

> 建议下一步：先完成一次方法讲解/引导应用。

系统不自动生成一串无法修改的三阶任务。

---

# 13. Case 状态与 Workflow 的关系

一个典型 Knowledge Case：

```text
new
→ confirmed
→ intervening
   ├─ 一阶
   ├─ 二阶
   └─ 三阶准备
→ pending_verification
→ stable
→ closed
```

但这只是常见路径，不是硬映射。

例如三阶 failed：

```text
pending_verification
→ intervening
```

如果合法状态转移规则允许，则通过受控 command 记录为什么继续干预。

Workflow 不能自行创造非法 lifecycle transition。

---

# 14. 长期/顽固问题的 Workflow 响应

当系统派生出：
- 多次 failed；
- 长期 partial；
- 多轮相同 Intervention 无改善；
- repeated reopen；

产品优先提示：

> **重新分析原因**

而不是：

> 再做一次同样的下一阶。

建议提供教师复盘入口：
- 原 root cause 是否仍成立；
- 是否需要新的 Evidence；
- 干预策略是否重复无效；
- 是否需要 Collaborator/Subject Lead 参与；
- 是否需要家校协同。

---

# 15. 家校与三类 Workflow 的关系

家校不是第四类 Case workflow。

它可以支持任何 Case：

### Knowledge
> 家庭只监督完成一次指定相似题，不增加额外题量。

### Habit
> 家庭只观察是否先列提纲，不替孩子修改内容。

### Exam Strategy
> 家庭帮助保持一次完整限时训练环境。

家庭配合要求必须具体、低负担、可 follow-up。

---

# 16. Lesson 与 Workflow

Lesson 是 Workflow 的主要执行上下文之一。

课前：
- 显示本节要执行/验证的阶段；

课中：
- 记录实际 Intervention/Assessment；

课后：
- 根据结果建立下一 Action；
- 不要求老师另外维护“当前第几阶”台账。

---

# 17. 默认 UI 语言

## Knowledge
- 一阶订正
- 二阶巩固
- 三阶验证
- 继续跟进
- 稳定观察
- 已清零

## Habit
- 当前行为
- 目标行为
- 调整策略
- 本次观察
- 继续观察
- 稳定观察

## Exam Strategy
- 当前策略问题
- 方法训练
- 引导应用
- 限时/模拟迁移
- 独立验证
- 稳定观察

状态仍统一显示 Foundation lifecycle 的教师友好文案。

---

# 18. Acceptance scenarios

### A. Knowledge 三阶一次走通

合法，但第三阶 passed 后仍由教师判断 stable/后续 review，不能自动 closed。

### B. Knowledge 二阶做了三次

合法。UI 显示多次巩固历史，不报“流程错误”。

### C. Habit 连续四次自然场景改善

系统整理观察证据；教师确认 stable；不靠固定次数自动判定。

### D. Habit 一次专门小测成功

不能自动 clear，因为尚不能证明自然行为稳定。

### E. Exam Strategy 无提示练习成功但正式考试失败

Case 可继续/重新干预；历史不覆盖。

### F. Case 多次 failed

进入长期重点提醒，优先重新分析原因；不自动创建第二个“顽固问题”。

---

# 19. 决策结论

Phase 0A.6 当前冻结：

1. 三类问题使用不同默认教学 workflow；
2. 底层领域对象保持统一；
3. 三阶订正是 Knowledge 默认 workflow，不是生命周期/三列 schema；
4. Habit 以可观察行为和多情境持续观察为核心；
5. Exam Strategy 必须验证接近真实考试条件下的迁移；
6. 不设置统一自动 stable/clear 阈值；
7. Assessment passed 永远不自动 closed；
8. workflow 阶段优先从事实派生，不新建第二套权威状态；
9. V1 暂不要求 workflow template entity/version；
10. Quick Capture 不被完整 workflow 阻塞。
