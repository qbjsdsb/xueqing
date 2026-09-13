# Xueqing Visual Foundation

状态：v0.3.x production visual baseline  
最后更新：2026-09-13

本文件把信息架构转成可实现的视觉语言。数值是起始 token，不是对每个页面的像素锁死；页面先遵循关系和优先级，再使用 token。

## 1. 视觉判断

Xueqing 采用低装饰、编辑部/专业工作台式的视觉秩序：中性画布、稳定工作面、清楚正文、低饱和语义色、细分隔线和少量边界明确的容器。

不使用大面积渐变、玻璃、glow、neon、AI 星星/魔法棒、巨大 KPI、环形/雷达图、彩色胶囊泛滥或每行一个 Card。阴影只服务于 modal/sheet 的层级，不服务于“显得高级”。应用同时提供浅色和深色 ColorScheme，由 `ThemeMode.system` 跟随系统；页面不直接读取固定语义色。

生产 V2 与应用外围必须共享同一套视觉事实源。`V2Theme` 只可作为兼容/组合边界存在，不能重新定义第二套 Palette、触控尺寸、圆角或暗色 surface。

一句话原则：

> **用排版建立关系，用留白建立层级，用颜色表达行动与状态；只有真的需要边界时才出现容器。**

## 2. Color tokens

### 2.1 基础色

| Token | 值 | 用途 | 说明 |
| --- | --- | --- | --- |
| `canvas` | `#F7F8F6` | 页面背景 | 让大面积页面不刺眼 |
| `surface` | `#FFFFFF` | 主要工作面、输入框 | 与 canvas 形成轻微层级 |
| `surfaceMuted` | `#EEF1EE` | 选中/辅助区、空状态底 | 不作为信息唯一表达 |
| `surfaceAccent` | `#E1ECE7` | 主要操作的淡背景、focus 辅助 | 低饱和绿色，不做渐变 |
| `textPrimary` | `#202824` | 标题、正文、学生姓名、Case title | 最高层级文字 |
| `textSecondary` | `#59635D` | metadata、辅助说明 | 仍需满足正文/metadata 的可读性 |
| `textDisabled` | `#87918B` | disabled 文字 | 不能承载唯一关键信息 |
| `border` | `#D5DDD7` | 分隔线、输入框边界 | 细而明确 |
| `borderStrong` | `#B7C2BB` | hover/selected/输入焦点外围 | 与普通 border 区分 |
| `accent` | `#2D6A5B` | primary action、链接、selected indicator | 稳定、克制的深青绿 |
| `accentStrong` | `#235448` | pressed/hover、深色按钮 | 仅用于交互反馈 |

正文颜色按 WCAG AA 4.5:1 普通文字基线检查；小号 metadata 不使用更浅的灰替代信息。颜色值仍需在真实平台字体和系统高对比度模式下复测。

### 2.2 深色 surface 规则

暗色模式不把“有层级”理解为“尽可能多种黑色”。生产界面以连续 canvas 为主，只在真实需要独立工作面、输入、dialog/sheet 时提升 surface。

当前共享暗色基线：

| 角色 | 值 | 使用原则 |
| --- | --- | --- |
| `surface / surfaceContainerLowest` | `#121412` | 页面、scope bar、主工作面尽量连续 |
| `surfaceContainerLow` | `#171A18` | 输入、轻微选中或局部需要边界的区域 |
| `surfaceContainer` | `#1B1E1C` | 少量辅助 surface |
| `surfaceContainerHigh` | `#222623` | dialog / popup 等临时任务层 |
| `surfaceContainerHighest` | `#2A2F2B` | disabled / 明确需要更高层次的状态 |

不得为了区分 AppBar、页面正文、底部导航、普通列表行而机械使用不同深色。它们属于同一空间时应使用同一 surface，通过分隔线、排版和间距表达结构。

绿色只承担交互、焦点、选中和少量语义状态，不承担大面积页面分区。selected indicator 优先使用低透明度 accent，而不是整块高饱和 `primaryContainer`。

### 2.3 语义状态色

| 状态 | foreground | background | 文字/结构冗余 |
| --- | --- | --- | --- |
| 今天到期 | `#7A591E` | `#F6EDDC` | 明确写“今天到期”，可配小日历图标 |
| 已逾期 | `#A44F4B` | `#F7E5E3` | 明确写“已逾期”，显示日期/补救动作 |
| 待验证 | `#3C6384` | `#E6EEF5` | 明确写“待验证”，显示“确认稳定/继续跟进” |
| 稳定 | `#2F6B4F` | `#E7F0EA` | 明确写“稳定”，仍显示 review/verify action |
| 已关闭 | `#59635D` | `#EEF1EE` | 明确写“已关闭”，提供“重新打开”入口 |
| 保存失败 | `#A44F4B` | `#F7E5E3` | 错误文字 + 重试，不只显示红色 |
| 离线草稿 | `#6B5A36` | `#F3EEDA` | 写明“本机草稿，未计入正式学情” |

状态色只标注状态，不给每个学科、Case 或标签分配一套颜色。相同状态在 Today、Student Detail、Case Detail 使用同一文字和语义。

## 3. Typography

### 3.1 字体策略

```text
Windows: system Chinese font → Microsoft YaHei → Noto Sans CJK SC
Android: system Chinese font → Noto Sans CJK SC → Microsoft YaHei
```

Flutter 通过 `fontFamilyFallback` 保留上述 fallback，不引入网络字体。英数字段与中文混排不得依赖英文 SaaS 字体的紧凑字宽。

### 3.2 类型层级

| Role | size / line height | weight | 使用场景 |
| --- | --- | --- | --- |
| Page title | 26 / 34 | 600 | Today、Student、Case 页面标题 |
| Page intro | 16 / 26 | 400 | 页面一句话任务说明 |
| Section title | 16 / 24 | 600 | 当前重点、待验证、最近记录 |
| Item title | 15 / 24 | 600 | 学生名、Case title、action title |
| Body | 15 / 24 | 400 | 证据、判断、干预、描述 |
| Body comfortable | 16 / 26 | 400 | Quick Capture、长文本阅读 |
| Metadata | 13 / 20 | 400/500 | 日期、学科、负责人、来源 |
| Label / button | 14 / 20 | 600 | 操作和字段标签 |
| Helper | 13 / 20 | 400 | 状态解释、失败恢复提示 |

核心信息最低不低于 13px；12px 只用于非关键的 fixture 标记或调试信息。姓名、Case title、状态和操作文本允许自然换行，不用省略号隐藏唯一关键信息。数字不作为视觉主角。

### 3.3 中文换行与密度

- Case title 默认最多自然展示三行；长文本继续滚动，操作区不被遮挡。
- 姓名与学科不强行在窄屏同一行；必要时让 metadata 换到下一行。
- 日期采用教师易读的中文文案，例如“今天到期”“9 月 3 日”，而不是只给 ISO 数字。
- 正文行高至少 1.5；系统字体放大时容器可增高，不用固定高度裁切。

## 4. Spacing

基础间距是 4 的倍数，页面常用关系如下：

| Token | px | 用途 |
| --- | ---: | --- |
| `xxs` | 4 | 图标与短标签、紧邻基线 |
| `xs` | 8 | 小组内间距 |
| `sm` | 12 | 行内间距、metadata 组 |
| `md` | 16 | 控件内边距、列表行上下文 |
| `mdPlus` | 20 | section 与主要分组的呼吸 |
| `lg` | 24 | section 间距、窄屏页面边距 |
| `xl` | 32 | 宽屏主要区块间距 |
| `xxl` | 40 | 页面 header 与主工作区之间 |
| `touchTarget` | 48 | Android 和触控布局的关键最小操作目标 |

页面不靠增加卡片数量制造层级；分组间距和分隔线应优先表达关系。

## 5. Border、radius、elevation

| 属性 | 基线 |
| --- | --- |
| 普通 border | 1px `border` |
| 强 border / focus 外围 | 1–2px `borderStrong` / `accent` |
| 紧凑控件 radius | 4px |
| 普通行/轻容器 radius | 8–12px |
| dialog/sheet radius | 单层、克制；按共享 `AppRadii` 与平台形态实现 |
| 默认 elevation | 0 |
| modal/sheet elevation | 低、单层，避免漂浮叠层 |

圆角不是信息分组的默认标记。列表行、timeline、section 默认用对齐和 divider；只有可独立操作的 surface 才使用轻容器。

## 6. Interaction states

| 状态 | 视觉变化 | 必须同时表达 |
| --- | --- | --- |
| default | 普通正文、细 border | 元素是什么 |
| hover | 轻微 surface 变化或 borderStrong | 鼠标当前所在位置，不改变布局 |
| focus | 2px accent ring，offset 2 | 键盘当前可操作元素 |
| pressed | accentStrong 或 surfaceAccent | 已经触发操作 |
| selected | 低透明度 accent + 字重/图标变化 | 当前导航/筛选位置，不能只靠色彩 |
| disabled | 降低对比度、不可点击光标 | 为什么不可操作若会造成疑惑 |
| loading | 原内容保留结构，局部 progress/label | 正在做什么，不跳动整页 |
| saving | 主按钮显示“保存中…”并暂时避免重复提交 | 输入仍保留 |
| save failed | 错误文字 + 重试/保留内容 | 用户下一步是什么 |

## 7. Surface 与信息层级规则

页面层级通常只使用：

1. canvas / base surface：全局页面和主要工作区。
2. subtle surface：输入、selected、真正需要独立边界的小区域。
3. modal/sheet：当前需要聚焦的短任务。

不使用透明玻璃、背景模糊、光晕或渐变。Today 的 action row、Student 的 case row、Case 的 timeline item 优先作为平面行存在；如果需要边界，使用 divider 和低对比度 surface。

机构管理尤其不得形成 `Area Card → Section → Empty Card` 的 Card 套 Card。默认使用“标题 / 说明 / divider / rows”组织，只有错误、危险操作和真正需要用户立即处理的 setup next step 可以拥有独立语义 surface。

Organization 学情同样不是 KPI dashboard。顶部事实、筛选和学生列表必须服务“哪里值得关注”，而不是通过彩色统计卡制造管理感。

## 8. Flutter token mapping

| 设计事实 | Flutter 落点 |
| --- | --- |
| color | `lib/app/theme/app_colors.dart` 的 `AppColors` + `AppTheme` 暗色角色 |
| spacing/radius/border | `lib/app/theme/app_spacing.dart` 的 `AppSpacing`、`AppRadii`、`AppBorders` |
| type/color scheme | `lib/app/theme/app_theme.dart` 的 `AppTheme.light()` / `AppTheme.dark()`；应用根使用 `ThemeMode.system` |
| V2 compatibility | `lib/features/design_v2/v2_theme.dart` 只从 `AppTheme` 派生，不建立第二套 palette |
| size class | `lib/app/layout/responsive.dart` 的 `ResponsiveBreakpoints` |
| focus/keyboard | Material controls + `FocusTraversalGroup` / `Shortcuts` |
| safe area/IME | `SafeArea` + `MediaQuery.viewInsetsOf` |
| semantics | `Semantics`、清楚的 button label、状态文字 |
| key touch target | `AppSpacing.touchTarget` + `AppTheme` 中的 button/icon constraints |

这些 token 服务于 prototype 和生产组件；不要在 feature 内另写一套颜色、间距或字体常量，除非先更新本文件并说明原因。

### 8.1 Adaptive workspace contract

生产工作区只使用共享 `ResponsiveBreakpoints` 定义结构尺寸，不允许 V2、机构页或弹窗再建立第二套结构断点。

| size class | 宽度 | Shell | 学生工作流 | modal |
| --- | --- | --- | --- | --- |
| Compact | `<600` | Bottom Navigation | 单栏逐级进入 | Bottom Sheet |
| Medium | `600–1023` | 72px Navigation Rail | 单栏逐级进入；内容按剩余 pane 宽度继续适配 | Dialog |
| Expanded | `>=1024` | Navigation Rail | Student master-detail，其余保持单主工作面 | Dialog |

`1280` 可以作为**内容密度阈值**，例如展开 rail 标签、稍微增加学生列表宽度；它不能决定“手机还是桌面”、Bottom Sheet/Dialog 或单栏/master-detail。类似地，feature 不得再用 `720`、`900` 等私有数字建立另一套结构语义。

嵌套页面必须按自己真实得到的 `BoxConstraints.maxWidth` 判断布局；只有 modal/sheet 这种针对整个应用窗口的呈现方式才使用 `ResponsiveBreakpoints.of(context)` / `isCompact(context)`。这样 Windows 窄窗口、平板分屏和 rail 后的内容区不会因为读取整窗宽度而误判。

Medium 的目标不是“把桌面版硬塞进小窗口”，也不是“放大手机版”：它保留键鼠高效的 rail，同时保持单工作面与逐级进入，直到 `>=1024` 才建立稳定 master-detail。

## 9. Production visual review gates

视觉验收不能只证明“控件存在”。每轮生产 UI 修改至少覆盖：

- 浅色 / 深色；
- Android compact 与 Windows medium/expanded；
- 0 个待办、少量待办、大量待办；
- 有学生但无最近活动；
- 机构中无异常、少量异常、大量 Case；
- 中文长标题与字体放大；
- hover / keyboard focus / 48dp touch target；
- empty、loading、error、saving、save failed；
- Personal / Organization scope 是否始终可辨，但不靠大片背景色区分。

CI 的 source/widget contract 用于防止交互和 token 回退；截图/golden 或真实设备视觉验收用于发现“CI 全绿但层级仍然难看”的问题，两者不能互相替代。

## Page Rhythm Contract

Top-level V2 workspaces share one editorial content-header grammar. Personal and Organization may expose different scope actions, but they should not look like different applications.

- Today / Student / Learning / Organization begin with the same title-context-action rhythm.
- Compact manager accounts do not add a permanent scope strip above Personal pages; Organization is a quiet header action while bottom navigation remains exactly Today / Student / Learning.
- Embedded Organization uses an in-content header rather than a nested AppBar. Its Learning / Management switch belongs to that header as a local section control.
- Compact embedded Organization exposes an explicit return-to-Personal affordance without changing system-back semantics.
- Embedded Organization Management does not repeat organization identity already owned by the parent header.
- Organization Learning and embedded Management align to the same centered content width and horizontal rhythm.

See `docs/design/PAGE_RHYTHM_AUDIT.md` for the audit and acceptance matrix.

## Organization Management Density Contract

Organization Management remains information-dense, but repeated records should read as a quiet work list rather than a stack of mini cards.

- repeated member / student / assignment rows use spacing and thin dividers instead of rounded filled containers;
- role and identity metadata stays neutral and compact;
- status may use a restrained semantic tint, but should not become a wall of Material Chips;
- setup guidance may emphasize the next step with a slim semantic edge, not a large primary-tinted block;
- local actions remain near the record they affect; visual reduction must not hide real operational capability.

See `docs/design/MANAGEMENT_DENSITY_AUDIT.md` for the audit boundary.
