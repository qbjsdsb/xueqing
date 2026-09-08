# Xueqing Core Screen Specifications

状态：Phase 0A.5 implementation-ready screen baseline

最后更新：2026-09-09

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

教师打开软件后，在约 30 秒内知道今天真正需要处理什么、哪些已逾期、哪些安排在以后、哪些提醒还没有日期。没有明确 Action 的观察记录、检查结果或继续关注状态，不因为“系统流程”自动变成 Today 任务。

### 1.2 Entry points

- 默认一级导航入口。
- 课程结束返回。
- 保存 Quick Capture 后返回来源上下文。
- 完成 Student/Case action 后返回并保留原列表位置。

### 1.3 Information priority

1. 页面标题 `今日` + 一句工作说明。
2. `overdue`：已逾期的 pending primary actions。
3. `today`：今天到期的 pending primary actions。
4. `future`：有明确未来日期的 pending primary actions，不进入“今天的工作”。
5. `undated`：没有日期、但教师已经明确创建的 pending primary actions。
6. 最近学生和进入学生上下文的入口。

Today 的硬边界是“教师明确安排过的 Action”，不是“所有尚未 closed 的 Case”。`new` 且没有 Action 的快速记录、`pending_verification` 且没有 Action 的检查结果、普通 Evidence/Intervention/Assessment 都留在学生成长历史和问题详情中，不额外制造第二份待办。每个 Action 只能进入一个语义 bucket：`overdue`、`today`、`future`、`undated`；不能以“不是逾期/不是无日期”隐式推断 today。每个 bucket 内同一学生多个事项合并成一个学生簇：姓名只出现一次，最多直出三项，其余用“还有 N 项”；跨 bucket 不复制同一事项。

### 1.4 Primary action

页面 primary action 是当前第一条明确 Action 的具体处理入口，例如 `处理`；进入后可记录本次进展，并按需决定是否提醒、结束跟进。没有明确 Action 的 Case 不因为状态名被提升为 Today 主任务。页面右上可有一个上下文动作 `记录问题`，但不能用“查看 Dashboard”替代工作动作。

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


未来
  示例学生乙 · 阅读理解      9 月 6 日            [查看 Case] [完成]

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
| Many actions | 先按逾期/今天/未来/待安排分组，学生簇减少重复；提供“还有 N 项”，不横向塞满 |
| No due date | `待安排` 独立 section；默认可见，不因日期筛选消失 |
| Future action | 有明确未来日期的 action 独立进入 `未来`；不进入“今天的工作” |
| Closed Case | 不出现在 pending action 队列；若在最近学生中出现，明确 `已关闭`，提供查看历史/重新打开 |
| Reopen event | 显示 `重新打开` 的 timeline 事实和当前新的 Next Action；不把 event 当作 status，也不覆盖旧 closed 历史 |

### 1.8 Windows layout

- Expanded：232px expanded rail + max-width 工作区；主列工作队列，右侧可放最近学生/轻量上下文，不无限拉宽。
- Medium：72px compact rail；工作队列单列，行尾可放日期/操作。
- hover 显示行可操作区域；focus ring 明显；Tab 按 header action → section → row → row action 顺序。
- mouse wheel 滚动列表；学生行或 Case row 的 `查看 Case` 按钮进入详情，完成 action 不离开当前队列。
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

关键行/按钮至少 48dp；Student row 的导航与 Action row 的具体按钮，以及 Case row 的 `查看 Case` 与主操作按钮分别拥有清楚的可点击边界，避免误触。完成 action 后给出短反馈，不把 Case 自动变成 closed。

### 1.13 Privacy / permission visibility

列表中只显示当前权限范围内的学生和 Case；无权内容不通过“空”伪装。可查看不可编辑时保留摘要但将修改 action 置为 disabled 并解释原因。

### 1.14 Anti-patterns

不做统计图/大数字 KPI、彩色状态胶囊墙、重复学生卡、按日期筛选后隐藏无日期 action、把 Case 状态直接翻译成待办、把 Today 变成普通 Todo App。

### 1.15 Acceptance scenarios

1. 有一个逾期 action、一个今天 action、一个没有 action 的继续关注 Case、一个未来 action、一个待安排 action：Today 只出现四条明确 Action；继续关注 Case 保留在学生历史，不制造额外待办。
2. 同一学生有三条 action：学生姓名只出现一次，三条仍可单独操作。
3. 375px 宽和 1280px 宽：内容关系一致，宽屏没有无限拉宽，窄屏 action 没被截断。
4. 点击完成失败：action 仍可见，输入/上下文没有丢，出现重试。
5. 进入 Student/Case 再返回：回到原来源和滚动位置。

## 2. Student Detail 学生详情

### 2.1 User goal

第一次接手学生的教师无需翻完整历史，就能回答“现在最重要的三件事是什么、还有哪些问题需要按需查看、最近发生了什么”。

### 2.2 Entry points

- Today 学生簇/学生行。
- 学生搜索结果。
- 课程入口中的学生。
- Case detail 的学生上下文。

### 2.3 Information priority

1. 姓名 + 学科/年级最小上下文 + 权限提示。
2. `现在最重要的事`，最多 3 个未关闭问题，每项指向 Case 或 action。
3. 同一问题 section 的 `查看全部 N 个 / 只看重点` 渐进展开入口；完整清单只有按需时出现。
4. 未进入当前重点的 `pending verification` 问题最多预览 2 项；展开全部问题后不再重复显示该区。
5. `最近关键事实`：少量 Evidence/Lesson/Intervention。
6. 必要学科上下文；只有确实帮助理解当前问题时才显示为一行定位文字。
7. 折叠的更早 timeline；关闭历史只在按需查看全部问题或历史时出现。

### 2.4 Primary action

根据当前上下文选择一项具体主操作：优先是第一条 Next Action；若无 Case，则为 `记录问题`。不显示新的学生总分或“综合健康分”。

### 2.5 Secondary actions

`查看 Case`、`完成行动`、`记录问题`、`查看全部问题`、`只看重点`、`展开最近记录`、`查看更早历史`、在有权限时 `补充学生上下文`。

### 2.6 推荐结构

```text
[返回] 示例学生甲                         [记录问题]
数学 · 八年级
必要时的一行学科定位文字

现在最重要的事                     [查看全部 6 个]
  分数概念混淆                  待验证     [查看 Case]
  应用题审题跳步                intervening [查看 Case]
  计算检查习惯                  confirmed   [查看 Case]

另外待验证（若存在且未进入重点，最多预览 2 项）
  迁移题检查                    待验证      [查看 Case]

最近关键事实
  9 月 2 日 课堂观察……
  8 月 30 日 教学动作……

更早历史（按需展开）
```

点击 `查看全部 6 个` 后，同一 section 改为 `全部问题` 并显示当前与已关闭问题；`另外待验证` 不再重复出现，提供 `只看重点` 返回默认视图。

### 2.7 States

| 状态 | 规格 |
| --- | --- |
| Empty | 完全没有 Case：显示“还没有记录的问题。发现问题时，可以先记下来。” + `记录问题` |
| Only closed history | 没有未关闭 Case：显示“当前没有需要跟进的问题。已有问题记录仍然保留，需要时可以查看全部。” + `查看全部 N 个` |
| Loading | `正在打开学生详情…`，摘要结构先占位，不展示错误空状态 |
| Error | `学生详情暂时打不开。请重试；如果仍失败，稍后再打开。` + 重试/返回 |
| No permission | `当前账号无权查看这名学生的学情内容。`；不展示姓名以外超出权限的细节 |
| Saving | 完成/补充 action 后局部显示 `保存中…`，保留当前 section |
| Save failed | 原值保留，显示失败和重试，不用乐观成功覆盖事实 |
| Offline | 读取到的内容标识当前同步状态；Quick Capture 草稿与正式 Case 分开 |
| New record | 新记录可以作为未关闭问题进入当前重点排序；它已经是正式成长记录，不额外制造“待整理”任务 |
| Long content | 学科定位、Case title、最近事实可换行；重点行自然增高，不固定一行 |
| Many cases | 默认只显示最多 3 个当前重点 + 最多 2 个额外待验证；其余通过 `查看全部 N 个` 展开，不能让首屏淹没在历史中 |
| No due date | action 仍显示为 `待安排` |
| Closed Case | 不计入学生列表的“跟进中的问题”数量；只在 `查看全部`/历史中出现，仍可进入 recurrence/reopen 流程 |
| Reopen event | 重新打开后回到当前问题排序，显示新的 Next Action 和 reopen 事件；status 仍属于六段生命周期 |

### 2.8 Windows layout

Expanded 使用主工作列 + 辅助事实列；主列先放当前重点和按需展开入口，辅助列放最近关键事实/必要学科上下文。Medium 以单列为主；side panel 只有在最小列宽满足时出现。Tab 顺序按 header → 当前重点 → 展开/收起 → 额外待验证 → 最近事实 → 历史。

### 2.9 Android layout

单列滚动；返回回到来源；标题和 `记录问题` 之间不塞多余字段。最多 3 个当前重点和 Next Action 优先出现在屏幕上方，完整问题与历史通过可展开入口按需出现。长中文不被头像或标签挤压。

### 2.10 Responsive transition

Expanded 的辅助事实列在 Medium/Compact 移到当前问题 section 之后；不删除最近关键事实。Compact 的主 action 可以成为全宽按钮，Expanded 可位于 header/侧栏。展开全部问题只改变内容量，不改变 Case 生命周期或排序语义。

### 2.11 Keyboard behavior

`Alt/Command+Left` 仅在无文本编辑冲突时返回；Tab 只访问可操作的学生 row、Case row 按钮、展开/收起和 action 按钮。打开 Case 后 focus 进入 Case title 或 primary action，而不是静态装饰。

### 2.12 Touch behavior

学生行、Case 行、展开/收起、主要 action 分开触控区域；长按不触发隐藏菜单。滚动时不误触 action，浮动/固定操作不遮住最近事实。

### 2.13 Privacy / permission visibility

身份信息最小化；联系方式、非当前学科信息不主动展开。可查看不可编辑时显示 `你可以查看，但不能修改此学科内容。`；无权限不泄露 Case title、状态数量或 Evidence。

### 2.14 Anti-patterns

不做几十字段档案表、成绩趋势图、成长指数、风险概率、标签云、四个统计 Card 的首屏；不把最近事实写成无来源的“智能洞察”；不同时铺开“当前 Learning Cases”和另一份完整“待验证”造成重复。

### 2.15 Acceptance scenarios

1. 新教师打开已有多个 Case 的学生详情，默认能在 30 秒内看到最多 3 个重点和一条最近 Evidence，不需要先滚过完整 Case 清单。
2. 有更多问题时 `查看全部 N 个` 可达；展开后当前与已关闭问题都保留，关闭历史仍可进入 recurrence/reopen，`只看重点` 能恢复默认视图。
3. 未进入重点的待验证很多时默认最多预览 2 项，不与重点重复；展开全部问题后不再出现重复的待验证区。
4. 学生无 Case 时能直接进入 Quick Capture；只有关闭历史时不会把关闭历史算成当前跟进数量。
5. Case title 很长、text scale 1.5：主操作和展开入口仍可见，内容自然增高。
6. 无编辑权限：能看到权限原因，不把页面伪装成空列表。
7. 从 Today 进入后返回：Today 的学生簇和滚动位置保持。

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

只显示当前状态允许的下一步：例如 `补充证据`、`记录教学动作`、`记录一次检查`、`确认稳定`、`安排下一次检查`、`重新打开`。后面三项是 Case command；在本阶段 prototype 中只展示命令入口并明确提示不会改变领域状态，不调用普通 action completion。主操作不根据颜色猜测，且不把 Assessment passed 自动转为 stable/closed。

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
| Reopen event | 保留 closed 和 reopen 事件；当前 status/Next Action 按新流程显示，reopen 不成为额外 status |
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

每个段落主 action 使用共享 48dp 目标；Evidence 文本区域可滚动；状态/历史不可点击时不做成大面积伪按钮。确认 stable、重新打开等状态命令需要明确按钮和必要确认；prototype 不伪造领域状态变化。

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

课堂中用一只手在 10–20 秒内留下一条足够具体的真实观察，不因为分类、附件、判断或行动计划错过事实；以后有新情况时继续记录，需要提醒时再提醒。

### 4.2 Entry points

- Today 的 `记录问题`。
- Student Detail 的 `记录问题`。
- Case Detail 发现新问题的上下文入口。
- 课程记录中的 `记录问题`。

已知 Student/Subject 时直接带入上下文；未知时先搜索/选择学生和学科，但不在课堂路径追加完整档案字段。

### 4.3 Information priority

1. 学生 + 学科上下文；从学生详情进入时直接沿用，全局只有一个可选学生时自动选中。
2. 唯一主输入 `今天发现什么？`，写下一条题目、行为或课堂中实际看到的事实。
3. `更多选项`：问题类型、现场图片等只有需要时才展开。
4. 非阻塞相近 Case 提示。
5. `记录问题` 保存；取消为次要动作。

主输入既作为首次事实，也由客户端从首句生成简短 Case title，避免教师把同一件事组织两遍。不在最短路径强制要求 taxonomy、根因、教师判断、完整方案、Next Action、due date 或附件。

### 4.4 Primary action

`记录问题`。主输入为空时不提交；一条具体事实即可保存为正式 `new` 记录。保存本身不创建 Action，也不进入 Today；是否提醒、继续记录或结束跟进由后续真实教学情况决定。

### 4.5 Secondary actions

`取消`、更改学生/学科、展开/收起 `更多选项`、保存失败后的 `重试`、成功后的 `查看学生`。相近 Case 提示中的“仍然记录”是非阻塞选择，不是强制合并。

### 4.6 推荐结构

```text
记录问题                         [关闭]
学生  示例学生甲 · 数学           [更改]

今天发现什么？ *
[写下刚才真实看到的题目、行为或表现……]
看起来已有相近记录……（可忽略）

[更多选项]
  问题类型（可调整）
  现场图片（可选）

[取消]                         [记录问题]
```

### 4.7 States

| 状态 | 规格 |
| --- | --- |
| Empty | 不存在有效学生/学科上下文时，先显示搜索/选择；不能保存到未知对象 |
| Loading | 学生/学科上下文加载时显示局部 loading；已经输入的主记录不清空 |
| Error | 上下文读取失败时给出重试；输入区若可用仍保留 |
| No permission | 不能为无权学生/学科创建 Case；显示权限原因，不显示受限资料 |
| Saving | button 文案 `保存中…`，防重复点击；主记录和已展开的可选内容保留可见 |
| Save failed | `保存失败，刚才的内容还在。` + `重试`；关闭后仍可选择保留草稿 |
| Offline | `当前离线，已保留为本机草稿（未计入正式学情）`；不显示已正式保存 |
| Draft | 打开已有草稿时显示来源、时间和继续编辑；保存成功后才从 draft 语义移出 |
| Long content | 主记录自然换行并可滚动；键盘打开时保存按钮仍可到达 |
| Duplicate hint | 相近 Case 提示非阻塞，不自动改标题、不阻止保存；提供“仍然记录”或稍后处理 |
| Many cases | 提示只显示少量相近结果和 `查看全部`，不在课堂 sheet 展开完整历史 |
| No due date | 快速记录不要求 due date；只有教师明确需要提醒时才创建/安排 Action |
| Closed Case | 相近提示可说明已有已关闭 Case，但新问题仍可记录为新 Case/稍后处理，不静默写入旧 Case |
| Reopen event | 如果上下文包含 reopen event，明确显示当前 Case status，不把 Quick Capture 当作重新打开操作 |

### 4.8 Windows layout

在 expanded 窗口使用 centered dialog 或右侧 panel，宽度约 420–520px，保留底层 Student/Case 上下文；medium 可使用 dialog。支持 mouse、Tab、Enter/Space、Ctrl+Enter（多行 note 提交）、Esc（无改动直接关闭；有改动先确认）。

### 4.9 Android layout

使用 `showModalBottomSheet` 或全屏 sheet，SafeArea + `MediaQuery.viewInsetsOf` 处理系统栏和 IME。已知上下文时打开后 focus 到主记录输入；保存操作至少 48dp，单手可触达。内容区可滚动，键盘打开不遮住保存。

### 4.10 Responsive transition

compact 是 bottom sheet/全屏短任务；medium 是可滚动 dialog；expanded 是右侧 panel/centered dialog。字段和顺序不变，只有 surface 形态、宽度和操作区位置变化。

### 4.11 Keyboard behavior

主记录输入支持多行；Windows 可用 Ctrl+Enter 保存。Tab 顺序为 Student/Subject（若需要选择）→ 主记录 → 更多选项（若展开）→ 保存 → 取消。Esc/back：先收键盘，再按脏状态确认。全局快捷键不抢文本输入。

### 4.12 Touch behavior

学生/学科选择、主记录、更多选项、保存、取消均有至少 48dp 的可操作面积；相近 Case 提示不采用容易误触的全屏点击。保存防双击，失败时重试仍使用原内容。

### 4.13 Privacy / permission visibility

只显示当前已选且有权限的学生/学科上下文；切换选择前不展示相近 Case 的受限 title。设计预览使用虚构数据；正式版本需要遵循会话、assignment、RLS 和 draft 隐私规则。

### 4.14 Anti-patterns

不做完整 Case 表单、把 taxonomy/分类放在事实输入之前、强制根因/owner/action/date/附件、不强行合并重复 Case、不在课堂显示 AI 建议、不用大面积浮层/渐变/卡片堆砌，不因失败关闭 sheet 并丢掉文字。

### 4.15 Acceptance scenarios

1. 已知学生/学科：点击记录问题后只写一条具体观察即可保存，目标仍为 10–20 秒。
2. 键盘打开且输入中文长句：标题和保存仍可见/可滚动，back 不丢内容。
3. 相近 Case 存在：提示出现但不阻塞；教师仍可完成记录。
4. 保存失败：sheet 不关闭，文本保留，重试可用。
5. 离线：明确本机草稿与正式学情的区别；重连后可继续恢复。
6. 无权限：不能保存到受限对象，且不泄露其详情。

## 5. 四屏共同验证矩阵

| 目标 | Today | Student Detail | Learning Case | Quick Capture |
| --- | --- | --- | --- | --- |
| 30 秒课前理解 | 逾期/今天/未来/待安排 | 三件事 + 最近事实 | 当前 status + 按需 Next Action | 不参与 |
| 10–20 秒课堂记录 | 提供入口 | 提供入口 | 提供入口 | 核心指标 |
| 60 秒课后跟进 | 处理明确提醒/进入上下文 | 从学生理解 Case | 继续记录/提醒/结束 | 无强制整理 |
| 语义正确 | 只有明确 Action 进入队列 | 当前学生上下文 | 结构化成长历史 | new 正式记录、无默认 Action |
| 失败可恢复 | action 重试 | 内容保留 | 编辑重试/timeline 不造假 | 输入保留/draft |
