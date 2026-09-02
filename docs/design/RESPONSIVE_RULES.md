# Xueqing Responsive and Adaptive Rules

状态：Phase 0A.5 responsive baseline

最后更新：2026-09-02

Xueqing 采用 adaptive 规则：同一套产品语言和对象，在不同可用窗口、内容需求和输入方式下选择不同布局。`WindowSizeClass` 只描述当前空间，不代表 Android 或 Windows；不要用 `Platform.isAndroid` 作为唯一分支。

## 1. Size classes

| Window size class | 宽度参考 | 导航形态 | 典型工作方式 |
| --- | ---: | --- | --- |
| Compact | `<600px` | AppBar + bottom navigation | 单手搜索、快速记录、完成行动 |
| Medium | `600–1023px` | compact rail（图标 + tooltip/辅助文本） | 小窗口或横屏移动设备，单列优先 |
| Expanded | `≥1024px` | expanded rail（图标 + 文字） | Windows 扫视、比较、编辑、复盘 |

这些是起始断点，不是设备名单。最终布局还要检查内容是否需要第二列：如果第二列会让 Case title、Evidence 或 action 变窄，就保持单列。

## 2. Content width and gutters

- Compact：页面水平 padding 16px；Quick Capture 内容区 16px；触控目标不贴屏幕边缘。
- Medium：内容水平 padding 24px；主内容建议 max width 760px；需要双列时各列最小 320px。
- Expanded：rail 232px；主工作区 padding 32px；正文工作区 max width 1200px，阅读列通常 720–820px；侧栏用于 action/metadata，不无限拉长正文。
- 宽于 1440px：增加画布留白或侧栏呼吸，不把列表行拉到屏幕边缘。
- 每个页面使用 `ConstrainedBox` / `SizedBox` 或等价约束；学生名、Case title 和 timeline 不因为大窗口而拉成难读长行。

## 3. Navigation transitions

| 条件 | 结构变化 | 保持不变 |
| --- | --- | --- |
| Compact → Medium | bottom navigation 变 compact rail；页面 header 获得更多横向空间 | 一级入口、选中状态、返回语义 |
| Medium → Expanded | compact rail 变 expanded rail；可增加并列上下文或 side panel | 同一对象、同一文案、同一主操作 |
| Expanded → 窄窗口 | 侧栏移动到内容顶部/折叠；不缩小文字至不可读 | Next Action、状态、错误和权限说明 |
| 字体放大 | 由内容自然增高，按钮/行可换行 | 不裁剪核心文字，不让操作被遮挡 |

## 4. Today adaptive behavior

### Compact

- 学生簇是主要视觉单位；学生名只出现一次。
- 每条 action 直接提供一个主完成操作，次操作进入详情。
- `待验证` 和 `待安排` 分成明确 section，不使用横向 tabs 隐藏。
- 头部保留搜索学生、记录问题两个高频入口；筛选通过 bottom sheet。

### Medium

- 保持单列 action queue；可在行尾显示日期和状态。
- 如果有足够空间，最近学生放在主队列下方，不创建 dashboard 卡片。
- 右侧详情只在内容最小宽度足够时出现；否则进入栈式页面。

### Expanded

- 左侧 expanded rail；主列显示 action queue，右侧可显示“最近学生”或当前选中上下文。
- 右侧不是必需的独立数据源；只显示当前队列的辅助入口，避免重复轰炸。
- 支持 hover 预告操作，真正改变状态仍需明确 click/keyboard activation。

## 5. Student Detail adaptive behavior

- Compact：按“身份最小上下文 → 现在最重要的三件事 → Cases → 待验证 → 最近事实 → 历史”单列排列；主 action 在标题下方。
- Medium：仍以单列为默认；只有最近事实不压缩当前工作区时才侧放。
- Expanded：主列显示三件事、Case 和待验证，辅助列显示最近关键事实与学科上下文；辅助列可滚动但不能遮住主 action。
- 长姓名、学科名、Case title 允许换行；任何固定高度的摘要行都必须在 text scale 增大时失效为自适应高度。

## 6. Learning Case adaptive behavior

- Compact：固定纵向叙事顺序；Case status 和 Next Action 贴近顶部；编辑 Evidence/判断/干预用 sheet 或分步区域。
- Medium：保留纵向叙事；action/metadata 可在顶部右侧排列但不缩小标题。
- Expanded：主列是问题到 Verification 的叙事，侧栏固定显示 status、priority、owner、due 和 primary action；timeline 位于主内容之后或独立可滚动区。
- `passed`、`stable`、`closed`、`reopened` 必须以文字区分，不能只通过侧栏颜色区分。

## 7. Android-specific input rules

- 所有需要点击的关键目标至少 48dp × 48dp；列表行如果承载多个动作，扩大可点击区域并分离危险操作。
- 页面 body 使用 SafeArea；Quick Capture 的底部操作区根据 `viewInsets` 随软键盘上移。
- 键盘弹起后标题输入仍可见，保存按钮可滚动到或保持在可视区域；不把底部按钮固定在键盘后面。
- 返回行为：第一次返回收起键盘；有未保存文字时第二次返回给出保留/放弃确认；无改动才直接关闭。
- touch down 不立即触发 destructive action；删除/丢弃需要确认。重复 Case 提示不阻塞首次记录。
- 连接中断/重连状态在当前上下文内可见，保存失败时输入继续保留。

## 8. Windows-specific input rules

- 支持 Tab 按阅读顺序移动 focus，Enter/Space 激活当前操作，Esc 关闭无改动 dialog/sheet；Ctrl+Enter 可提交多行 Quick Capture。
- 只有 button、link、text field、select、可打开行等交互元素进入 Tab 顺序；静态 status marker、装饰 icon 不进入。
- hover 只提供位置反馈；不可让 hover 成为了解状态的唯一方式。
- ListView/SingleChildScrollView 支持 mouse wheel；滚动不改变当前 selection。
- 窗口 resize 触发布局重排，不触发数据重载；滚动位置和正在编辑的草稿应保留。
- 宽窗口不无限拉伸内容；至少保留清晰的主列/侧栏边界和阅读 measure。

## 9. Input and focus order

各核心页面的默认 focus 顺序：

1. 跳过链接/页面标题（若有）→ 一级导航/返回。
2. 搜索或上下文选择。
3. 当前页面 primary action。
4. 主要列表/Case 内容。
5. 次要筛选、辅助入口和历史展开。

Quick Capture 的 focus 顺序固定为：学生/学科确认 → 问题标题 → 可选补充 → 保存 → 取消/稍后整理。输入文本时，全局快捷键不抢占 Ctrl/Command 组合键。

## 10. State transitions across size changes

窗口变化不应改变业务状态：

- loading 保留 loading 的局部位置；不因换成 rail 而清空列表。
- saving 保留按钮和输入内容；完成后在原上下文反馈。
- save failed / offline draft 保留可恢复内容；切换宽度不丢 draft。
- detail 从 side panel 变为 full page 时，保持当前 Student/Case 以及返回来源。
- no permission 只换成受限内容，不把“空列表”误报成“没有数据”。

## 11. Testing matrix

| 检查维度 | 最小场景 |
| --- | --- |
| 宽度 | 375、480、600、800、1024、1280、1440 |
| 字体 | 1.0、1.3、1.5 text scale |
| 内容 | 无 Case、无 due、1 项、同一学生 3 项、很多逾期、长中文 title |
| 输入 | touch、mouse hover/click、Tab/Shift+Tab、Enter/Space、滚轮、Android back |
| 状态 | loading、empty、error、no permission、saving、failed、offline/draft、reopened |
| 环境 | Android portrait/landscape、Windows 窄窗/宽窗 |

## 12. Flutter implementation rule

使用 `LayoutBuilder` / `MediaQuery.sizeOf` 读取空间，使用共享的 `ResponsiveBreakpoints` 选择布局。不要在 screen 里以 `Platform.isAndroid` 直接决定信息结构；平台信息只可作为输入能力或系统行为的补充条件。内容分栏必须由最小内容宽度和交互复杂度共同决定。
