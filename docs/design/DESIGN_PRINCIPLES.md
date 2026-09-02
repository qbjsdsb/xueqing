# Xueqing Design Principles

> Status: Phase 0A.5 working baseline. These principles may be refined by evidence during the design phase, but should not be silently contradicted by implementation.

## 1. 先看懂，再操作

界面第一职责是帮助教师快速理解当前状态和下一步，而不是展示系统“有多少数据”。

- 当前最重要的信息必须比历史信息更先出现；
- Primary action 必须比次要 metadata 更容易找到；
- 状态与行动必须用文字和结构表达，不能只靠颜色；
- 历史用于解释现在，不应淹没现在。

## 2. 闭环优先于模块

Xueqing 不是“学生表 + 课程表 + 问题表”的后台集合。

设计应持续强化：

`问题 → 证据 → 干预 → 验证 → 下一步`

同一事实尽量只记录一次，其他视图派生展示。

## 3. 记录新事实，不要求老师重抄

课中和课后只要求记录真正新增的信息。

- new case 目标 10–20 秒；
- 常规课后目标中位 ≤60 秒；
- 不要求教师重复填写能从上下文推导的数据；
- 不为报告、周报重新抄一次事实。

## 4. 当前行动必须清楚

正式未关闭 Case 的 pending primary action 是关键业务事实。

UI 必须让教师一眼看出：

- 下一步是什么；
- 谁负责；
- 何时处理（如有 due）；
- 是否逾期；
- 是干预、验证还是 review。

不得在视觉上把 action 降级成藏在详情页底部的辅助字段。

## 5. 证据与判断分开

Evidence、教师判断、Intervention、Assessment 是不同事实。

设计不得用一段混合文本把它们糊在一起，也不得让“验证通过”自动看起来等同于“Case 已稳定/关闭”。

## 6. 中文优先

设计从中文真实长度和信息密度出发。

- 不依赖英文短词才能成立；
- 重要信息不用极小灰字；
- 标题、辅助文字和 metadata 有明确层级；
- 长中文、数字、日期、学科名需要真实测试；
- Windows 和 Android 都要验证中文排版。

## 7. 专业工具感，不做展示型 AI 产品

Xueqing 的视觉应安静、克制、可信、耐看。

默认避免：

- 大面积渐变；
- 玻璃拟态；
- Glow / Neon；
- 大量阴影；
- 满屏 Card；
- 夸张圆角；
- 彩色胶囊泛滥；
- 驾驶舱式大数字；
- 无依据成长指数；
- AI 星星 / 魔法棒；
- “智能洞察 / 赋能 / 潜力”等营销式文案。

如果一个元素只是为了显得“现代”，但不提高理解、操作或判断效率，就删掉。

## 8. 结构优先于容器

信息分组优先使用：

1. typography；
2. spacing；
3. alignment；
4. subtle divider / background tone；
5. 最后才是 Card / shadow。

不要把每一行信息都放进独立圆角卡片。

## 9. 少量、稳定的颜色角色

颜色服务层级和语义，不服务装饰。

- surface hierarchy 保持中性；
- accent 只强调真正可操作或选中状态；
- success/warning/danger 使用克制；
- 关键状态必须同时有文字/图形线索；
- 不建立“每种 Case 状态一个高饱和颜色”的彩虹系统。

## 10. Windows 和 Android 不做简单缩放

共享产品语言，允许不同布局。

Windows：
- 扫视；
- 比较；
- 多信息并列；
- 编辑；
- 复盘；
- 键鼠效率。

Android：
- 搜索；
- 快速记录；
- 处理下一步；
- 单手触控；
- 键盘弹起；
- 弱网络与保存状态。

同一功能可以拥有平台差异化的布局和入口，只要业务语义一致。

## 11. 默认信息密度适中

Xueqing 是每天工作的工具，不是宣传页。

- Windows 不应浪费大面积空白；
- Android 不应把每个信息块做成巨大卡片；
- 关键任务保持视觉呼吸空间；
- 长列表需要可扫读；
- metadata 可以紧凑，但不可牺牲可读性。

## 12. 快速路径不被完整结构阻塞

课堂 quick capture 与课后 confirmed case 是两个不同阶段。

quick capture 只收最小必要信息；完整 taxonomy、证据确认、owner、primary action 等在正式确认时补齐。

UI 不得因为数据库最终结构复杂，就让课堂输入也复杂。

## 13. 状态反馈必须可信

保存状态至少区分：

- 未保存；
- 保存中；
- 已确认保存；
- 保存失败；
- 本地草稿 / 待同步（未来实现）。

不能用乐观动画把尚未被服务器确认的数据显示成正式“已保存”。

## 14. 弱状态也必须设计

每个核心页面都要考虑：

- empty；
- loading；
- error；
- disabled/no permission；
- saving；
- offline/draft；
- long content；
- multiple simultaneous cases/actions。

只画“数据刚刚好”的理想截图不算完成。

## 15. 不用 Dashboard 替代工作流

首页不是统计驾驶舱。

Today 应优先回答：

- 今天该做什么；
- 什么已经逾期；
- 什么等着验证；
- 什么还没安排日期；
- 哪些学生近期需要关注。

统计如果不能帮助今天的教学决策，应后置。

## 16. 不做伪精确

未经验证的方法不得展示为科学指标。

禁止用人为权重制造：

- 综合成长指数；
- 学情健康分；
- 学习潜力分；
- AI 风险概率。

优先展示可解释事实：次数、日期、case 状态、evidence、assessment、行动、趋势事件。

## 17. 可访问性不是收尾项

- 文本与背景对比足够；
- 状态不只依赖颜色；
- Windows focus 可见；
- Android touch target 足够；
- 系统字体放大后不崩；
- 重要按钮和错误提示可被清楚识别。

## 18. 设计必须能落到 Flutter

规范需要能映射到真实 token、layout 和 component。

不为效果图引入大量复杂第三方 UI 框架；优先 Flutter SDK / Material 基础能力上的克制定制。

设计稿如果无法解释响应式、长文本、hover/focus/pressed、error/loading/offline，只能算视觉草图，不算可实现规格。

## 19. 用真实任务评价设计

评审不问“好不好看”一个问题，而问：

- 新老师 30 秒能否看懂学生当前重点；
- 10–20 秒能否记录一个 new case；
- 是否能立刻找到当前 primary action；
- 是否能区分 Evidence 与判断；
- 是否能看出 assessment passed 但尚未 stable；
- Windows 能否高效扫视；
- Android 是否单手可用；
- 网络/保存异常是否不会让老师误判数据状态。

## 20. 审美服从长期使用

最终目标不是让截图在第一眼“惊艳”，而是让教师连续使用数周后仍觉得：

- 清楚；
- 快；
- 不累；
- 不烦；
- 找得到；
- 信得过。
