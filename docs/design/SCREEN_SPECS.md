# Xueqing Core Screen Specifications

状态：Phase 0A.5 implementation-ready screen baseline

最后更新：2026-09-02

本文件是四个核心 screen 的可实现规格。它描述用户任务、信息优先级、状态、Windows/Android 行为和验收场景；不要求第一版生产实现全部字段齐全。字段语义以 `PRODUCT.md`、`DATA_MODEL.md` 和 `COMMANDS_AND_INVARIANTS.md` 为准。

## 0. 共用约束

- 所有 screen 都使用共享 token、状态文字、权限模型和返回来源。
- screen 不直接访问 repository、Supabase、Auth 或生产 API。
- loading 不等于 empty；no permission 不等于“没有数据”。
- action status 和 Case status 分开显示。
- 关键操作在 Windows 可用 mouse/keyboard，在 Android 可用 touch/back/IME。
- 长中文自然换行；不固定高度裁剪 title、状态、错误或主操作。
- prototype fixture 明显标为虚构，数据最小且集中管理。

## 1. Today 今日

### 1.1 User goal

教师打开软件后，在约 30 秒内知道今天先处理什么、哪些已逾期、哪些在等待验证、哪些没有安排日期，以及可以直接完成什么。

### 1.2 Entry points

- 默认一级导航入口。
- 课程结束返回。
- 保存 Quick Capture 后返回来源上下文。
- 完成 Student/Case action 后返回并保留原列表位置。

### 1.3 Information priority

1. 页面标题 `今日` + 一句工作说明。
2. 已逾期和今天到期的 pending primary actions。
3. 待验证的 Case actions/确认入口。
4. 待安排的无日期 primary actions。
5. 重点 Case（只有在它尚未被 action queue 覆盖时出现）。
6. 最近学生和进入课程入口。

同一学生多个事项合并成一个学生簇：姓名只出现一次，最多直出三项，其余用“还有 N 项”。同一待验证事件不在两个 section 复制；如果切换分组视图，改变的是组织方式，不是产生新对象。

### 1.4 Primary action

页面 primary action 是当前第一条最需要处理的 action 的具体动词，例如 `完成`、`确认稳定` 或 `补充证据`。页面右上可有一个上下文动作 `记录问题`，但不能用“查看 Dashboard”替代工作动作。

### 1.5 Secondary actions

- `查看学生`
- `查看 Case`
- `开始记录课程`
- `安排日期` / `改期`
- `记录问题`
- 搜索和轻量筛选

### 1.6 推荐结构

```text
今日                         [记录问题] [搜索]
先处理今天要做的事，再回看需要判断的学生。

今天的工作
  已逾期
    示例学生甲 · 数学        已逾期 8 月 31 日  [查看 Case] [完成]
  今天到期
    示例学生乙 · 英语        今天到期          [查看 Case] [完成]

待验证
  示例学生甲 · 分数概念      本次验证通过，待确认是否稳定 [查看 Case]

待安排
  示例学生乙 · 词义辨析      尚未安排日期        [安排日期]

最近学生                    [查看全部]
```

wireframe 只用于推理；最终实现使用真实 Flutter rows/sections，不把它当视觉稿。

### 1.7 States

| 状态 | 规格 |
| --- | --- |
| Empty | 无 action 时显示“目前没有已安排的行动。发现问题时，可以先记录一句。”；仍保留学生搜索和记录问题入口 |
| Loading | 显示页面骨架/局部 progress 和 `正在加载今日事项…`；不显示“没有数据” |
| Error | 显示 `今日事项暂时加载失败。可以重试，已有本地内容不会被删除。` + `重试`；不清空已存在内容 |
| No permission | 只显示有权查看的队列；受限区显示“当前账号无权查看此内容”，不泄露隐藏学生/Case |
| Saving | 完成 action 后行内显示 `保存中…`，防重复提交，保持学生簇位置 |
| Save failed | 行内显示 `保存失败` + `重试`；原 action 仍存在，不假装完成 |
| Offline | 显示连接状态；若是 Quick Capture 草稿，明确“本机草稿，未计入正式学情”；Today 不把未同步内容显示为正式完成 |
| Draft | 可恢复的本机草稿显示来源和恢复入口，不与正式 Case/action 混排为已保存 |
| Long content | 长 title 最多自然三行后继续可见/进入详情；操作区随内容下移，不覆盖文字 |
| Many actions | 先按逾期/今天/待验证/待安排分组，学生簇减少重复；提供“还有 N 项”，不横向塞满 |
| No due date | `待安排` 独立 section；默认可见，不因日期筛选消失 |
| Closed Case | 不出现在 pending action 队列；若在最近学生中出现，明确 `已关闭`，提供查看历史/重新打开 |
| Reopened Case | 显示 `重新打开` 的 timeline 事实和当前新的 Next Action；不覆盖旧 closed 历史 |

### 1.8 Windows layout

- Expanded：232px expanded rail + max-width 工作区；主列工作队列，右侧可放最近学生/轻量上下文，不无限拉宽。
- Medium：72px compact rail；工作队列单列，行尾可放日期/操作。
- hover 显示行可操作区域；focus ring 明显；Tab 按 header action → section → row → row action 顺序。
- mouse wheel 滚动列表；点击学生名/标题进入详情，完成 action 不离开当前队列。
- 窄窗口从双列退回单列，不能把字体缩小到不可读。

### 1.9 Android layout

- AppBar + bottom navigation；内容水平 padding 16px。
- 学生簇单列；主完成操作至少 48dp；筛选使用 sheet。
- 适合单手搜索、快速记录和完成 action；不要为展示全量历史牺牲 action 可见性。
- SafeArea 保护系统栏；软键盘打开时搜索和 Quick Capture 保持可视。
- 返回进入详情后回到 Today 原滚动位置；不会因为完成 action 重置到顶部。

### 1.10 Responsive transition

`<600` 为 AppBar/bottom nav + 单列；`600–1023` 为 compact rail + 单列优先；`≥1024` 才允许主列/辅助列并列。数据分组、状态文案和主要 action 不随断点改变。

### 1.11 Keyboard behavior

Tab/Shift+Tab 依次访问可操作元素；Enter/Space 激活当前 button/row；Esc 关闭无改动的轻层；列表支持滚轮。页面级快捷键不得在搜索/文本输入时抢占字符或组合键。

### 1.12 Touch behavior

关键行/按钮至少 48dp；整行点击区域与行尾 action 分离，避免误触。完成 action 后给出短反馈，不把 Case 自动变成 closed。

### 1.13 Privacy / permission visibility

列表中只显示当前权限范围内的学生和 Case；无权内容不通过“空”伪装。可查看不可编辑时保留摘要但将修改 action 置为 disabled 并解释原因。

### 1.14 Anti-patterns

不做统计图/大数字 KPI、彩色状态胶囊墙、重复学生卡、按日期筛选后隐藏无日期 action、把 pending verification 画成逾期、把 Today 变成普通 Todo App。

### 1.15 Acceptance scenarios

1. 有一个逾期 action、一个待验证、一个待安排 action：教师能在首屏分别说出三者含义和下一步。
2. 同一学生有三条 action：学生姓名只出现一次，三条仍可单独操作。
3. 375px 宽和 1280px 宽：内容关系一致，宽屏没有无限拉宽，窄屏 action 没被截断。
4. 点击完成失败：action 仍可见，输入/上下文没有丢，出现重试。
5. 进入 Student/Case 再返回：回到原来源和滚动位置。

## 2. Student Detail 学生详情

### 2.1 User goal

第一次接手学生的教师无需翻完整历史，就能回答“现在最重要的三件事是什么、有哪些 Case 在推进、最近发生了什么”。

### 2.2 Entry points

- Today 学生簇/学生行。
- 学生搜索结果。
- 课程入口中的学生。
- Case detail 的学生上下文。

### 2.3 Information priority

1. 姓名 + 学科/年级最小上下文 + 权限提示。
2. `现在最重要的事`，最多三项，每项指向 Case 或 action。
3. `当前 Learning Cases`：status、最近事实、Next Action。
4. `待验证`：检查结果与确认动作。
5. `最近关键事实`：少量 Evidence/Lesson/Intervention。
6. 必要学科上下文。
7. 折叠的更早 timeline。

### 2.4 Primary action

根据当前上下文选择一项具体主操作：优先是第一条 Next Action；若无 Case，则为 `记录问题`。不显示新的学生总分或“综合健康分”。

### 2.5 Secondary actions

`查看 Case`、`完成行动`、`记录问题`、`展开最近记录`、`查看更早历史`、在有权限时 `补充学生上下文`。

### 2.6 推荐结构

```text
[返回] 示例学生甲                         [记录问题]
数学 · 八年级                  仅用于设计预览的虚构资料

现在最重要的事
  1. 分数概念 · 补充一次具体题目证据       [查看 Case]
  2. 应用题审题 · 今天到期                 [完成]

当前 Learning Cases
  分数概念混淆                  待验证     [查看 Case]
  应用题审题跳步                intervening [查看 Case]

最近关键事实
  9 月 2 日 课堂观察……
  8 月 30 日 教学动作……

更早历史（按需展开）
```

### 2.7 States

| 状态 | 规格 |
| --- | --- |
| Empty | 学生存在但没有 Case：显示“还没有 Learning Case……” + `记录问题` |
| Loading | `正在打开学生详情…`，摘要结构先占位，不展示错误空状态 |
| Error | `学生详情暂时打不开。请重试；如果仍失败，稍后再打开。` + 重试/返回 |
| No permission | `当前账号无权查看这名学生的学情内容。`；不展示姓名以外超出权限的细节 |
| Saving | 完成/补充 action 后局部显示 `保存中…`，保留当前 section |
| Save failed | 原值保留，显示失败和重试，不用乐观成功覆盖事实 |
| Offline | 读取到的内容标识当前同步状态；Quick Capture 草稿与正式 Case 分开 |
| Draft | “待整理问题”可显示在 draft 区，明确尚未进入正式闭环 |
| Long content | 学科上下文、Case title、最近事实可换行；三件事用自然增高行，不固定一行 |
| Many cases | 当前/待验证优先；其余折叠或按需展开，不能让首屏淹没在历史中 |
| No due date | action 仍显示为 `待安排` |
| Closed Case | current list 可折叠；显示已关闭和重新打开历史，不当作 active action |
| Reopened Case | 置于当前 Cases，显示新的 Next Action 和 reopen 事件 |

### 2.8 Windows layout

Expanded 使用主工作列 + 辅助事实列；主列先放三件事和当前 Cases，辅助列放最近关键事实/学科上下文。Medium 以单列为主；side panel 只有在最小列宽满足时出现。Tab 顺序按 header → 三件事 → Cases → 待验证 → 最近事实 → 历史。

### 2.9 Android layout

单列滚动；返回回到来源；标题和 `记录问题` 之间不塞多余字段。当前三件事和 Next Action 优先出现在屏幕上方，历史通过可展开 section。长中文不被头像或标签挤压。

### 2.10 Responsive transition

Expanded 的辅助事实列在 Medium/Compact 移到当前 Cases 之后；不删除最近关键事实。Compact 的主 action 可以成为全宽按钮，Expanded 可位于 header/侧栏。

### 2.11 Keyboard behavior

`Alt/Command+Left` 仅在无文本编辑冲突时返回；Tab 能访问每个可操作 row。打开 Case 后 focus 进入 Case title 或 primary action，而不是静态装饰。

### 2.12 Touch behavior

学生行、Case 行、主要 action 分开触控区域；长按不触发隐藏菜单。滚动时不误触 action，浮动/固定操作不遮住最近事实。

### 2.13 Privacy / permission visibility

身份信息最小化；联系方式、非当前学科信息不主动展开。可查看不可编辑时显示 `你可以查看，但不能修改此学科内容。`；无权限不泄露 Case title、状态数量或 Evidence。

### 2.14 Anti-patterns

不做几十字段档案表、成绩趋势图、成长指数、风险概率、标签云、四个统计 Card 的首屏；不把最近事实写成无来源的“智能洞察”。

### 2.15 Acceptance scenarios

1. 新教师打开已有多个 Case 的学生详情，能在 30 秒内找到最多三项重点和一条最近 Evidence。
2. 学生无 Case 时，能直接进入 Quick Capture，且空状态不把“没有 Case”写成错误。
3. Case title 很长、text scale 1.5：主操作仍可见，内容自然增高。
4. 无编辑权限：能看到权限原因，不把页面伪装成空列表。
5. 从 Today 进入后返回：Today 的学生簇和滚动位置保持。

## 3. Learning Case 学情问题

### 3.1 User goal

教师能理解这条问题从哪里来、目前有什么证据、做过什么教学动作、一次检查结果是什么，以及现在该做哪一个 Next Action。

### 3.2 Entry points

- Today action/Case row。
- Student Detail 当前 Case。
- 学情列表。
- 课程记录中的关联 Case。
- Quick Capture 保存后选择“查看 Case”。

### 3.3 Information priority

1. Student + subject + Case title + Case status + priority。
2. 当前 primary Next Action（owner、due/待安排、直接操作）。
3. 问题。
4. Evidence。
5. 教师判断。
6. Intervention。
7. Assessment / Verification。
8. timeline。

### 3.4 Primary action

只显示当前状态允许的下一步：例如 `补充证据`、`记录教学动作`、`记录一次检查`、`确认稳定`、`安排下一次检查`、`重新打开`。主操作不根据颜色猜测，且不把 Assessment passed 自动转为 stable/closed。

### 3.5 Secondary actions

`补充证据`、`记录教师判断`、`记录教学动作`、`记录一次检查`、`安排/改期`、`查看学生`、`展开历史`。破坏性/丢弃动作必须明确对象和确认。

### 3.6 推荐结构

```text
[返回] 示例学生甲 · 数学
分数概念混淆                         待验证 · 高优先级
本次验证通过，仍待确认是否稳定。       [确认稳定]

Next Action / 下一行动
  9 月 4 日再做两道迁移题并核对过程       [完成]

问题
  在异分母比较时容易直接相加分子分母。

Evidence / 证据
  9 月 2 日课堂题目：……                  [补充证据]

教师判断
  ……                                      [记录教师判断]

Intervention / 教学动作
  ……                                      [记录教学动作]

Assessment / Verification
  9 月 2 日：本次验证通过；待确认稳定。    [记录一次检查]

历史 timeline
```

### 3.7 States

| 状态 | 规格 |
| --- | --- |
| Empty | 不存在的 Case：显示安全 not-found/返回；已有 Case 的空段显示“尚未记录” + 合适补充动作 |
| Loading | `正在读取这条 Case…`；status/action 区保留结构 |
| Error | 说明读取失败，提供重试和返回；已加载的内容不被清空 |
| No permission | 不展示问题标题/Evidence 等受限内容；显示无权查看此 Case |
| Saving | 当前编辑段保留文字，按钮变 `保存中…`，禁止重复提交 |
| Save failed | 保留草稿文本，显示 `保存失败` + `重试`；不产生假 timeline |
| Offline | 明确正式保存与本机 draft 的差异；不能把本机草稿当作新 Evidence 或 action 完成 |
| Draft | new/待整理 Case 显示草稿/待整理标记，允许稍后 formalize |
| Long content | Evidence、判断、干预和 timeline 支持多行滚动；固定操作区不盖正文 |
| Many events | 当前工作段优先；timeline 按时间分页/折叠，默认显示最近关键事件 |
| No due date | Next Action 明确 `待安排`，并提供安排日期动作 |
| Closed Case | status 文案 `已关闭；当前没有待完成的主要行动。`；primary action 为 `重新打开`，无 pending action |
| Reopened Case | 保留 closed 和 reopen 事件；当前 status/Next Action 按新流程显示 |
| Assessment passed | 文字为 `本次验证通过，仍待确认是否稳定。`，提供确认稳定/继续跟进，不自动切换 |
| Stable | 文案 `稳定；仍需安排下一次检查。`；仍有 review/verify action |

### 3.8 Windows layout

Expanded：主列显示语义叙事，侧栏显示 status、priority、owner、due 和 primary action；侧栏随滚动保持可见但不遮盖内容。Medium：单列叙事，metadata 横向不足时换行。支持 hover 显示编辑 affordance，focus/Tab 可进入每个段落的真实操作。

### 3.9 Android layout

纵向顺序固定，status 和 Next Action 靠近顶部。补充 Evidence/判断/干预/检查用 sheet 或分段编辑；保存按钮随 IME 上移。返回先收键盘；脏内容确认保留/放弃。

### 3.10 Responsive transition

侧栏 metadata 在窄屏移到 title 下方；主 action 从侧栏移到全宽顶部。语义顺序和状态不变；timeline 不在 compact 默认抢占当前工作段。

### 3.11 Keyboard behavior

Tab 按 status/Next Action → 当前段 action → 后续段 action → timeline 展开顺序。多行输入用 Ctrl+Enter 保存（若上下文支持）；Esc 关闭轻层并保护未保存内容；全局快捷键不能抢输入。

### 3.12 Touch behavior

每个段落主 action ≥48dp；Evidence 文本区域可滚动；状态/历史不可点击时不做成大面积伪按钮。确认 stable、重新打开等状态变化需要明确按钮和必要确认。

### 3.13 Privacy / permission visibility

Case detail 遵循 subject assignment/role 可见范围。可查看不可编辑时保留文本但锁定编辑；无权时不通过 title、数量或 timeline 时间泄露信息。审查内容不在日志或 fixture 中放真实敏感资料。

### 3.14 Anti-patterns

不做巨大表单、四块统计卡、雷达图、自动风险分、不把所有 timeline 平铺到首屏、不把 Evidence 与教师判断合成一个“备注”、不把 passed 变 stable、不把 stable 变 closed。

### 3.15 Acceptance scenarios

1. Case 从 new 到 confirmed：标题可先存在，补充字段后才确认；Next Action 规则不被 UI 绕过。
2. 一次 Assessment passed：页面仍显示待验证/确认稳定动作。
3. Case stable：仍显示 review/verify action；没有被误认为 closed。
4. Case closed 后 reopen：旧历史仍在，新 action 清楚显示。
5. Evidence、教师判断、Intervention 各自可定位且不混文案。
6. 保存失败/离线：当前文本保留，失败原因和恢复动作清楚。

## 4. Android Quick Capture 快速记录

### 4.1 User goal

课堂中用一只手在 10–20 秒内抓住一个新问题，不因为完整 taxonomy 或长表单错过事实；课后再 formalize。

### 4.2 Entry points

- Today 的 `记录问题`。
- Student Detail 的 `记录问题`。
- Case Detail 发现新问题的上下文入口。
- 课程记录中的 `记录问题`。

已知 Student/Subject 时直接带入上下文；未知时先搜索/选择学生和学科，但不在课堂路径追加完整档案字段。

### 4.3 Information priority

1. 学生 + 学科上下文（可确认、可更改）。
2. 必填单行 `问题标题`。
3. 可选 `补充说明`。
4. 非阻塞相近 Case 提示。
5. `记录问题` 保存；取消/稍后整理为次要动作。

不在最短路径强制要求 taxonomy、根因、正式 owner、完整 Evidence、Next Action、due date、附件。

### 4.4 Primary action

`记录问题`。标题为空时不提交，说明“请先写下问题标题”；标题有内容时保存进入 new/待整理语义。

### 4.5 Secondary actions

`取消`、`稍后整理`、更改学生/学科、保存失败后的 `重试`、成功后的 `查看学生`。相近 Case 提示中的“仍然记录”是非阻塞选择，不是强制合并。

### 4.6 推荐结构

```text
记录问题                         [关闭]
学生  示例学生甲 · 数学           [更改]

问题标题 *
[用一句话记下刚发现的问题       ]
看起来已有相近的 Case……（可忽略）

补充说明（可选）
[关键表现、题目或课堂语境       ]

[取消]                         [记录问题]
```

### 4.7 States

| 状态 | 规格 |
| --- | --- |
| Empty | 不存在有效学生/学科上下文时，先显示搜索/选择；不能保存到未知对象 |
| Loading | 学生/学科上下文加载时显示局部 loading；已经输入的 title 不清空 |
| Error | 上下文读取失败时给出重试；输入区若可用仍保留 |
| No permission | 不能为无权学生/学科创建 Case；显示权限原因，不显示受限资料 |
| Saving | button 文案 `保存中…`，防重复点击；title/note 保留可见 |
| Save failed | `保存失败，刚才的内容还在。` + `重试`；关闭后仍可选择保留草稿 |
| Offline | `当前离线，已保留为本机草稿（未计入正式学情）`；不显示已正式保存 |
| Draft | 打开已有草稿时显示来源、时间和继续编辑；保存成功后才从 draft 语义移出 |
| Long content | title/note 自然换行并可滚动；键盘打开时保存按钮仍可到达 |
| Duplicate hint | 相近 Case 提示非阻塞，不自动改标题、不阻止保存；提供“仍然记录”或稍后处理 |
| Many cases | 提示只显示少量相近结果和 `查看全部`，不在课堂 sheet 展开完整历史 |
| No due date | 快速记录不要求 due date；保存后由课后 formalize 安排 |
| Closed Case | 相近提示可说明已有已关闭 Case，但新问题仍可记录为新 Case/稍后处理，不静默写入旧 Case |
| Reopened Case | 如果上下文是 reopened Case，明确显示当前 Case status，不把 Quick Capture 当作重新打开操作 |

### 4.8 Windows layout

在 expanded 窗口使用 centered dialog 或右侧 panel，宽度约 420–520px，保留底层 Student/Case 上下文；medium 可使用 dialog。支持 mouse、Tab、Enter/Space、Ctrl+Enter（多行 note 提交）、Esc（无改动直接关闭；有改动先确认）。

### 4.9 Android layout

使用 `showModalBottomSheet` 或全屏 sheet，SafeArea + `MediaQuery.viewInsetsOf` 处理系统栏和 IME。已知上下文时打开后 focus 到 title；保存操作至少 48dp，单手可触达。内容区可滚动，键盘打开不遮住保存。

### 4.10 Responsive transition

compact 是 bottom sheet/全屏短任务；medium 是可滚动 dialog；expanded 是右侧 panel/centered dialog。字段和顺序不变，只有 surface 形态、宽度和操作区位置变化。

### 4.11 Keyboard behavior

title 输入时允许 Enter 完成（note 未展开/单行语境）；note 多行时使用 Ctrl+Enter 保存。Tab 顺序为 Student/Subject → title → note → 保存 → 取消。Esc/back：先收键盘，再按脏状态确认。全局快捷键不抢文本输入。

### 4.12 Touch behavior

学生/学科选择、标题、note、保存、取消均有至少 48dp 的可操作面积；相近 Case 提示不采用容易误触的全屏点击。保存防双击，失败时重试仍使用原内容。

### 4.13 Privacy / permission visibility

只显示当前已选且有权限的学生/学科上下文；切换选择前不展示相近 Case 的受限 title。设计预览使用虚构数据；正式版本需要遵循会话、assignment、RLS 和 draft 隐私规则。

### 4.14 Anti-patterns

不做完整 Case 表单、强制 taxonomy/根因/owner/action/date/附件、不强行合并重复 Case、不在课堂显示 AI 建议、不用大面积浮层/渐变/卡片堆砌，不因失败关闭 sheet 并丢掉文字。

### 4.15 Acceptance scenarios

1. 已知学生/学科：点击记录问题后只写一句标题即可保存，目标 10–20 秒。
2. 键盘打开且输入中文长句：标题和保存仍可见/可滚动，back 不丢内容。
3. 相近 Case 存在：提示出现但不阻塞；教师仍可完成记录。
4. 保存失败：sheet 不关闭，文本保留，重试可用。
5. 离线：明确本机草稿与正式学情的区别；重连后可继续恢复。
6. 无权限：不能保存到受限对象，且不泄露其详情。

## 5. 四屏共同验证矩阵

| 目标 | Today | Student Detail | Learning Case | Quick Capture |
| --- | --- | --- | --- | --- |
| 30 秒课前理解 | 逾期/到期/待验证/待安排 | 三件事 + 最近事实 | 当前 status + Next Action | 不参与 |
| 10–20 秒课堂记录 | 提供入口 | 提供入口 | 提供入口 | 核心指标 |
| 60 秒课后闭环 | 完成/进入上下文 | 从学生理解 Case | 补证据/动作/验证 | 稍后整理 |
| 语义正确 | Action queue | 当前学生上下文 | 六段证据叙事 | new/待整理 |
| 失败可恢复 | action 重试 | 内容保留 | 编辑重试/timeline 不造假 | 输入保留/draft |
