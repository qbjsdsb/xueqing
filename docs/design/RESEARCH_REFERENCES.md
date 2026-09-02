# Xueqing UX/UI Research References

状态：Issue #7 research spike 完成

最后更新：2026-09-02

本研究为 Phase 0A.5 服务。研究结果先写成可审查的设计事实，再进入 `INFORMATION_ARCHITECTURE.md`、`VISUAL_FOUNDATION.md`、`RESPONSIVE_RULES.md`、`COMPONENTS.md` 和 `SCREEN_SPECS.md`。研究不以 Dribbble、Behance 或 Pinterest 作为主要依据。

## 1. 研究结论摘要

| 决策 | 证据等级 | 对 Xueqing 的结论 |
| --- | --- | --- |
| 按可用空间选择布局，并同时适配输入方式 | Official platform guidance | 用 `LayoutBuilder` / `MediaQuery.sizeOf` 和内容需求决定 rail、bottom navigation、单列或分栏；不以 `Platform.isAndroid` 代替布局判断 |
| SafeArea 与键盘 inset 是移动核心路径的结构条件 | Official platform guidance | Quick Capture 使用 SafeArea、可滚动内容和键盘避让；返回行为要保留草稿 |
| Tab / focus / pointer / scroll 都是 Windows 的正式输入 | Official platform guidance | 可操作元素才进 focus；明确 Tab 顺序、focus ring、hover 和滚轮；不要只验证触控 |
| Android 触控目标至少 48dp | Official platform guidance | Quick Capture、列表行、返回和主要按钮以 48dp 为最低可用目标 |
| 少量、浅层、清楚的主导航降低选择成本 | Official platform guidance + Xueqing product judgment | Today / 学生 / 课程 / 学情四个一级入口；详情页作为上下文，不放进一级导航 |
| 必填最小化、稍后补全、保留草稿降低记录负担 | Observed mature-product pattern | Quick Capture 只要求问题标题；其他 Case 字段延后 formalize；错误和离线不能吞掉文字 |
| 同一数据可用不同视图理解，但视图不应改变语义 | Observed mature-product pattern | Today 组织行动，Student Detail 组织交接，Case 组织证据链；不是复制三套数据 |
| Excel 原型里的连续问题与三阶知识闭环值得保留 | Xueqing product judgment | 映射为 Learning Case、Evidence/Intervention/Assessment、Case Action 和 timeline；不复制 Excel 表格形状 |

## 2. 官方平台与无障碍依据

### 2.1 Flutter adaptive / responsive

- [Adaptive and responsive design](https://docs.flutter.dev/ui/adaptive-responsive)：Flutter 将 responsive 理解为适应可用空间，将 adaptive 理解为选择适合该空间与交互方式的布局。对 Xueqing 的约束是“同一语义、不同工作重心”，不是手机页面放大到 Windows。
- [Best practices for adaptive design](https://docs.flutter.dev/ui/adaptive-responsive/best-practices)：建议根据实际可用空间、输入方式和内容需要拆分布局，支持键盘、鼠标/触控板和滚动，不锁死方向，也要考虑状态恢复。Xueqing 因此使用窗口宽度和内容要求分支，避免硬编码平台分支。
- [General approach to adaptive design](https://docs.flutter.dev/ui/adaptive-responsive/general)：推荐用 `MediaQuery` 或 `LayoutBuilder` 测量空间，并在同一组件层保留共享数据/语义。文档示例也使用窄屏 bottom navigation、中等/宽屏 rail 的结构；Xueqing 借鉴这个响应式关系，不复制示例视觉。
- [SafeArea and MediaQuery](https://docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery)：SafeArea 用于避开系统 UI，MediaQuery 提供窗口尺寸、文字缩放、高对比度和辅助功能信息。Quick Capture 需要在表单内容和操作区同时使用这些信息。
- [User input and accessibility](https://docs.flutter.dev/ui/adaptive-responsive/input)：Flutter 官方说明滚动列表默认支持滚轮，Material 控件支持键盘 Tab 和 focus 视觉，自定义控件要使用 focus / traversal / pointer 相关能力，并在输入时谨慎处理全局快捷键。Xueqing 的 Case 和 Today 列表据此设计滚轮、Tab、Enter/Ctrl+Enter 和 focus ring。

### 2.2 Windows navigation and input

- [Windows navigation basics](https://learn.microsoft.com/en-us/windows/apps/design/basics/navigation-basics)：导航应一致、简单、清楚，减少同级项目，避免深层级与来回跳转。Xueqing 采用四个一级工作入口，详情页通过上下文进入。
- [Focus navigation](https://learn.microsoft.com/en-us/windows/apps/develop/input/focus-navigation)：只有可交互元素支持 focus；focus 顺序要线性、符合阅读方向并按逻辑分组。Xueqing 不让静态状态、装饰图标进入 Tab 顺序。
- [NavigationView](https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/navigationview)：Windows 的 NavigationView 在不同宽度下可展开、紧凑或收为菜单，并强调浅层层级和明确的 selected indicator。Xueqing 借鉴“expanded rail / compact rail / minimal menu”的空间关系，不复制 acrylic、WinUI 皮肤或图标样式。

### 2.3 Android touch, insets and accessibility

- [Android accessibility apps and touch targets](https://developer.android.com/guide/topics/ui/accessibility/apps)：Android 建议可触控/可聚焦目标至少 48dp × 48dp。Xueqing 把 Quick Capture 的保存、返回、学生选择、Case 行和 action 行按至少 48dp 设计。
- [Handle insets](https://developer.android.com/develop/ui/views/layout/insets)：Android 15 默认 edge-to-edge，应用需要根据 system bar 和 IME inset 防止重要内容或触控目标被遮挡。Quick Capture 的操作区必须随软键盘动态避让。
- [Window insets in Compose](https://developer.android.com/develop/ui/compose/system/insets)：虽然 Xueqing 使用 Flutter，IME、safe drawing 和 gesture inset 的问题同样适用于移动交互判断；原型用 Flutter `SafeArea` 与 `MediaQuery.viewInsetsOf` 验证对应行为。

### 2.4 WCAG 基线

- [WCAG 2.2 contrast minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum)：普通文字对比度至少 4.5:1，大文字至少 3:1。核心文字、状态文字和按钮不能依赖低对比度灰色。
- [WCAG 2.2 focus appearance](https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html)：focus 指示必须可见并有足够对比。Windows 原型采用明确 focus ring，不用只有 hover 的弱变化。
- [WCAG 2.2 quick reference](https://www.w3.org/WAI/WCAG22/quickref/)：非文字 UI 组件也要有可辨识的对比基线；Xueqing 将颜色之外的文字、图标和结构作为状态冗余表达。

## 3. 成熟知识工作软件的具体模式

这里研究的是公开帮助文档描述的具体机制，不是“参考某品牌风格”。

### 3.1 Linear：最小创建、状态与可恢复编辑

来源：[Configuring workflows](https://linear.app/docs/configuring-workflows)、[Creating issues](https://linear.app/docs/creating-issues)、[Editing issues](https://linear.app/docs/editing-issues)。

| 它解决的问题 | 借鉴什么 | 为什么适合 Xueqing | 坚决不复制 | 教师场景映射 |
| --- | --- | --- | --- | --- |
| 记录新事项时不被大量元数据阻塞 | 标题 + 最小状态即可创建，其余属性可后补；草稿/短时间编辑可恢复 | 课堂发现问题时先保住事实和标题，课后再整理 Case | 不复制 issue tracker 的工程术语、快捷键密度、团队视觉或完整工作流配置 | Quick Capture 只要求问题标题，默认进入 new，待课后 confirm |
| 状态变化要能解释流程而不是装饰 | 状态有明确顺序与类别，编辑历史保留 | Case lifecycle 和 action lifecycle 都需要可追溯 | 不把 Case status 直接当作 action status，也不引入无限自定义状态 | Case 页面显示当前阶段；timeline 保留 reopen/transition |
| 频繁编辑不应丢失上下文 | 内联编辑与历史恢复 | 教师在复盘时需要少跳转地补充 Evidence 或判断 | 不复制桌面端批量 issue 操作成为主要交互 | Windows 支持内联/侧栏补充，Android 采用分步 sheet |

### 3.2 Notion：一个对象，多种工作视图

来源：[Views, filters, and sorts](https://www.notion.com/help/views-filters-and-sorts)、[Using database views](https://www.notion.com/help/guides/using-database-views)。

| 它解决的问题 | 借鉴什么 | 为什么适合 Xueqing | 坚决不复制 | 教师场景映射 |
| --- | --- | --- | --- | --- |
| 同一数据在不同任务下需要不同的扫描方式 | list/table/timeline 等视图可改变组织方式，属性可隐藏、过滤、排序；打开可进入 peek 或完整页 | Today、Student Detail、Case 各自服务行动、交接、证据判断，但共享同一语义 | 不复制自由拼装数据库、无边界属性、无限配置导致的复杂度 | Today 隐藏不必要字段；Student Detail 突出当前三件事；Case 展开证据链 |
| 需要在列表和上下文间保持位置感 | side peek / 上下文打开是可借鉴的空间关系 | Windows 可在列表旁看 Case，减少来回跳转 | Android 不强行使用窄屏 side peek，也不把整页做成可配置数据库 | Windows medium/expanded 可使用侧栏；compact 使用栈式页面 |

### 3.3 Todoist：离线反馈的可理解性

来源：[Use Todoist while offline](https://www.todoist.com/help/todoist/features/use-todoist-while-offline-4rbaZw)。

| 它解决的问题 | 借鉴什么 | 为什么适合 Xueqing | 坚决不复制 | 教师场景映射 |
| --- | --- | --- | --- | --- |
| 连接中断时用户不知道改动是否成功 | 明确离线图标/状态，并说明稍后同步；同步完成前不要让用户误以为已经完成 | 课堂记录不能因网络抖动而丢失，教师需要知道“正式保存”与“本地草稿”的差异 | Xueqing 仍遵循 online-first 与加密 draft 的产品边界，不把公开 todo 的同步机制当作 Phase 0.5 实现 | Quick Capture save failed/offline 保留文本，显示重试或本机草稿语义 |

## 4. Xueqing Excel 原型的审阅

审阅对象：用户提供的 `学情档案Excel化原型_v0.1_修复版.xlsx`。本次仅读，不修改附件。

观察到 8 个 sheet：说明与规则、学生档案、初诊问题、知识闭环、周度跟进、顽固问题、家校沟通、阶段复盘。原型提供了三个对产品有用的连续性线索：

1. 一个问题会跨周追踪，而不是一次输入即消失。
2. 知识问题有多次纠正/练习/测试的连续动作。
3. 周度跟进需要把旧问题进展、新问题、下周重点放在同一复盘语境里。

这些被映射为：一个 `Learning Case` 连接问题和生命周期；`Evidence`、`Intervention`、`Assessment / Verification` 分开承载证据与教师动作；`Case Action` 承载明确的 Next Action；timeline 解释跨周历史。

不复制的部分：固定 50 行、宽表格、重复填写周度摘要、把阶段复盘做成总分/统计表、输入区的 Excel 下拉体验、家校沟通和报告字段在本阶段的扩张。它们会让软件退化为 Excel、Dashboard 或 Phase 0B 业务实现。

## 5. 从研究到设计事实源

| 研究发现 | 写入的事实源 | 验证方式 |
| --- | --- | --- |
| 空间和输入方式决定布局 | `RESPONSIVE_RULES.md` | 375、600、800、1024、1280 宽度检查；键盘/触控检查 |
| 最小创建 + 可恢复草稿 | `SCREEN_SPECS.md`、`UX_COPY.md` | Quick Capture 10–20 秒场景；saving/fail/offline/draft 状态 |
| 浅层导航 + 上下文详情 | `INFORMATION_ARCHITECTURE.md` | Today → Student → Case 往返；不增加一级入口 |
| 结构优先于 Card 与颜色 | `VISUAL_FOUNDATION.md`、`COMPONENTS.md` | Anti-AI review；检查边界、圆角、阴影、胶囊密度 |
| focus、touch、字体缩放和长文本 | `COMPONENTS.md`、`SCREEN_SPECS.md`、`DESIGN_REVIEW_CHECKLIST.md` | Tab 顺序、48dp、text scale、滚动和错误恢复 |

## 6. 研究边界与未决问题

- 本 spike 没有把任何第三方产品当成视觉模板；还需要在后续真实可用性测试中验证教师是否能在 30 秒内理解学生详情。
- 官方指导解决的是平台可用性，不直接决定 Xueqing 的色彩和中文语气；这些属于 Xueqing product judgment / visual preference，已在其他事实源中单独标记。
- Phase 0B 再决定真实权限数据如何影响列表过滤、draft 加密和网络状态；Phase 0A.5 只定义 UI 可见性和失败文案。

## 7. Issue #7 完成记录

- 官方平台：Flutter adaptive/input/SafeArea、Windows navigation/focus、Android touch/insets、WCAG 对比度/focus 已核对。
- 成熟模式：Linear 的最小创建与状态、Notion 的多视图/上下文打开、Todoist 的离线反馈已逐项写明借鉴与不复制边界。
- 内部材料：Phase 0A 产品/流程/不变量/权限/隐私文档已对照，Excel 原型已读并完成映射判断。
- 输出：本文件及其链接的设计事实源；Issue #7 可在 Draft PR #9 中标记为完成，主 Issue #6 继续保持开放等待设计审计。
