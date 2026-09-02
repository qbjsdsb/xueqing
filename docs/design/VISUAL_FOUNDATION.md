# Xueqing Visual Foundation

状态：Phase 0A.5 visual baseline

最后更新：2026-09-02

本文件把信息架构转成可实现的视觉语言。数值是起始 token，不是对每个页面的像素锁死；页面先遵循关系和优先级，再使用 token。

## 1. 视觉判断

Xueqing 采用浅色、低装饰、编辑部/专业工作台式的视觉秩序：中性画布、白色工作面、深色正文、低饱和语义色、细分隔线和少量边界明确的容器。

不使用大面积渐变、玻璃、glow、neon、AI 星星/魔法棒、巨大 KPI、环形/雷达图、彩色胶囊泛滥或每行一个 Card。阴影只服务于 modal/sheet 的层级，不服务于“显得高级”。

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

### 2.2 语义状态色

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

Flutter 先通过 `fontFamilyFallback` 保留上述 fallback，不在 Phase 0A.5 引入网络字体。英数字段与中文混排不得依赖英文 SaaS 字体的紧凑字宽。

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

页面不靠增加卡片数量制造层级；分组间距和分隔线应优先表达关系。

## 5. Border、radius、elevation

| 属性 | 基线 |
| --- | --- |
| 普通 border | 1px `border` |
| 强 border / focus 外围 | 1–2px `borderStrong` / `accent` |
| 紧凑控件 radius | 4px |
| 普通行/轻容器 radius | 8px |
| dialog/sheet radius | 12px，仅顶部或外框 |
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
| selected | 淡背景 + 3px selected indicator / 字重 | 当前导航/筛选位置，不能只靠色彩 |
| disabled | 降低对比度、不可点击光标 | 为什么不可操作若会造成疑惑 |
| loading | 原内容保留结构，局部 progress/label | 正在做什么，不跳动整页 |
| saving | 主按钮显示“保存中…”并暂时避免重复提交 | 输入仍保留 |
| save failed | 错误文字 + 重试/保留内容 | 用户下一步是什么 |

## 7. Surface 规则

页面层级最多使用三层：

1. canvas：全局背景。
2. surface：工作内容和输入。
3. modal/sheet：当前需要聚焦的短任务。

不使用透明玻璃、背景模糊、光晕或渐变。Today 的 action row、Student 的 case row、Case 的 timeline item 优先作为平面行存在；如果需要边界，使用 divider 和低对比度 surface。

## 8. Flutter token mapping

| 设计事实 | Flutter 落点 |
| --- | --- |
| color | `lib/app/theme/app_colors.dart` 的 `AppColors` |
| spacing/radius/border | `lib/app/theme/app_spacing.dart` 的 `AppSpacing`、`AppRadii`、`AppBorders` |
| type/color scheme | `lib/app/theme/app_theme.dart` 的 `AppTheme.light()` |
| size class | `lib/app/layout/responsive.dart` 的 `ResponsiveBreakpoints` |
| focus/keyboard | Material controls + `FocusTraversalGroup` / `Shortcuts` |
| safe area/IME | `SafeArea` + `MediaQuery.viewInsetsOf` |
| semantics | `Semantics`、清楚的 button label、状态文字 |

这些 token 服务于 prototype 和后续生产组件；不要在 feature 内另写一套颜色、间距或字体常量，除非先更新本文件并说明原因。

## 9. Phase 0A theme audit

| 现有基础 | 判断 | Phase 0A.5 处理 |
| --- | --- | --- |
| `AppColors` 的中性画布、深色正文、青绿色 accent | 值得保留的方向，与产品关键词一致 | 保留色相关系；补充 surface、focus、borderStrong、info 和语义背景，降低把颜色当装饰分类的风险 |
| 原 `surface` 同时承担页面背景和工作面 | 命名/层级不足 | 分成 `canvas` 与 `surface`；页面背景使用 canvas，工作面使用白色 surface |
| 4/8/12/16/24/32 间距骨架 | 值得保留 | 增加 20/40 供中文长内容和页面呼吸；不在 feature 内另建间距 |
| 6/10/12 radius | 可用但偏向 bootstrap | 收敛常用 radius 到 4/8/12 关系，保留小号 6 以兼容既有 bootstrap；不大面积使用圆角 |
| Microsoft YaHei / Noto Sans CJK SC fallback | 只是工程占位，不等于完成中文排版 | 按中文真实层级调整字号/行高；保留 fallback，后续在目标设备复测系统字体 |
| Material 3 seed color / CardTheme | 可作为 Flutter 基线 | 覆盖 surface、outline、button、input、navigation 状态；原型优先使用 rows/dividers，Card 不作为默认分组 |
| expanded rail、compact/mobile AppBar | 结构起点 | 补上 medium compact rail，并在设计 prototype 中验证 expanded/medium/compact 三种关系 |
