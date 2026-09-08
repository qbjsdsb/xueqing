from pathlib import Path

path = Path('docs/design/SCREEN_SPECS.md')
text = path.read_text(encoding='utf-8')

replacements = {
    '最后更新：2026-09-07': '最后更新：2026-09-09',
    '教师打开软件后，在约 30 秒内知道今天先处理什么、哪些已逾期、哪些在等待验证、哪些没有安排日期，以及可以直接完成什么。':
        '教师打开软件后，在约 30 秒内知道今天真正需要处理什么、哪些已逾期、哪些安排在以后、哪些提醒还没有日期。没有明确 Action 的观察记录、检查结果或继续关注状态，不因为“系统流程”自动变成 Today 任务。',
    '''1. 页面标题 `今日` + 一句工作说明。\n2. `overdue`：已逾期的普通 pending primary actions。\n3. `today`：今天到期的普通 pending primary actions。\n4. `pending verification`：等待教师确认的 Case 级入口，不进入普通 action queue。\n5. `future`：有明确未来日期的普通 actions，不进入“今天的工作”。\n6. `undated`：没有日期的普通 pending primary actions。\n7. 重点 Case（只有在它尚未被 action queue 覆盖时出现）。\n8. 最近学生和进入课程入口。\n\n每个 action/event 只能进入一个语义 bucket：`overdue`、`today`、`future`、`undated`；`pending verification` 是 Case 级 bucket，覆盖该 Case 的普通 action 入口。不能以“不是逾期/不是无日期”隐式推断 today。每个 bucket 内同一学生多个事项合并成一个学生簇：姓名只出现一次，最多直出三项，其余用“还有 N 项”；跨 bucket 不复制同一事件。''':
        '''1. 页面标题 `今日` + 一句工作说明。\n2. `overdue`：已逾期的 pending primary actions。\n3. `today`：今天到期的 pending primary actions。\n4. `future`：有明确未来日期的 pending primary actions，不进入“今天的工作”。\n5. `undated`：没有日期、但教师已经明确创建的 pending primary actions。\n6. 最近学生和进入学生上下文的入口。\n\nToday 的硬边界是“教师明确安排过的 Action”，不是“所有尚未 closed 的 Case”。`new` 且没有 Action 的快速记录、`pending_verification` 且没有 Action 的检查结果、普通 Evidence/Intervention/Assessment 都留在学生成长历史和问题详情中，不额外制造第二份待办。每个 Action 只能进入一个语义 bucket：`overdue`、`today`、`future`、`undated`；不能以“不是逾期/不是无日期”隐式推断 today。每个 bucket 内同一学生多个事项合并成一个学生簇：姓名只出现一次，最多直出三项，其余用“还有 N 项”；跨 bucket 不复制同一事项。''',
    '页面 primary action 是当前第一条最需要处理的 action 的具体动词，例如 `完成` 或 `补充证据`；`确认稳定`、`安排下一次检查`、`重新打开` 是 Case command 入口，不等同于普通 action completion。页面右上可有一个上下文动作 `记录问题`，但不能用“查看 Dashboard”替代工作动作。':
        '页面 primary action 是当前第一条明确 Action 的具体处理入口，例如 `处理`；进入后可记录本次进展，并按需决定是否提醒、结束跟进。没有明确 Action 的 Case 不因为状态名被提升为 Today 主任务。页面右上可有一个上下文动作 `记录问题`，但不能用“查看 Dashboard”替代工作动作。',
    '''\n待验证\n  示例学生甲 · 分数概念      本次验证通过，待确认是否稳定 [查看 Case]\n''': '\n',
    '| Many actions | 先按逾期/今天/待验证/未来/待安排分组，学生簇减少重复；提供“还有 N 项”，不横向塞满 |':
        '| Many actions | 先按逾期/今天/未来/待安排分组，学生簇减少重复；提供“还有 N 项”，不横向塞满 |',
    '不做统计图/大数字 KPI、彩色状态胶囊墙、重复学生卡、按日期筛选后隐藏无日期 action、把 pending verification 画成逾期、把 Today 变成普通 Todo App。':
        '不做统计图/大数字 KPI、彩色状态胶囊墙、重复学生卡、按日期筛选后隐藏无日期 action、把 Case 状态直接翻译成待办、把 Today 变成普通 Todo App。',
    '1. 有一个逾期 action、一个今天 action、一个待验证、一个未来 action、一个待安排 action：教师能在首屏分别说出五者含义和下一步，且未来 action 不出现在“今天的工作”。':
        '1. 有一个逾期 action、一个今天 action、一个没有 action 的继续关注 Case、一个未来 action、一个待安排 action：Today 只出现四条明确 Action；继续关注 Case 保留在学生历史，不制造额外待办。',
    '| Empty | 完全没有 Case：显示“还没有记录的问题。发现问题时，可以先记录一句，课后再整理。” + `记录问题` |':
        '| Empty | 完全没有 Case：显示“还没有记录的问题。发现问题时，可以先记下来。” + `记录问题` |',
    '| Draft | “待整理问题”可作为未关闭问题进入当前重点排序，明确尚未进入正式闭环 |':
        '| New record | 新记录可以作为未关闭问题进入当前重点排序；它已经是正式成长记录，不额外制造“待整理”任务 |',
    '课堂中用一只手在 10–20 秒内抓住一个新问题和一句关键表现，不因为完整 taxonomy 或长表单错过事实；课后再补充判断与方案。':
        '课堂中用一只手在 10–20 秒内留下一条足够具体的真实观察，不因为分类、附件、判断或行动计划错过事实；以后有新情况时继续记录，需要提醒时再提醒。',
    '''1. 学生 + 学科上下文（可确认、可更改）。\n2. 必填单行 `问题标题`。\n3. 必填一句 `具体表现`，只记录题目、行为或课堂中实际看到的事实。\n4. `问题类型` 使用已有默认值，只有教师当下确定时才调整；分类不得排在事实输入之前。\n5. 非阻塞相近 Case 提示。\n6. `记录问题` 保存；取消/稍后整理为次要动作。\n\n不在最短路径强制要求 taxonomy、根因、正式 owner、长篇 Evidence、手工填写 Next Action、due date 或附件。''':
        '''1. 学生 + 学科上下文；从学生详情进入时直接沿用，全局只有一个可选学生时自动选中。\n2. 唯一主输入 `今天发现什么？`，写下一条题目、行为或课堂中实际看到的事实。\n3. `更多选项`：问题类型、现场图片等只有需要时才展开。\n4. 非阻塞相近 Case 提示。\n5. `记录问题` 保存；取消为次要动作。\n\n主输入既作为首次事实，也由客户端从首句生成简短 Case title，避免教师把同一件事组织两遍。不在最短路径强制要求 taxonomy、根因、教师判断、完整方案、Next Action、due date 或附件。''',
    '`记录问题`。问题标题或具体表现为空时不提交；两句最小事实完整后保存进入 new/待整理语义。':
        '`记录问题`。主输入为空时不提交；一条具体事实即可保存为正式 `new` 记录。保存本身不创建 Action，也不进入 Today；是否提醒、继续记录或结束跟进由后续真实教学情况决定。',
    '`取消`、`稍后整理`、更改学生/学科、保存失败后的 `重试`、成功后的 `查看学生`。相近 Case 提示中的“仍然记录”是非阻塞选择，不是强制合并。':
        '`取消`、更改学生/学科、展开/收起 `更多选项`、保存失败后的 `重试`、成功后的 `查看学生`。相近 Case 提示中的“仍然记录”是非阻塞选择，不是强制合并。',
    '''记录问题                         [关闭]\n学生  示例学生甲 · 数学           [更改]\n\n问题标题 *\n[用一句话记下刚发现的问题       ]\n看起来已有相近的 Case……（可忽略）\n\n具体表现 *\n[题目、行为或课堂里实际看到的表现 ]\n\n问题类型（可调整）  [当前默认类型      v]\n\n[取消]                         [记录问题]''':
        '''记录问题                         [关闭]\n学生  示例学生甲 · 数学           [更改]\n\n今天发现什么？ *\n[写下刚才真实看到的题目、行为或表现……]\n看起来已有相近记录……（可忽略）\n\n[更多选项]\n  问题类型（可调整）\n  现场图片（可选）\n\n[取消]                         [记录问题]''',
    '| Loading | 学生/学科上下文加载时显示局部 loading；已经输入的 title 不清空 |':
        '| Loading | 学生/学科上下文加载时显示局部 loading；已经输入的主记录不清空 |',
    '| Saving | button 文案 `保存中…`，防重复点击；title/note 保留可见 |':
        '| Saving | button 文案 `保存中…`，防重复点击；主记录和已展开的可选内容保留可见 |',
    '| Long content | title/note 自然换行并可滚动；键盘打开时保存按钮仍可到达 |':
        '| Long content | 主记录自然换行并可滚动；键盘打开时保存按钮仍可到达 |',
    '| No due date | 快速记录不要求 due date；保存后由课后 formalize 安排 |':
        '| No due date | 快速记录不要求 due date；只有教师明确需要提醒时才创建/安排 Action |',
    '使用 `showModalBottomSheet` 或全屏 sheet，SafeArea + `MediaQuery.viewInsetsOf` 处理系统栏和 IME。已知上下文时打开后 focus 到 title；保存操作至少 48dp，单手可触达。内容区可滚动，键盘打开不遮住保存。':
        '使用 `showModalBottomSheet` 或全屏 sheet，SafeArea + `MediaQuery.viewInsetsOf` 处理系统栏和 IME。已知上下文时打开后 focus 到主记录输入；保存操作至少 48dp，单手可触达。内容区可滚动，键盘打开不遮住保存。',
    'title 输入时允许 Enter 完成（note 未展开/单行语境）；note 多行时使用 Ctrl+Enter 保存。Tab 顺序为 Student/Subject → title → note → type → 保存 → 取消。Esc/back：先收键盘，再按脏状态确认。全局快捷键不抢文本输入。':
        '主记录输入支持多行；Windows 可用 Ctrl+Enter 保存。Tab 顺序为 Student/Subject（若需要选择）→ 主记录 → 更多选项（若展开）→ 保存 → 取消。Esc/back：先收键盘，再按脏状态确认。全局快捷键不抢文本输入。',
    '学生/学科选择、标题、note、保存、取消均有至少 48dp 的可操作面积；相近 Case 提示不采用容易误触的全屏点击。保存防双击，失败时重试仍使用原内容。':
        '学生/学科选择、主记录、更多选项、保存、取消均有至少 48dp 的可操作面积；相近 Case 提示不采用容易误触的全屏点击。保存防双击，失败时重试仍使用原内容。',
    '1. 已知学生/学科：点击记录问题后写一句标题和一句具体表现即可保存，目标仍为 10–20 秒。':
        '1. 已知学生/学科：点击记录问题后只写一条具体观察即可保存，目标仍为 10–20 秒。',
    '| 30 秒课前理解 | 逾期/今天/待验证/未来/待安排 | 三件事 + 最近事实 | 当前 status + Next Action | 不参与 |':
        '| 30 秒课前理解 | 逾期/今天/未来/待安排 | 三件事 + 最近事实 | 当前 status + 按需 Next Action | 不参与 |',
    '| 60 秒课后闭环 | 完成/进入上下文 | 从学生理解 Case | 补证据/动作/验证 | 稍后整理 |':
        '| 60 秒课后跟进 | 处理明确提醒/进入上下文 | 从学生理解 Case | 继续记录/提醒/结束 | 无强制整理 |',
    '| 语义正确 | Action queue | 当前学生上下文 | 六段证据叙事 | new/待整理 |':
        '| 语义正确 | 只有明确 Action 进入队列 | 当前学生上下文 | 结构化成长历史 | new 正式记录、无默认 Action |',
}

for old, new in replacements.items():
    if old not in text:
        raise SystemExit(f'missing expected text: {old[:120]!r}')
    text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8')
