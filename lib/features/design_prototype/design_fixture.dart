/// Small, explicit fixture data for the Phase 0A.5 design preview.
///
/// These names and facts are intentionally fictional. This file must not
/// become a production data source or a substitute for repositories.
enum PrototypeCaseStatus {
  // Dart's `new` is a keyword; `newCase` represents the Foundation `new` state.
  newCase,
  confirmed,
  intervening,
  pendingVerification,
  stable,
  closed,
}

enum PrototypeActionKind { evidence, intervention, verification, review }

/// Date semantics for an ordinary action queue.
///
/// `pendingVerification` is deliberately not a value here: it is a Case-level
/// bucket and therefore cannot be duplicated in an ordinary action bucket.
enum PrototypeActionDueBucket { overdue, today, future, undated }

class PrototypeAction {
  const PrototypeAction({
    required this.id,
    required this.title,
    required this.dueLabel,
    required this.kind,
    required this.dueBucket,
    this.dueDate,
  }) : assert(
         dueBucket == PrototypeActionDueBucket.undated
             ? dueDate == null
             : dueDate != null,
         'Undated actions have no dueDate; dated actions must have one.',
       );

  final String id;
  final String title;
  final String dueLabel;
  final PrototypeActionKind kind;
  final PrototypeActionDueBucket dueBucket;
  final DateTime? dueDate;
}

class PrototypeTimelineEvent {
  const PrototypeTimelineEvent({
    required this.dateLabel,
    required this.typeLabel,
    required this.text,
  });

  final String dateLabel;
  final String typeLabel;
  final String text;
}

class PrototypeCase {
  const PrototypeCase({
    required this.id,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.priorityLabel,
    required this.subject,
    required this.problem,
    required this.evidence,
    required this.judgement,
    required this.intervention,
    required this.assessment,
    required this.nextAction,
    required this.nextActionDue,
    required this.timeline,
    this.primaryAction,
  });

  final String id;
  final String title;
  final PrototypeCaseStatus status;
  final String statusLabel;
  final String priorityLabel;
  final String subject;
  final String problem;
  final String evidence;
  final String judgement;
  final String intervention;
  final String assessment;
  final String nextAction;
  final String nextActionDue;
  final List<PrototypeTimelineEvent> timeline;
  final PrototypeAction? primaryAction;
}

class PrototypeStudent {
  const PrototypeStudent({
    required this.id,
    required this.name,
    required this.grade,
    required this.subject,
    required this.context,
    required this.cases,
    required this.recentFacts,
  });

  final String id;
  final String name;
  final String grade;
  final String subject;
  final String context;
  final List<PrototypeCase> cases;
  final List<PrototypeTimelineEvent> recentFacts;
}

abstract final class DesignFixture {
  /// The fixed preview date keeps the fixture and executable tests deterministic.
  static final previewDate = DateTime(2026, 9, 2);

  static final students = <PrototypeStudent>[
    PrototypeStudent(
      id: 'demo-student-a',
      name: '示例学生甲',
      grade: '八年级',
      subject: '数学',
      context: '分数与应用题',
      cases: <PrototypeCase>[
        PrototypeCase(
          id: 'demo-case-a1',
          title: '异分母比较时把分子分母直接相加',
          status: PrototypeCaseStatus.pendingVerification,
          statusLabel: '待验证',
          priorityLabel: '重点跟进',
          subject: '数学',
          problem: '在异分母比较时，容易直接相加分子和分母，尚未形成通分的稳定步骤。',
          evidence: '9 月 2 日课堂练习中，3 道题有 2 道跳过通分；口头复述时能说出“要找公分母”。',
          judgement: '概念能够复述，但迁移到新题型时步骤不稳定，需要再观察过程而不只看答案。',
          intervention: '用一条数轴重新演示，再让学生先说步骤、后写计算。',
          assessment: '本次验证通过，仍待确认是否稳定。',
          nextAction: '再做两道迁移题并核对过程',
          nextActionDue: '9 月 4 日',
          timeline: <PrototypeTimelineEvent>[
            PrototypeTimelineEvent(
              dateLabel: '9 月 2 日',
              typeLabel: 'Assessment / Verification',
              text: '本次验证通过，等待教师确认是否稳定。',
            ),
            PrototypeTimelineEvent(
              dateLabel: '9 月 2 日',
              typeLabel: 'Evidence',
              text: '课堂练习中 3 道题有 2 道跳过通分。',
            ),
            PrototypeTimelineEvent(
              dateLabel: '8 月 30 日',
              typeLabel: 'Intervention',
              text: '使用数轴和口头步骤复述进行干预。',
            ),
          ],
          primaryAction: PrototypeAction(
            id: 'demo-action-a1',
            title: '确认是否稳定',
            dueLabel: '今天到期',
            kind: PrototypeActionKind.verification,
            dueBucket: PrototypeActionDueBucket.today,
            dueDate: previewDate,
          ),
        ),
        PrototypeCase(
          id: 'demo-case-a2',
          title: '应用题审题时跳过数量关系',
          status: PrototypeCaseStatus.intervening,
          statusLabel: '干预中',
          priorityLabel: '常规跟进',
          subject: '数学',
          problem: '读完题目后直接列式，容易漏掉单位关系和已知条件之间的对应。',
          evidence: '最近一次课后题中，列式正确 1 题，另外 2 题缺少数量关系说明。',
          judgement: '主要困难出现在把文字条件转成关系式，先练习复述比增加题量更合适。',
          intervention: '每题先用一句话说出“已知什么、求什么、如何联系”。',
          assessment: '尚未安排下一次验证。',
          nextAction: '课后复述一道题的数量关系',
          nextActionDue: '已逾期 8 月 31 日',
          timeline: <PrototypeTimelineEvent>[
            PrototypeTimelineEvent(
              dateLabel: '8 月 29 日',
              typeLabel: 'Intervention',
              text: '开始使用“已知—求—关系”三句复述。',
            ),
            PrototypeTimelineEvent(
              dateLabel: '8 月 28 日',
              typeLabel: 'Evidence',
              text: '两道应用题列式前没有写出数量关系。',
            ),
          ],
          primaryAction: PrototypeAction(
            id: 'demo-action-a2',
            title: '课后复述一道题的数量关系',
            dueLabel: '已逾期 8 月 31 日',
            kind: PrototypeActionKind.intervention,
            dueBucket: PrototypeActionDueBucket.overdue,
            dueDate: DateTime(2026, 8, 31),
          ),
        ),
      ],
      recentFacts: <PrototypeTimelineEvent>[
        PrototypeTimelineEvent(
          dateLabel: '9 月 2 日',
          typeLabel: '课堂观察',
          text: '能口头说出公分母，但书写步骤仍会跳过。',
        ),
        PrototypeTimelineEvent(
          dateLabel: '8 月 30 日',
          typeLabel: '教学动作',
          text: '使用数轴演示后，再让学生复述步骤。',
        ),
      ],
    ),
    PrototypeStudent(
      id: 'demo-student-b',
      name: '示例学生乙',
      grade: '七年级',
      subject: '英语',
      context: '近义词辨析',
      cases: <PrototypeCase>[
        PrototypeCase(
          id: 'demo-case-b1',
          title: '近义词辨析混淆',
          status: PrototypeCaseStatus.newCase,
          statusLabel: '待整理',
          priorityLabel: '新记录',
          subject: '英语',
          problem: '在两个相近词的语境选择中，容易依赖中文直译。',
          evidence: '课堂口头练习中出现一次选择犹豫，尚未补充题目记录。',
          judgement: '尚未形成足够判断，需要补充一条具体题目证据。',
          intervention: '尚未记录。',
          assessment: '尚未记录。',
          nextAction: '补充一条题目证据后再整理',
          nextActionDue: '待安排',
          timeline: <PrototypeTimelineEvent>[
            PrototypeTimelineEvent(
              dateLabel: '9 月 2 日',
              typeLabel: 'Quick Capture',
              text: '课堂中先记录为待整理问题。',
            ),
          ],
          primaryAction: PrototypeAction(
            id: 'demo-action-b1',
            title: '补充一条题目证据后再整理',
            dueLabel: '待安排',
            kind: PrototypeActionKind.evidence,
            dueBucket: PrototypeActionDueBucket.undated,
          ),
        ),
        PrototypeCase(
          id: 'demo-case-b2',
          title: '句子语境中近义词选择不稳定',
          status: PrototypeCaseStatus.intervening,
          statusLabel: '干预中',
          priorityLabel: '常规跟进',
          subject: '英语',
          problem: '在两个相近词的语境选择中，仍会依赖中文直译，回答前缺少复述步骤。',
          evidence: '9 月 2 日课堂口头练习中，4 题有 1 题先猜中文含义后再改答案。',
          judgement: '需要先稳定语境复述，再观察选择是否能独立完成。',
          intervention: '每道题先用英文短句复述语境，再说明选择依据。',
          assessment: '尚未安排下一次验证。',
          nextAction: '课堂中复述一句例句',
          nextActionDue: '今天到期',
          timeline: <PrototypeTimelineEvent>[
            PrototypeTimelineEvent(
              dateLabel: '9 月 2 日',
              typeLabel: 'Intervention',
              text: '开始用短句复述语境后再选择近义词。',
            ),
            PrototypeTimelineEvent(
              dateLabel: '9 月 2 日',
              typeLabel: 'Evidence',
              text: '口头练习中有一题先依赖中文直译。',
            ),
          ],
          primaryAction: PrototypeAction(
            id: 'demo-action-b2',
            title: '课堂中复述一句例句',
            dueLabel: '今天到期',
            kind: PrototypeActionKind.intervention,
            dueBucket: PrototypeActionDueBucket.today,
            dueDate: previewDate,
          ),
        ),
        PrototypeCase(
          id: 'demo-case-b3',
          title: '阅读理解中概括依据不足',
          status: PrototypeCaseStatus.intervening,
          statusLabel: '干预中',
          priorityLabel: '常规跟进',
          subject: '英语',
          problem: '概括段落时容易只复述结论，没有指出答案对应的原文依据。',
          evidence: '课后练习中有两题写出结论，但没有标出对应句子。',
          judgement: '需要在下一次练习中继续观察“结论—依据”的对应关系。',
          intervention: '先圈出依据句，再用一句话概括答案。',
          assessment: '尚未安排下一次验证。',
          nextAction: '下次课检查两道依据题',
          nextActionDue: '9 月 6 日',
          timeline: <PrototypeTimelineEvent>[
            PrototypeTimelineEvent(
              dateLabel: '9 月 2 日',
              typeLabel: 'Intervention',
              text: '开始练习先标出依据句，再概括答案。',
            ),
          ],
          primaryAction: PrototypeAction(
            id: 'demo-action-b3',
            title: '下次课检查两道依据题',
            dueLabel: '9 月 6 日',
            kind: PrototypeActionKind.review,
            dueBucket: PrototypeActionDueBucket.future,
            dueDate: DateTime(2026, 9, 6),
          ),
        ),
      ],
      recentFacts: <PrototypeTimelineEvent>[
        PrototypeTimelineEvent(
          dateLabel: '9 月 2 日',
          typeLabel: '课堂记录',
          text: '新增一条待整理问题，尚未安排日期。',
        ),
      ],
    ),
  ];

  static Iterable<PrototypeCase> get cases sync* {
    for (final student in students) {
      yield* student.cases;
    }
  }

  static PrototypeStudent studentForCase(PrototypeCase targetCase) {
    return students.firstWhere(
      (student) => student.cases.any((item) => item.id == targetCase.id),
    );
  }
}
