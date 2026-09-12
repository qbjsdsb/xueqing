# Xueqing 双视角工作区 UX 合同

状态：v0.3.x product / UX contract  
适用范围：Personal Projection 与 Organization Projection 的导航、信息层级和责任表达。  
实施策略：先收口 Organization 监督信息层级，再独立调整 Workspace Shell，避免把导航、业务写入和责任模型混入同一高风险改动。  

## 1. 为什么需要双视角

Xueqing 面向中小型教育机构。负责人、管理员与一线老师不是互斥身份：同一个成员可以拥有机构监督能力，也可以真实承担某些学生、某些学科的教学责任。

因此产品不能把用户简单分成“教师端”和“管理员端”，也不能把机构可见数据混入个人教学工作台。

Xueqing 只保留一套业务事实，但提供两个正式 Projection：

```text
Personal Projection（我的教学）
  回答：我今天要帮助谁？我真实负责哪些学生、问题和下一步？

Organization Projection（机构）
  回答：全机构哪里需要关注？哪个学生、哪个学科、谁负责、下一步是什么？
```

二者共享 Student / Subject Profile / Learning Case / Evidence / Intervention / Assessment / Action 等事实，不建立第二套 Case 系统。

## 2. 三个维度不得混用

界面和命令必须持续区分：

- **机构权限**：成员是否可以查看、监督或治理机构范围的数据；
- **教学责任**：成员是否真实负责某个 Student Subject Profile / Case / Action；
- **当前视角**：用户此刻正在“我的教学”还是“机构”中工作。

机构权限永远不是教学责任的充分条件。

负责人/管理员在 Organization Projection 中补充记录时，实际 Actor 是本人；原 Case owner / primary Action assignee 不得因此被静默改写。

## 3. 默认进入规则

- 有当前 Personal Assignment 的普通老师：进入 Personal Projection。
- 同时任课的负责人/管理员：仍优先进入 Personal Projection，机构能力作为独立入口存在。
- 没有任何当前 Personal Assignment、但有机构监督能力的负责人/管理员：直接进入 Organization Projection，不展示一组无意义的空 Personal 页面。
- 没有当前任课、也没有机构监督能力的普通老师：显示清晰的“暂无当前任课学生”状态。

## 4. 一级导航语义

v0.3.x 当前生产 V2 的个人主线保持：

```text
今日 / 学生 / 学情
```

Organization capability 存在时增加“机构”入口，但“机构”是 scope 入口，不代表把全机构数据重新标记成“我的”。

`Lesson / 课程` 的领域事实继续保留。早期 IA 文档仍把“课程”列为一级入口，而当前 V2 shell 没有该 destination；这是一个明确的 IA 一致性审计项。本合同不在机构 UX 改造中贸然恢复或删除 Lesson 领域能力，后续应根据真实教师使用路径单独决定它是否需要重新成为一级入口。

## 5. Organization Projection 不是 KPI Dashboard

机构学情是“监督工作台”，不是经营驾驶舱。

首屏优先回答：

```text
哪个学生需要关注？
哪个学科？
当前是什么问题？
谁负责？
下一步是什么？
是否待复检、逾期或没有明确主责？
```

允许展示的顶部事实必须是可行动、可解释、直接来自真实业务状态的，例如：

- 正在跟进的问题数量；
- 待复检；
- 已逾期；
- 未明确主责。

不得为了“管理感”引入教师排行榜、闭环率 KPI、AI 风险分、红黄绿绩效评价或第二套统计台账。

## 6. Organization 学生列表的信息顺序

学生仍然是机构学情的主组织对象，而不是老师。

推荐层级：

```text
Student
  → Subject
    → active Learning Case
      → Responsible Teacher
      → Next Action
```

收起状态只提供扫描所需的信息：姓名、年级、当前跟进数量/注意状态、简洁的学科—主责摘要。

展开后再展示进行中的 Case、状态、责任老师和下一步。已结束 Case 属于历史，不与当前需要处理的问题混成同一层级。

宽屏中“记录问题”使用明确文本动作，避免只靠不透明图标；窄屏可在空间不足时退化为带 tooltip/semantic label 的图标动作。

## 7. 机构注意力筛选

机构页可以提供事实型筛选：

```text
全部 / 需关注 / 待复检 / 已逾期 / 未明确主责
```

“需关注”只能由明确事实派生，例如 pending verification、overdue、undated next action、missing Lead。不得建立不可解释的综合风险评分。

筛选只改变 Organization Projection 的当前呈现，不改变 Case status、责任或任何历史事实。

## 8. Organization Quick Capture 责任表达

Organization Quick Capture 必须保持现有 fail-closed 责任合同：

- 新 Case 的 Responsible Teacher 默认解析为目标 Profile 的当前 active Lead；
- 当前管理者只有在自己确实是合法 Lead / Assignment 老师时，才可能成为教学责任人；
- Profile 没有 active Lead 时，不建立正式 Case；
- stale Lead / responsibility conflict 必须拒绝保存并要求刷新，不得猜测新责任人；
- Organization draft 与 Personal draft 使用不同 scope，不能串台。

UI 应逐步把“本次记录不会改变主责”以及最终 Responsible Teacher 提前表达给用户，而不是只在保存失败后解释。

## 9. Windows 与 Android 的适配目标

业务 scope 一致，导航形态可以不同。

### Windows / expanded

Personal 与 Organization 应在左侧导航中形成清晰的视觉分组，使兼任老师的负责人能一次点击进入机构监督，同时始终知道自己当前所处 scope。

宽屏内容保持合理阅读宽度，不把学生、学科、主责和 Case 信息拼成横跨整个窗口的一条长句。

### Android / compact

个人教学的高频底部导航保持克制。Organization 应作为清晰的 scope 入口进入，再在机构内部使用“学情 / 管理”，而不是把所有个人入口与机构管理入口一起塞进底部导航。

返回顺序必须优先退出 Case / Student 子层，再退出当前 Organization scope，最后才允许离开应用。

上述 shell 调整属于后续独立实现 PR；不得为追求一次性视觉重构而破坏当前已验证的返回、草稿和刷新语义。

## 10. 本轮实现边界

机构监督工作台的 UI 重构优先复用现有 Read Model / Responsibility Context，在当前目标规模下不新增统计表、缓存表或 materialized view。

本轮不得改变：

- RLS 与跨机构隔离；
- Actor / Supervisor / Responsible Teacher 语义；
- Case owner / Action assignee 的安全边界；
- Lead-based Organization Quick Capture；
- 历史 Evidence / Intervention / Assessment / Event actor；
- Personal Projection 的 Assignment 隔离。

如果未来性能数据证明 Organization Projection 需要专门只读 RPC，可在保持同一产品语义的前提下增加 read projection，但不能因此引入第二套业务事实。

## 11. UX 验收问题

每次改动至少要能回答：

1. 兼任老师的负责人进入 Personal 后，是否只看到自己真实负责的学生与任务？
2. 进入 Organization 后，是否能快速判断“哪个学生、哪个学科、什么问题、谁负责、下一步是什么”？
3. 管理者补充记录后，是否仍能分清“谁操作”和“谁负责”？
4. 没有主责时，系统是否 fail closed 并给出清楚原因？
5. 普通老师是否完全不需要理解机构管理复杂度？
6. Android / Windows 是否都能明确感知当前 scope，并保持返回、刷新和草稿上下文？

一句话原则：

> **我的教学让老师专注自己今天该帮助谁；机构让负责人知道哪里需要关注、谁正在负责。两者共享同一份学生成长事实，但绝不混淆权限、责任和操作者。**
