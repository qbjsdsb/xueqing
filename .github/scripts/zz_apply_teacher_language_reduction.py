from pathlib import Path


def replace_exact(text: str, old: str, new: str, *, expected: int = 1, label: str) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{label} anchor drifted: expected {expected}, got {count}')
    return text.replace(old, new)


# Production presentation copy only. Domain behavior remains unchanged.
source_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
source = source_path.read_text()

replacements = [
    (
        "              title: '工作台初始化失败',\n              message: '请检查开发环境配置后重试。',",
        "              title: '工作台暂时无法打开',\n              message: '请检查网络后重试；已经保存的学情记录不会受影响。',",
        1,
        'workspace initialization copy',
    ),
    (
        "          title: '机构管理尚未接通',\n          message: '当前账号有机构管理角色，但管理数据服务没有配置。请检查应用初始化和开发环境同步状态。',",
        "          title: '管理功能暂时不可用',\n          message: '当前账号具有管理权限，但管理页面暂时无法打开。请退出后重新登录；如果持续出现，请联系机构负责人。',",
        1,
        'management fallback copy',
    ),
    (
        "    return '开发环境服务还没有完成同步，请稍后重试。';",
        "    return '服务正在更新，暂时无法读取工作台。请稍后重试。';",
        1,
        'schema drift user copy',
    ),
    (
        "            message: 'Assessment passed 不是 stable。请保留这次检查记录，再由教师确认是否稳定。',",
        "            message: '本次检查已经通过，还需要你确认这个问题是否已经稳定。',",
        1,
        'pending verification copy',
    ),
    (
        "            message: '稳定不等于已关闭，当前仍需保留 review / verify action。',",
        "            message: '当前表现已经稳定，但还没有结束跟进；请保留下一次复查。',",
        1,
        'stable copy',
    ),
    (
        "            title: '待整理 Case',\n            message: 'Quick Capture 已保存原始问题和证据；确认前请补充判断和合适的下一步。',",
        "            title: '待整理问题',\n            message: '这是一条课堂快速记录；确认前请补充教师判断和合适的下一步。',",
        1,
        'new case copy',
    ),
    (
        "            message: '只有关闭后的新 Evidence 才能重新打开；系统会保留原来的关闭历史。',",
        "            message: '关闭后如果再次出现新的表现，可以记录后重新打开；原来的关闭历史会继续保留。',",
        1,
        'reopen copy',
    ),
    (
        "                  message: '新的 Evidence、教学动作和验证会按时间追加在这里。',",
        "                  message: '新的课堂记录、教学动作和检查结果会按时间追加在这里。',",
        1,
        'timeline empty copy',
    ),
    (
        "                    '先记录一条真实观察；保存后 Case 会保持“待整理”，不会自动跳过教师判断。',",
        "                    '先记下刚看到的问题和具体表现，课后再补充判断与跟进。',",
        1,
        'quick capture intro',
    ),
    (
        "                      labelText: '现场表现 / Evidence *',",
        "                      labelText: '具体表现 *',",
        1,
        'quick capture evidence label',
    ),
    (
        "                      hintText: '记下题目、行为或课堂中可观察到的表现',",
        "                      hintText: '写下题目、行为或课堂里实际看到的表现',",
        1,
        'quick capture evidence hint',
    ),
    (
        "                    '保存后会生成一条 finalized Evidence；错误需要用后续修正事实表达，不会静默覆盖原记录。',",
        "                    '这段记录会作为问题依据保留；之后可以继续补充，不会覆盖原记录。',",
        1,
        'quick capture evidence helper',
    ),
    (
        "                        '待整理 Case · ${_selectedCaseType.label} · 下一步“补充证据并确认下一步” · 日期待安排',",
        "                        '待整理问题 · ${_selectedCaseType.label} · 之后补充判断并安排跟进',",
        1,
        'quick capture saved-state preview',
    ),
    (
        "                          child: Text(_saving ? '保存中…' : '保存问题'),",
        "                          child: Text(_saving ? '保存中…' : '记录问题'),",
        1,
        'quick capture primary button',
    ),
    (
        "            '照片只作为 Evidence 的补充；请保留一句文字说明，便于搜索和复盘。',",
        "            '可以补一张题目、作业或课堂照片；仍建议写一句文字，之后更容易查找。',",
        1,
        'quick capture attachment helper',
    ),
    (
        "        .showSnackBar(const SnackBar(content: Text('已保存为待整理 Case，并保留下一步行动。')));",
        "        .showSnackBar(const SnackBar(content: Text('已记录为待整理问题。')));",
        1,
        'quick capture success copy',
    ),
    (
        "                    '日期按机构时区解释；提交失败时输入会保留，重试沿用同一 operation ID。',",
        "                    '日期按机构时区计算；提交失败时输入会保留，直接重试即可，不会重复记录。',",
        1,
        'retry helper unlocked',
    ),
    (
        "                    '日期按机构时区解释；提交失败时原始内容会锁定，重试沿用同一 operation ID。',",
        "                    '日期按机构时区计算；提交失败时本次内容会保留，直接重试即可，不会重复记录。',",
        1,
        'retry helper locked',
    ),
]
for old, new, expected, label in replacements:
    source = replace_exact(source, old, new, expected=expected, label=label)
source_path.write_text(source)

# Widget-test expectations follow the intentional teacher-facing copy change.
test_path = Path('test/features/teacher_workspace_test.dart')
tests = test_path.read_text()
test_replacements = [
    ("expect(find.text('待整理 Case'), findsOneWidget);", "expect(find.text('待整理问题'), findsOneWidget);", 1, 'new case test'),
    ("expect(find.text('现场表现 / Evidence *'), findsOneWidget);", "expect(find.text('具体表现 *'), findsOneWidget);", 1, 'quick capture label test'),
    ("find.widgetWithText(FilledButton, '保存问题')", "find.widgetWithText(FilledButton, '记录问题')", 2, 'quick capture button tests'),
    ("expect(find.text('已保存为待整理 Case，并保留下一步行动。'), findsOneWidget);", "expect(find.text('已记录为待整理问题。'), findsOneWidget);", 1, 'quick capture success test'),
    ("expect(find.text('开发环境服务还没有完成同步，请稍后重试。'), findsOneWidget);", "expect(find.text('服务正在更新，暂时无法读取工作台。请稍后重试。'), findsOneWidget);", 1, 'schema copy test'),
    ("expect(find.text('机构管理尚未接通'), findsOneWidget);", "expect(find.text('管理功能暂时不可用'), findsOneWidget);", 1, 'management fallback test'),
]
for old, new, expected, label in test_replacements:
    tests = replace_exact(tests, old, new, expected=expected, label=label)
test_path.write_text(tests)

# Accepted copy contract: keep implementation and UX_COPY aligned.
ux_path = Path('docs/design/UX_COPY.md')
ux = ux_path.read_text()
ux = replace_exact(
    ux,
    "| optional note | `补充说明（可选）` |\n| note placeholder | `记下关键表现、题目或课堂语境` |",
    "| 具体表现 | `具体表现` |\n| 具体表现 placeholder | `写下题目、行为或课堂里实际看到的表现` |",
    label='UX copy quick capture fields',
)
ux = replace_exact(
    ux,
    "| discard | `放弃记录` |\n\n## 4. State copy rules",
    "| discard | `放弃记录` |\n\n当前 V1 的课堂快速记录最小输入为：`问题标题 + 一句具体表现`。具体表现用于保留可复核的教学事实，但不要求课堂现场填写根因、教师判断、完整干预方案、行动日期或长篇 Evidence。\n\n## 4. State copy rules",
    label='UX copy quick capture rule',
)
ux_path.write_text(ux)

# Screen spec: reflect the real minimum safe Quick Capture contract.
spec_path = Path('docs/design/SCREEN_SPECS.md')
spec = spec_path.read_text()
spec_replacements = [
    (
        "课堂中用一只手在 10–20 秒内抓住一个新问题，不因为完整 taxonomy 或长表单错过事实；课后再 formalize。",
        "课堂中用一只手在 10–20 秒内抓住一个新问题和一句关键表现，不因为完整 taxonomy 或长表单错过事实；课后再补充判断与方案。",
        'screen quick capture goal',
    ),
    (
        "2. 必填单行 `问题标题`。\n3. 可选 `补充说明`。\n4. 非阻塞相近 Case 提示。\n5. `记录问题` 保存；取消/稍后整理为次要动作。\n\n不在最短路径强制要求 taxonomy、根因、正式 owner、完整 Evidence、Next Action、due date、附件。",
        "2. 必填单行 `问题标题`。\n3. 必填一句 `具体表现`，只记录题目、行为或课堂中实际看到的事实。\n4. 非阻塞相近 Case 提示。\n5. `记录问题` 保存；取消/稍后整理为次要动作。\n\n不在最短路径强制要求 taxonomy、根因、正式 owner、长篇 Evidence、手工填写 Next Action、due date 或附件。",
        'screen quick capture priority',
    ),
    (
        "`记录问题`。标题为空时不提交，说明“请先写下问题标题”；标题有内容时保存进入 new/待整理语义。",
        "`记录问题`。问题标题或具体表现为空时不提交；两句最小事实完整后保存进入 new/待整理语义。",
        'screen quick capture action',
    ),
    (
        "补充说明（可选）\n[关键表现、题目或课堂语境       ]",
        "具体表现 *\n[题目、行为或课堂里实际看到的表现 ]",
        'screen quick capture layout',
    ),
    (
        "1. 已知学生/学科：点击记录问题后只写一句标题即可保存，目标 10–20 秒。",
        "1. 已知学生/学科：点击记录问题后写一句标题和一句具体表现即可保存，目标仍为 10–20 秒。",
        'screen quick capture acceptance',
    ),
]
for old, new, label in spec_replacements:
    spec = replace_exact(spec, old, new, label=label)
spec_path.write_text(spec)

components_path = Path('docs/design/COMPONENTS.md')
components = components_path.read_text()
components = replace_exact(
    components,
    "最小结构：已知 Student/Subject 上下文 → 问题标题 → 可选补充 → `记录问题`。重复提示放在标题下方作为非阻塞 helper；保存后反馈为“已记录为待整理问题”，不强迫立即填写完整 taxonomy。",
    "最小结构：已知 Student/Subject 上下文 → 问题标题 → 一句具体表现 → `记录问题`。具体表现只要求可观察事实；重复提示保持非阻塞，保存后反馈为“已记录为待整理问题”，不强迫立即填写 taxonomy、根因、完整方案或日期。",
    label='components quick capture contract',
)
components_path.write_text(components)

product_path = Path('docs/PRODUCT.md')
product = product_path.read_text()
product = replace_exact(
    product,
    "目标仍是课堂 10–20 秒：student/subject → 一句标题 → optional detail → new Case。\n\n但“快”不等于绕过权限：云端 new Case 必须完整 Teaching Fact Gate。",
    "目标仍是课堂 10–20 秒：student/subject → 一句标题 → 一句具体表现 → new Case。\n\n当前 V1 用“一句具体表现”守住最小事实依据，但不要求课堂现场填写根因、判断、完整干预方案或日期。\n\n但“快”不等于绕过权限：云端 new Case 必须完整 Teaching Fact Gate。",
    label='product quick capture contract',
)
product_path.write_text(product)

for path_str, old, new, label in [
    ('docs/USER_FLOWS.md', '→ optional detail', '→ 一句具体表现', 'user flow quick capture'),
    ('docs/product/CASE_WORKFLOW_TEMPLATES.md', '→ optional detail', '→ 一句具体表现', 'case template quick capture'),
    ('docs/product/INITIAL_DIAGNOSIS_WORKFLOW.md', '→ optional detail/evidence', '→ 一句具体表现', 'initial diagnosis quick capture'),
]:
    path = Path(path_str)
    text = path.read_text()
    text = replace_exact(text, old, new, label=label)
    path.write_text(text)
