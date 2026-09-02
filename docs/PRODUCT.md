# 产品蓝图

## 1. 定位

**学情闭环（Xueqing）｜机构教学协作与学生成长闭环系统**

不是 Excel 网页化，也不是收费排课/招生 ERP。核心是让真实教学事实形成连续、多人协作、可验证、能指导下一次教学的学生成长记录。

### 北极星

> **老师打开软件后，能否快速知道这个学生下一步做什么，并能用证据判断前一次教学是否有效？**

不能改善这个闭环、只增加填写负担的功能，默认后置、自动化或删除。

---

## 2. 主要用户

### 任课教师
今天做什么、学生上次遗留什么、课中怎么快速记、课后怎么在 60 秒左右留下可靠记录。

### 学生负责人 / 学管 / 班主任
跨学科整体状态、需要协调的事项、家校沟通。

### 学科负责人
本科长期问题、高频共性问题、可沉淀教研方案。

### 教学/机构管理员
成员权限、学生主档案、交接、异常、数据完整性。

管理端不把“老师填多少条”做核心 KPI，避免系统退化为应付式填表。

---

## 3. 核心领域对象

### Student
同一机构一个真实学生一份主档案。姓名不是唯一标识；重复通过提示 + 受控合并治理。

### Student Subject Profile
学生某学科的连续学情主线。换老师不新建。

### Learning Case
可独立跟进的学习问题，是闭环最小业务单元。

正式 case 至少能回答：
- 问题是什么；
- 证据来自哪里；
- 当前原因判断；
- 做过什么干预；
- 如何验证、结果如何；
- 下一步是什么；
- 是否复发。

### Evidence
试卷、作文、课堂练习、小测、作业、可观察事实。证据不是“附件越多越好”。

### Intervention
真正实施过的教学处理。

### Assessment
后续验证结果；必须和 case status 分开。

### Case Action
下一步行动，是 Today 的核心事实源。

### Lesson
真实教学会话，用来关联本节课发生的事实，不是完整排课系统。

---

## 4. Case 生命周期

```text
new → confirmed → intervening → pending_verification → stable → closed
```

- `new`：课堂 10–20 秒快速捕捉，可缺完整分类/owner/action；
- `confirmed`：确认值得正式跟进，结构完整；
- `intervening`：正在干预；
- `pending_verification`：等待后续验证；
- `stable`：已有改善证据，仍观察；
- `closed`：退出主动跟进。

`reopen` 是受控命令/事件，不是第七状态。

一次 assessment passed 不自动 stable/closed。

---

## 5. 正式 Case 永远有下一步

最终规则：
- new 可以没有 action；
- confirmed / intervening / pending_verification / stable 必须始终有一个 pending primary action；
- 暂时不处理不是“没有下一步”，而是建立 `review` primary action；
- 暂缓 `review` 必须有 `due_at`；
- `pause_reason` 只解释为什么暂缓，不替代 action；
- closed 不存在 pending primary action。

这样避免“暂停后没人再看”，也让 Today 只需要一个行动事实源。

### 无日期主行动
部分下一步可能还不知道具体日期，可暂时无 due_at，但必须在 Today 的“待安排”区域出现。暂停/稳定观察的 review action 不允许无日期。

---

## 6. 分类：结构化但不困住老师

V1：
- 受控 taxonomy：学科 → 模块/能力，用于统计；
- 自由 title/description：表达真实问题。

new 可暂不选完整 taxonomy；confirmed 前补齐。只做少量默认分类 + “其他/暂未分类”，不建庞大知识图谱。

---

## 7. Excel 原型怎么转成软件

Excel 的工作表不是软件页面：
- 学生档案 → Student / Enrollment / Assignment；
- 初诊问题 → Learning Case；
- 知识闭环 → Evidence + Intervention + Assessment + Event；
- 周度跟进 → 自动派生；
- 顽固问题 → 同一 case 的持续/失败/复发提示；
- 家校沟通 → V1.1 Parent Communication；
- 阶段复盘 → V1.1 Report Snapshot。

事实只保存一次，展示/报告尽量派生。

---

## 8. 导航

### V1
1. 今日
2. 学生
3. 课程
4. 学情

### V1.1
增加：家校、报告。

“今日”不要求完整课表，主要来自：
- 今日/逾期 case actions；
- 无日期待安排 actions；
- 待验证；
- 高优先级 case；
- 最近负责学生。

教师能从 Today/学生直接开始 lesson。

---

## 9. 核心教师流程

### 课前：约 30 秒
看到：上次遗留、到期行动、待验证、高优先级 case、最近关键事实。

### 课中
只记录新事实：
- 完成/调整 action；
- evidence；
- intervention；
- assessment；
- new 快速草稿。

### 课后：目标 30–60 秒
系统整理本课事实，教师确认：
- 处理了哪些 case；
- 必要的 new → confirmed；
- 旧 action 完成/取消；
- 新 primary action；
- 必要状态变化；
- lesson complete。

不要求再抄一份周总结。

---

## 10. 网络失败与本地草稿

V1 online-first，云数据库是唯一正式事实源。

必须：
- 未保存/保存中/已保存/失败清晰；
- 网络失败不清空输入；
- 可恢复草稿加密保存；
- 草稿按 user/org 隔离，有 TTL，同步成功清理；
- 重试不重复事实；
- 云端未确认前不显示正式“已保存”。

这不是 offline-first，而是“不让老师白填，也不让本地明文变第二数据库”。

---

## 11. 跨学科协作

**默认隔离、必要互通**：
- 本科教师：本科详细数据；
- 其他任课教师：必要摘要；
- advisor：更广综合视角，但不能随意改写专业学科结论；
- subject lead：本科范围；
- admin：机构治理视角。

“能看”与“能改”分开。

---

## 12. V1 必须有

- 安全登录/机构 membership/首位管理员；
- 学生统一主档案与查重；
- enrollment / teacher/staff assignment 历史；
- learning case + taxonomy；
- evidence/intervention/assessment；
- case action；
- lesson；
- Today；
- RLS/审计/并发；
- network recovery；
- secure Session / encrypted draft；
- DB + Storage recovery。

### 可以简单
- 附件只支持少量私有文件；
- 管理端只做必要治理；
- 搜索只覆盖高频字段；
- Windows Pilot 内部分发。

### 明确不做
- 收费/课消/招生 CRM；
- 完整排课；
- 大型题库；
- 学情健康分/成绩预测；
- 家长/学生独立 App（V1）；
- AI 自动正式诊断；
- CRDT/offline-first；
- 多套登录方式；
- 大量第三方 SaaS。

---

## 13. V1 成功指标

1. **低负担**：new 10–20 秒，常规课后中位 ≤60 秒；
2. **连续性**：换老师后仍能快速看懂重点/下一步；
3. **闭环率**：正式未关闭 case 都有主行动；
4. **证据性**：关键结论可追溯到 evidence/assessment；
5. **协作**：两位教师看到同一 student 的权限化数据；
6. **安全**：revoked/onboarding/disabled 无法访问业务；
7. **可靠**：网络失败不丢，重试不重复；
8. **恢复**：DB/Storage 能从备份实际恢复；
9. **可运营**：教师连续一周愿意真实使用，而不是为了验收点几次。

---

## 14. 产品铁律

1. 一个学生一份机构主档案。
2. 事实只记录一次。
3. 重要结论尽量有证据。
4. 正式未关闭 case 永远有下一步。
5. 学生历史不因换老师/升年级断裂。
6. 数据共享与编辑权限分开。
7. 老师少填一次，系统多自动一次。
8. 网络失败不能让高频记录消失。
9. 本地恢复不能以明文长期留存敏感数据为代价。
10. Today 不偷偷变排课 CRM。
11. AI 只做副驾驶。
12. 功能数量永远排在数据正确、权限安全、教师可用之后。
