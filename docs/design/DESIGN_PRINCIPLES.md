# Xueqing UX/UI Design Principles

状态：Phase 0A.5 foundation baseline

最后更新：2026-09-02

这份文档只定义设计原则与语义边界。信息架构、视觉 token、响应式规则、组件和 screen spec 分别见同目录的对应事实源，避免同一规则在多份文档中漂移。

## 1. 北极星

教师打开软件后，应能快速回答两件事：

1. 这个学生下一步做什么？
2. 上一次教学是否有效，有什么证据？

因此每个核心页面的默认顺序是：当前重点 → 可执行的下一行动 → 支撑判断的最近事实 → 必要历史。历史用于解释现在，不是默认要读完的档案库。

## 2. 设计决策的证据等级

文档中的决策使用以下标签。标签表示依据强度，不表示视觉质量高低。

| 标签 | 含义 | 设计约束 |
| --- | --- | --- |
| Foundation requirement | `PRODUCT.md`、`USER_FLOWS.md`、`COMMANDS_AND_INVARIANTS.md` 等已冻结的产品事实 | 不得被视觉偏好覆盖 |
| Official platform guidance | Flutter、Android、Windows、WCAG 官方指导 | 用来决定适配、输入、焦点、触控和无障碍 |
| Observed mature-product pattern | 对成熟知识工作软件的公开帮助文档/产品模式观察 | 只借鉴解决的问题，不照搬品牌外观 |
| Xueqing product judgment | 为教师闭环做出的产品判断 | 必须能解释对教师任务的帮助 |
| Visual preference | 颜色、字重、表面气质等可调整偏好 | 不能改变信息优先级或业务语义 |

发生冲突时，优先级为：Foundation requirement → 平台可用性/无障碍 → Xueqing product judgment → visual preference。

## 3. 一条闭环，一套语义

Xueqing 的核心关系必须在 UI 中保持可追溯：

`学生档案 → 发现问题 → Evidence → Intervention → Assessment / Verification → Stable / 继续跟进 → Next Action`

Learning Case status 只能沿用 Foundation 生命周期：`new → confirmed → intervening → pending_verification → stable → closed`。`reopen` 是 command/event/timeline fact，用来保留历史连续性，不是第七个 status。

- Evidence 是可观察事实、作品、回答、错误、课堂表现或附件引用；不等于教师解释。
- 教师判断说明如何理解 Evidence；不能把判断伪装成客观事实。
- Intervention 是已经采取或计划采取的教学动作。
- Assessment / Verification 记录某次检查的结果；“通过”只描述这次检查，不自动把 Case 变成 stable。
- stable 仍须有 review / verify action；stable 不等于 closed。
- closed 表示没有待完成的主要行动；reopen 是保留历史连续性的事件，不覆盖旧记录。
- Case status 与 action status 是两个不同对象；页面文案和颜色都不能把它们混成一个状态。

## 4. 信息优先于容器

默认用标题、行高、留白、对齐和分隔线组织信息，最后才使用 Card。只有当一组内容需要独立操作、形成明确边界或与页面背景有真实层级差时才使用容器。

禁止把每一行包成圆角 Card，也禁止出现 Card inside Card 的递归层级。一个页面的 surface 层级通常不超过：canvas、surface、modal/sheet。

## 5. 真实工作软件气质

视觉方向是克制、安静、专业、可信、耐看、中文友好、适度信息密度。可以有少量教学场景的温度，但不做幼态和卡通化。整体借鉴编辑部、工具书、专业工作台的秩序感，不复制任何品牌。

如果元素只是为了显得高级、科技或现代，却没有提高教师理解、操作或判断效率，就删除它。

## 6. Today 不是 Dashboard

Today 是教师当天的工作队列，不是统计页。首屏按互斥语义组织：`overdue`、`today`、`pending verification`、`future`、`undated`，再提供重点 Case、最近学生和进入课堂的动作。

- 逾期表达“需要补救”，待验证表达“等待判断”；两者不使用同一套文案。
- `future` 由明确未来 due date/bucket 决定，不能用“不是逾期且不是无日期”推断为 today；pending verification 的 Case 级入口不重复进入普通 action queue。
- 无日期行动进入明确的“待安排”，不能因为没有日期而从列表消失。
- 同一学生的多个事项以学生为视觉锚点合并，避免重复轰炸；具体动作仍可逐条完成。
- 直接可完成的动作留在 Today；需要理解上下文的判断进入 Student Detail 或 Learning Case。

## 7. Student Detail 先解释现在

学生详情首屏必须让第一次接手的教师在不翻完整历史的情况下回答“现在最重要的三件事”。首屏至少包含当前重点、当前 Learning Cases、待验证、Next Action、最近关键事实、学科上下文和必要身份信息。

历史按时间线或折叠区呈现，用来解释当前判断。禁止把学生做成几十个字段的档案表，也禁止用成长指数、风险概率、标签云或四个统计 Card 代替理解。

## 8. Learning Case 是可追溯叙事

Learning Case 不是巨大表单，而是一条可逐步补全的解释链：

`问题 → Evidence → 教师判断 → Intervention → Assessment / Verification → Next Action`

课堂中只需要完成当下的最小记录；课后再 formalize 缺失的 taxonomy、根因、owner、evidence、action 和日期。当前状态与下一行动必须始终可见，历史 timeline 解释状态如何来到这里。

## 9. Quick Capture 以低负担为性能指标

已知学生和学科时，最短路径是：输入一句问题标题 → 可选补充 → 保存，目标 10–20 秒。课堂阶段不强迫完整 taxonomy、根因、正式 owner、完整 Evidence、下一行动、due date 或附件。

重复提示只能是非阻塞提醒；网络失败要保留输入；保存成功、保存中、失败、离线草稿都必须有清楚状态。Quick Capture 是“先抓住事实，稍后整理”，不是把完整 Case 表单压缩到手机上。

## 10. Windows 与 Android 是同一语言、不同重心

适配依据是 available window size、内容需求、输入方式和交互复杂度，不是静态 `Platform.isAndroid` 分支。

- Windows：看全貌、扫视、比较、编辑、复盘；支持 hover、visible focus、Tab、键盘激活、鼠标、滚轮、resize，宽窗口不让内容无限拉宽。
- Android：搜索学生、快速记录、查看/完成下一行动、课堂操作、课后补充；支持 SafeArea、触控、软键盘、返回、误触保护、系统字体放大、saving/save failed/local draft/offline/reconnect。
- 同一信息的语义和状态名称一致，布局密度、入口和交互成本可以不同。

## 11. 状态是内容，不是装饰

核心流程的每个可变状态都要能在不看颜色的情况下理解：loading、empty、error、no permission、saving、save failed、offline、draft、long content、many items、closed，以及带有 reopen event 的重新打开历史。

状态至少用文字或结构表达，颜色只做辅助。核心信息不得依赖极小浅灰文字。错误说明下一步，草稿说明是否计入正式学情，权限说明可查看和可操作的边界。

## 12. 中文排版优先于英文 SaaS 习惯

标题、姓名、学科名、日期、状态和长 Case title 按真实中文阅读来设计。优先保证 15–16px 的正文可读性、明确行高、可自然换行和稳定的多行操作布局；不因追求一行塞满而压缩中文。

Windows 使用系统中文字体并保留 Microsoft YaHei fallback；Android 使用系统 CJK 字体并保留 Noto Sans CJK SC fallback。字体缩放后，操作不能被截断或遮挡。

## 13. 可访问、可输入、可恢复

- 文字对比度满足 WCAG AA 基线；状态不只靠色相。
- 只有真正可操作的元素进入 focus；Tab 顺序按视觉阅读顺序；Windows focus 可见。
- Android 关键触控目标至少 48dp；操作之间有足够间隔。
- 鼠标、键盘、触控都能完成核心任务；滚轮能滚动长列表。
- 有未保存内容时，关闭、返回和切换上下文要有保护；失败时保留用户输入。
- 隐私/权限状态显式但克制，不泄露不应看到的学生细节。

## 14. Flutter 落地边界

Phase 0A.5 的 prototype 只验证设计事实：layout、tokens、components、states、quick capture 和平台输入差异。fixture 必须集中、明显虚构、数量最小；不接 repository、Supabase、Auth、真实 CRUD、Realtime、AI API 或真实学生数据。

推荐使用 Flutter SDK / Material 现有能力：`LayoutBuilder`、`MediaQuery.sizeOf`、`SafeArea`、`Scaffold`、`NavigationBar`、`FocusTraversalGroup`、`Shortcuts`、`TextField`、`Semantics`。自定义组件只有在有真实 screen 使用场景时才增加。

## 15. 完成判定

四个核心流程都必须能回答：教师看到什么、为什么先看到、下一步是什么、如何操作、失败怎么办、Windows 怎么工作、Android 怎么工作、权限如何体现、长文本怎么办、无数据怎么办、网络失败怎么办。

如果设计只能展示理想状态或漂亮截图，Phase 0A.5 不算完成。
