class V2Student {
  const V2Student({
    required this.id,
    required this.name,
    required this.grade,
    required this.subjects,
    required this.openCaseCount,
    required this.updatedLabel,
    required this.teacherSummary,
  });

  final String id;
  final String name;
  final String grade;
  final List<String> subjects;
  final int openCaseCount;
  final String updatedLabel;
  final String teacherSummary;
}

class V2FocusItem {
  const V2FocusItem({
    required this.id,
    required this.studentId,
    required this.title,
    required this.summary,
    required this.nextStep,
    required this.dueLabel,
    required this.subject,
    this.pendingVerification = false,
  });

  final String id;
  final String studentId;
  final String title;
  final String summary;
  final String nextStep;
  final String dueLabel;
  final String subject;
  final bool pendingVerification;
}

class V2TimelineEntry {
  const V2TimelineEntry({
    required this.caseId,
    required this.date,
    required this.kind,
    required this.body,
    required this.teacher,
    required this.time,
    this.photoCount = 0,
  });

  final String caseId;
  final String date;
  final String kind;
  final String body;
  final String teacher;
  final String time;
  final int photoCount;
}

const v2Students = <V2Student>[
  V2Student(
    id: 'student-lin',
    name: '林同学',
    grade: '初三',
    subjects: ['语文', '数学'],
    openCaseCount: 2,
    updatedLabel: '今天更新',
    teacherSummary: '王老师负责语文 · 李老师负责数学',
  ),
  V2Student(
    id: 'student-wang',
    name: '王同学',
    grade: '初二',
    subjects: ['英语'],
    openCaseCount: 1,
    updatedLabel: '3 天前',
    teacherSummary: '陈老师负责英语',
  ),
  V2Student(
    id: 'student-chen',
    name: '陈同学',
    grade: '初三',
    subjects: ['数学'],
    openCaseCount: 1,
    updatedLabel: '5 天前',
    teacherSummary: '李老师负责数学',
  ),
  V2Student(
    id: 'student-li',
    name: '李同学',
    grade: '初一',
    subjects: ['语文'],
    openCaseCount: 0,
    updatedLabel: '1 周前',
    teacherSummary: '王老师负责语文',
  ),
  V2Student(
    id: 'student-zhou',
    name: '周同学',
    grade: '初二',
    subjects: ['物理', '化学'],
    openCaseCount: 2,
    updatedLabel: '1 天前',
    teacherSummary: '张老师负责物理 · 赵老师负责化学',
  ),
  V2Student(
    id: 'student-wu',
    name: '吴同学',
    grade: '初三',
    subjects: ['英语'],
    openCaseCount: 1,
    updatedLabel: '4 天前',
    teacherSummary: '陈老师负责英语',
  ),
];

const v2FocusItems = <V2FocusItem>[
  V2FocusItem(
    id: 'case-lin-reading',
    studentId: 'student-lin',
    title: '阅读概括不完整',
    summary: '能够定位关键词，但概括仍容易遗漏结果。',
    nextStep: '周四再检查同类题',
    dueLabel: '9 月 12 日',
    subject: '语文',
  ),
  V2FocusItem(
    id: 'case-lin-function',
    studentId: 'student-lin',
    title: '函数应用题思路不清',
    summary: '能够套公式，但不会根据题意建立关系。',
    nextStep: '再练 2 道同类题',
    dueLabel: '9 月 14 日',
    subject: '数学',
  ),
  V2FocusItem(
    id: 'case-wang-tense',
    studentId: 'student-wang',
    title: '时态切换不稳定',
    summary: '单句能判断时态，进入语篇后容易跟着局部提示词误判。',
    nextStep: '用一篇完形再检查',
    dueLabel: '9 月 13 日',
    subject: '英语',
  ),
  V2FocusItem(
    id: 'case-chen-geometry',
    studentId: 'student-chen',
    title: '几何辅助线缺少依据',
    summary: '能想到作辅助线，但常说不清为什么这样作。',
    nextStep: '口述 2 道证明题思路',
    dueLabel: '9 月 15 日',
    subject: '数学',
  ),
  V2FocusItem(
    id: 'case-zhou-force',
    studentId: 'student-zhou',
    title: '受力分析容易漏力',
    summary: '复杂情境中容易遗漏支持力或摩擦力。',
    nextStep: '先画受力图再列式',
    dueLabel: '9 月 12 日',
    subject: '物理',
    pendingVerification: true,
  ),
  V2FocusItem(
    id: 'case-zhou-equation',
    studentId: 'student-zhou',
    title: '化学方程式配平不稳',
    summary: '基础反应能完成，遇到系数稍复杂时容易反复试错。',
    nextStep: '集中练 5 组配平',
    dueLabel: '9 月 16 日',
    subject: '化学',
  ),
  V2FocusItem(
    id: 'case-wu-reading',
    studentId: 'student-wu',
    title: '长难句主干抓不准',
    summary: '词汇认识较多，但长句里容易被修饰成分带偏。',
    nextStep: '拆 3 个阅读长句',
    dueLabel: '9 月 14 日',
    subject: '英语',
  ),
];

List<V2FocusItem> v2FocusItemsForStudent(V2Student student) => v2FocusItems
    .where((item) => item.studentId == student.id)
    .toList(growable: false);

V2Student v2StudentForFocusItem(V2FocusItem item) =>
    v2Students.firstWhere((student) => student.id == item.studentId);

const v2Timeline = <V2TimelineEntry>[
  V2TimelineEntry(
    caseId: 'case-lin-reading',
    date: '今天',
    kind: '新表现',
    body: '已经会主动定位关键词，但最后一个要点仍然遗漏。下次再观察是否能够独立完成。',
    teacher: '王老师',
    time: '18:31',
    photoCount: 3,
  ),
  V2TimelineEntry(
    caseId: 'case-lin-reading',
    date: '9 月 8 日',
    kind: '检查结果',
    body: '本次练习正确率提高，仍有两个易错点。继续保持，增加易错字复习。',
    teacher: '王老师',
    time: '17:20',
  ),
  V2TimelineEntry(
    caseId: 'case-lin-reading',
    date: '9 月 5 日',
    kind: '教学处理',
    body: '重新讲解“对象 + 特征 + 结果”的概括结构，并做了两道同类题。',
    teacher: '王老师',
    time: '16:05',
  ),
  V2TimelineEntry(
    caseId: 'case-lin-reading',
    date: '9 月 3 日',
    kind: '发现问题',
    body: '阅读第三题概括遗漏两个关键点，需要提醒才发现。',
    teacher: '王老师',
    time: '15:40',
  ),
  V2TimelineEntry(
    caseId: 'case-lin-function',
    date: '今天',
    kind: '教学处理',
    body: '把题意中的数量关系先画成简图，再让学生自己写函数关系。',
    teacher: '李老师',
    time: '19:05',
    photoCount: 1,
  ),
  V2TimelineEntry(
    caseId: 'case-lin-function',
    date: '9 月 7 日',
    kind: '发现问题',
    body: '公式记得，但题目换一种问法后不知道应该先设哪个量。',
    teacher: '李老师',
    time: '18:10',
  ),
  V2TimelineEntry(
    caseId: 'case-wang-tense',
    date: '9 月 6 日',
    kind: '检查结果',
    body: '单句练习明显稳定，语篇中仍会被最近一个时间状语干扰。',
    teacher: '陈老师',
    time: '17:42',
  ),
  V2TimelineEntry(
    caseId: 'case-chen-geometry',
    date: '9 月 4 日',
    kind: '发现问题',
    body: '能画出辅助线，但解释时只能说“感觉这样更方便”。',
    teacher: '李老师',
    time: '18:22',
  ),
  V2TimelineEntry(
    caseId: 'case-zhou-force',
    date: '9 月 8 日',
    kind: '新表现',
    body: '开始主动先画受力图，但斜面题仍会漏掉摩擦力方向判断。',
    teacher: '张老师',
    time: '16:36',
  ),
  V2TimelineEntry(
    caseId: 'case-zhou-equation',
    date: '9 月 7 日',
    kind: '教学处理',
    body: '改用先固定复杂化学式整体、最后处理单质系数的方法。',
    teacher: '赵老师',
    time: '15:55',
  ),
  V2TimelineEntry(
    caseId: 'case-wu-reading',
    date: '9 月 5 日',
    kind: '发现问题',
    body: '阅读长句时逐词翻译，主谓结构容易被多个从句打断。',
    teacher: '陈老师',
    time: '17:18',
  ),
];

List<V2TimelineEntry> v2TimelineForStudent(V2Student student) {
  final caseIds = v2FocusItemsForStudent(student)
      .map((item) => item.id)
      .toSet();
  return v2Timeline
      .where((entry) => caseIds.contains(entry.caseId))
      .toList(growable: false);
}

List<V2TimelineEntry> v2TimelineForCase(V2FocusItem item) => v2Timeline
    .where((entry) => entry.caseId == item.id)
    .toList(growable: false);
