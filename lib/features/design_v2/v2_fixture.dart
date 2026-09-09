class V2Student {
  const V2Student({
    required this.id,
    required this.name,
    required this.grade,
    required this.subjects,
    required this.openCaseCount,
    required this.updatedLabel,
  });

  final String id;
  final String name;
  final String grade;
  final List<String> subjects;
  final int openCaseCount;
  final String updatedLabel;
}

class V2FocusItem {
  const V2FocusItem({
    required this.title,
    required this.summary,
    required this.nextStep,
    required this.dueLabel,
    required this.subject,
  });

  final String title;
  final String summary;
  final String nextStep;
  final String dueLabel;
  final String subject;
}

class V2TimelineEntry {
  const V2TimelineEntry({
    required this.date,
    required this.kind,
    required this.body,
    required this.teacher,
    required this.time,
    this.photoCount = 0,
  });

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
  ),
  V2Student(
    id: 'student-wang',
    name: '王同学',
    grade: '初二',
    subjects: ['英语'],
    openCaseCount: 1,
    updatedLabel: '3 天前',
  ),
  V2Student(
    id: 'student-chen',
    name: '陈同学',
    grade: '初三',
    subjects: ['数学'],
    openCaseCount: 1,
    updatedLabel: '5 天前',
  ),
  V2Student(
    id: 'student-li',
    name: '李同学',
    grade: '初一',
    subjects: ['语文'],
    openCaseCount: 0,
    updatedLabel: '1 周前',
  ),
  V2Student(
    id: 'student-zhou',
    name: '周同学',
    grade: '初二',
    subjects: ['物理', '化学'],
    openCaseCount: 2,
    updatedLabel: '1 天前',
  ),
  V2Student(
    id: 'student-wu',
    name: '吴同学',
    grade: '初三',
    subjects: ['英语'],
    openCaseCount: 1,
    updatedLabel: '4 天前',
  ),
];

const v2FocusItems = <V2FocusItem>[
  V2FocusItem(
    title: '阅读概括不完整',
    summary: '能够定位关键词，但概括仍容易遗漏结果。',
    nextStep: '周四再检查同类题',
    dueLabel: '9 月 12 日',
    subject: '语文',
  ),
  V2FocusItem(
    title: '函数应用题思路不清',
    summary: '能够套公式，但不会根据题意建立关系。',
    nextStep: '再练 2 道同类题',
    dueLabel: '9 月 14 日',
    subject: '数学',
  ),
];

const v2Timeline = <V2TimelineEntry>[
  V2TimelineEntry(
    date: '今天',
    kind: '新表现',
    body: '已经会主动定位关键词，但最后一个要点仍然遗漏。下次再观察是否能够独立完成。',
    teacher: '王老师',
    time: '18:31',
    photoCount: 3,
  ),
  V2TimelineEntry(
    date: '9 月 8 日',
    kind: '检查结果',
    body: '本次练习正确率提高，仍有两个易错点。继续保持，增加易错字复习。',
    teacher: '王老师',
    time: '17:20',
  ),
  V2TimelineEntry(
    date: '9 月 5 日',
    kind: '教学处理',
    body: '重新讲解“对象 + 特征 + 结果”的概括结构，并做了两道同类题。',
    teacher: '王老师',
    time: '16:05',
  ),
  V2TimelineEntry(
    date: '9 月 3 日',
    kind: '发现问题',
    body: '阅读第三题概括遗漏两个关键点，需要提醒才发现。',
    teacher: '王老师',
    time: '15:40',
  ),
];
