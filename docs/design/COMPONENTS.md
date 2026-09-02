# Xueqing Component Foundation

状态：Phase 0A.5 component baseline

最后更新：2026-09-02

组件只覆盖 Today、Student Detail、Learning Case、Android Quick Capture 的真实高频场景。组件的职责是保持语义、状态、焦点和响应式行为一致，不是建立一个为了完整而完整的组件库。

## 1. 组件层级

| 层级 | 组件 | 责任 |
| --- | --- | --- |
| Shell | `AppShell` / adaptive navigation | 负责一级导航、页面安全区、窗口级布局 |
| Page | `PageHeader`、`SectionHeader` | 负责页面任务、层级、主操作 |
| Work rows | `StudentRow`、`CaseRow`、`ActionRow` | 负责扫视、直接动作、进入详情 |
| Case narrative | `StatusMarker`、`MetadataLine`、`TimelineItem`、`CaseSection` | 负责状态和证据链，不改变领域语义 |
| Input | `SearchField`、`TextField`/`Textarea`、`TaxonomyPicker`、`DateActionControl` | 负责最小输入和状态反馈 |
| Feedback | `EmptyState`、`LoadingState`、`ErrorState`、`SaveStatus`、`OfflineDraftNotice` | 负责不理想状态的可理解性和恢复 |
| Layer | `Dialog`、`Sheet`、Quick Capture shell | 负责聚焦短任务，不隐藏底层上下文 |

没有真实 screen 使用场景的组件不进入本阶段。Avatar、chart、score badge、tag cloud、AI insight card 不在组件清单中。

## 2. Shell 与导航

### `AppShell`

- Compact：AppBar + bottom navigation，最多四个一级入口。
- Medium：72px 左右 compact rail，图标必须配 tooltip/辅助文本。
- Expanded：约 232px expanded rail，显示图标、中文名称和 selected indicator。
- selected 不只靠颜色：背景/左侧 indicator + label/semantics。
- nav item 可 focus、可 hover、可 keyboard activate；静态品牌标题不可进入 Tab。
- shell 使用 `SafeArea`，内容区独立滚动；resize 不清空页面状态。

### `PageHeader`

包含页面标题、可选一句任务说明、上下文（日期/学生/学科）和最多一个 primary action。窄屏允许标题和 action 分行。不要在 header 堆统计数字。

### `SectionHeader`

用标题、数量（若对操作有帮助）和可选轻量动作分组。数量是导航提示，不是 KPI；没有内容时 section 仍可用空状态解释。

## 3. 工作行

### `StudentRow`

显示：学生姓名、学科/年级上下文、当前最重要的一句摘要、待处理数量（如有）。整行可打开 Student Detail；行尾只放一个直接动作时要有清楚 label。

状态：default、hover、focus、pressed、disabled、loading。长姓名允许两行；不把联系方式放入 Today 行。

### `CaseRow`

显示：Case title、status marker、最近关键事实或更新时间、Next Action 的短文案。Case status 与 action status 分开显示；“待验证”不能被写成“逾期”。Case row 是信息容器，不是包住其他按钮的父级 button；使用独立的 `查看 Case` 导航按钮，再用一个分开的主操作按钮，避免 row navigation 与 action 的嵌套 focus/semantics。

### `ActionRow`

显示：动作标题、关联学生/Case、due 文案（今天到期/已逾期/未来日期/待安排）、动作类型或对象。`完成` 是直接 action；Case 状态命令（如确认稳定、重新打开）不使用普通 `完成` 语义。`查看 Case` 是次动作；同一学生的多条 Action 由父级 Student cluster 合并姓名。

动作完成后保留可理解的反馈：已完成、撤销窗口或进入详情；不将 Case 自动关闭。

## 4. 状态与元数据

### `StatusMarker`

由小图形/短线、明确中文文本和可选背景组成。颜色仅辅助。至少支持：今天到期、已逾期、待验证、稳定、已关闭、保存失败、离线草稿。

### `MetadataLine`

承载日期、学科、负责人、来源、更新时间等次要上下文。用 13px/20px 起始层级，不能承载唯一的核心状态。过长时换行或折叠，不使用只有 tooltip 才能看到的关键事实。

### `TimelineItem`

显示时间、事件类型、事实/动作文本、来源和关联对象。Evidence、教师判断、Intervention、Assessment 需要不同事件类型或 heading；不能用同一“备注”样式混合。

## 5. 输入组件

### `SearchField`

- placeholder：`搜索学生或学情`。
- 支持键盘 focus、清除、滚动结果、无结果和加载。
- Android 打开键盘后结果仍在可视区；Windows 可用 Ctrl/Command+K 作为可选入口，但输入时不抢快捷键。

### `TextField` / `Textarea`

- label 永远可见，placeholder 不代替 label。
- Quick Capture 标题必填；note 可选，允许长中文自然换行。
- saving 时保留文字；error 时保留文字并把 focus/语义引导到恢复动作。
- 错误提示说明修复方式，不只显示红色边框。

### `TaxonomyPicker`

只在课后 formalize 或完整 Case 编辑场景出现。课堂 Quick Capture 默认不要求。compact 使用 sheet，Windows 使用 dialog/侧栏；选择后显示文字，不只显示颜色。

### `DateActionControl`

让教师设置/更改 due date、负责人和动作文案。无日期必须有显式 `待安排` 状态；不能通过隐藏在筛选里解决无日期问题。

## 6. Feedback components

### `EmptyState`

结构：当前没有什么 + 为什么这不一定是错误 + 下一步动作。例如学生刚建档：“还没有 Learning Case。发现问题时可以先记录一句，课后再整理。”

### `LoadingState`

保留页面 skeleton 的结构感，优先局部 loading，不整页闪烁。屏幕阅读器需要有可读的 loading label。

### `ErrorState`

说明发生了什么、现有输入/数据是否安全、下一步是重试还是返回。技术错误详情不直接泄露给学生信息或普通用户。

### `SaveStatus`

状态词固定：`保存中…`、`已保存`、`保存失败`。状态要贴近操作区，并通过 semantics 通知；失败时提供 `重试`，不关闭用户输入。

### `OfflineDraftNotice`

用明确文字说明：`当前离线，已保留为本机草稿（未计入正式学情）`。不能把本机草稿呈现成已同步或已完成的正式记录。加密 draft 的正式实现属于后续工程阶段，本阶段只验证 UI 状态。

## 7. Dialog、Sheet 与 Quick Capture shell

### Windows

- dialog 适合短确认或补充少量字段；宽屏可用右侧 panel 保留底层学生/Case 上下文。
- modal 只有一层；明确标题、关闭、主/次按钮；Esc 的脏内容保护明确。
- 主操作在可预期位置，Tab 顺序为上下文选择 → 输入 → 保存 → 取消。

### Android

- bottom sheet 或全屏 sheet；使用 SafeArea 与 IME inset。
- 核心操作目标至少 48dp；内容区可滚动，保存动作永远可找到。
- back 先收键盘，再对脏内容确认；误触不丢内容。

### Quick Capture

最小结构：已知 Student/Subject 上下文 → 问题标题 → 可选补充 → `记录问题`。重复提示放在标题下方作为非阻塞 helper；保存后反馈为“已记录为待整理问题”，不强迫立即填写完整 taxonomy。

## 8. Component state contract

所有可交互组件至少要定义以下状态，screen spec 可裁剪不适用项但不能默认遗漏：

| 状态 | 键盘/鼠标 | touch | 文案/语义 |
| --- | --- | --- | --- |
| default | 可 focus | 可触摸 | 默认 label |
| hover | 轻微 surface/border | 不适用 | 不改变业务状态 |
| focus | 2px focus ring | system focus/辅助功能 | 当前可操作元素 |
| pressed | pressed overlay | pressed feedback | 已触发 |
| disabled | 不进 action focus 或明确可聚焦说明 | 不触发 | 原因若必要 |
| loading/saving | 防重复提交 | 防重复点击 | 保存中… |
| error/failed | focus 恢复 action | 保留输入 | 保存失败 + 重试 |
| offline/draft | 状态可见 | 状态可见 | 未计入正式学情 |

## 9. Accessibility contract

- 关键 touch target 统一为 `AppSpacing.touchTarget = 48dp`；文字与图标之间有足够间距，button/icon theme 不另设 44dp 等第二个事实源。
- 文字、状态、按钮名称可被 TalkBack/Windows screen reader 读出；同一状态使用同一中文 label。
- focus ring 不被 canvas 或 surface 吞掉；Tab 顺序按阅读顺序。
- 可点击整行需要 button semantics，不让静态文本假装可操作。
- color contrast 按 WCAG AA 检查；红/蓝/绿状态都伴随文字和动作。
- `textScaleFactor` 增大时不使用固定高度裁切；长 Case title、错误和保存状态可换行。

## 10. Flutter implementation map

| 组件能力 | 首选 Flutter 能力 | 额外规则 |
| --- | --- | --- |
| adaptive shell | `LayoutBuilder`、`NavigationBar`、`NavigationRail` 或轻量自定义 rail | 不以平台名决定宽度 |
| row/list | `ListView`、`SliverList`（需要时） | 保留滚轮和语义 |
| input | Material `TextField`、`InputDecoration` | label、error、IME padding |
| focus | `FocusTraversalGroup`、`FocusTraversalOrder`、Material focus | 自定义按钮才使用 `FocusableActionDetector` |
| keyboard | `Shortcuts`、`Actions`、`CallbackShortcuts` | 输入时禁用会抢文本的全局快捷键 |
| pointer | `MouseRegion`、Material hover/focus | hover 只是辅助 |
| safe area | `SafeArea`、`MediaQuery.viewInsetsOf` | 处理系统栏和软键盘 |
| semantics | `Semantics`、`ExcludeSemantics`（必要时） | 不重复朗读装饰信息 |

## 11. 不做的组件

本阶段不做：统计图表组件、成长指数、风险概率 badge、无限标签系统、复杂表格编辑器、看板拖拽、富文本编辑器、AI suggestion card、头像装饰系统、跨屏 drag-and-drop。它们没有服务四个核心 screen 的必要场景。
