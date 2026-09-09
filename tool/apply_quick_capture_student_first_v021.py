from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


page_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
page = page_path.read_text(encoding='utf-8')

page = replace_once(
    page,
    """  WorkspaceStudent? _selectedStudent;
  String _selectedCaseTypeKey = WorkspaceCaseType.builtInTypes.last.key;
  String? _studentError;
  String? _titleError;
""",
    """  WorkspaceStudent? _selectedStudentPerson;
  WorkspaceStudent? _selectedStudent;
  String _selectedCaseTypeKey = WorkspaceCaseType.builtInTypes.last.key;
  String? _studentError;
  String? _subjectError;
  String? _titleError;
""",
    'quick capture selection state',
)

selected_type_anchor = """  WorkspaceCaseType get _selectedCaseType {
    for (final caseType in _caseTypeOptions) {
      if (caseType.key == _selectedCaseTypeKey) {
        return caseType;
      }
    }
    return WorkspaceCaseType.builtInTypes.last;
  }

"""
selection_helpers = selected_type_anchor + """  List<List<WorkspaceStudent>> get _quickCaptureStudentGroups =>
      _groupStudentsById(widget.students);

  List<WorkspaceStudent> _profilesForStudentId(String studentId) {
    for (final group in _quickCaptureStudentGroups) {
      if (group.isNotEmpty && group.first.id == studentId) {
        final profiles = List<WorkspaceStudent>.of(group)
          ..sort((left, right) => left.subject.compareTo(right.subject));
        return profiles;
      }
    }
    return const <WorkspaceStudent>[];
  }

  List<WorkspaceStudent> get _selectedStudentProfiles {
    final student = _selectedStudentPerson;
    if (student == null) {
      return const <WorkspaceStudent>[];
    }
    return _profilesForStudentId(student.id);
  }

  bool get _needsSubjectSelection => _selectedStudentProfiles.length > 1;

  String _studentPersonLabel(List<WorkspaceStudent> profiles) {
    final student = profiles.first;
    if (profiles.length == 1) {
      return [student.name, student.subject].join(' · ');
    }
    return student.name;
  }

  String? _studentPersonSubtitle(List<WorkspaceStudent> profiles) {
    if (profiles.length <= 1) {
      return null;
    }
    return profiles.map((student) => student.subject).join(' · ');
  }

"""
page = replace_once(
    page,
    selected_type_anchor,
    selection_helpers,
    'quick capture grouping helpers',
)

page = replace_once(
    page,
    """    _selectedStudent =
        widget.initialStudent ??
        (widget.students.length == 1 ? widget.students.first : null);
""",
    """    if (widget.initialStudent != null) {
      _selectedStudentPerson = widget.initialStudent;
      _selectedStudent = widget.initialStudent;
    } else {
      final groups = _quickCaptureStudentGroups;
      if (groups.length == 1) {
        final profiles = List<WorkspaceStudent>.of(groups.single)
          ..sort((left, right) => left.subject.compareTo(right.subject));
        _selectedStudentPerson = profiles.first;
        _selectedStudent = profiles.length == 1 ? profiles.single : null;
      }
    }
""",
    'quick capture initial selection',
)

page = replace_once(
    page,
    """    if (_selectedStudent == null) {
      _studentError = '请选择学生';
      valid = false;
    }
""",
    """    if (_selectedStudentPerson == null) {
      _studentError = '请选择学生';
      valid = false;
    } else if (_selectedStudent == null) {
      _subjectError = '请选择学科';
      valid = false;
    }
""",
    'quick capture validation',
)

old_student_controls = """  void _selectStudent(WorkspaceStudent? student) {
    setState(() {
      _selectedStudent = student;
      _studentError = null;
    });
    if (student == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_saving) {
        _titleFocusNode.requestFocus();
      }
    });
  }

  bool _isCompact(BuildContext context) =>
      ResponsiveBreakpoints.classify(MediaQuery.sizeOf(context).width) ==
      WindowSizeClass.compact;

  Widget _buildStudentField(BuildContext context) {
    if (!_isCompact(context)) {
      return DropdownButtonFormField<WorkspaceStudent>(
        initialValue: _selectedStudent,
        decoration: InputDecoration(
          labelText: '学生 *',
          errorText: _studentError,
        ),
        hint: const Text('选择学生后开始'),
        items: [
          for (final student in widget.students)
            DropdownMenuItem<WorkspaceStudent>(
              value: student,
              child: Text([student.name, student.subject].join(' · ')),
            ),
        ],
        onChanged: _saving ? null : _selectStudent,
      );
    }

    final student = _selectedStudent;
    return _WorkspaceChoiceField(
      fieldKey: const Key('quick-capture-student-picker'),
      label: '学生 *',
      value: student == null
          ? '请选择学生'
          : [student.name, student.subject].join(' · '),
      errorText: _studentError,
      onTap: _saving ? null : _openStudentPicker,
    );
  }

"""
new_student_controls = """  void _focusQuickCaptureNote() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_saving) {
        _titleFocusNode.requestFocus();
      }
    });
  }

  void _selectStudentPerson(WorkspaceStudent? student) {
    if (student == null) {
      setState(() {
        _selectedStudentPerson = null;
        _selectedStudent = null;
        _studentError = null;
        _subjectError = null;
      });
      _titleFocusNode.unfocus();
      return;
    }
    final profiles = _profilesForStudentId(student.id);
    final selectedProfile = profiles.length == 1 ? profiles.single : null;
    setState(() {
      _selectedStudentPerson = student;
      _selectedStudent = selectedProfile;
      _studentError = null;
      _subjectError = null;
    });
    if (selectedProfile == null) {
      _titleFocusNode.unfocus();
    } else {
      _focusQuickCaptureNote();
    }
  }

  void _selectSubject(WorkspaceStudent? student) {
    setState(() {
      _selectedStudent = student;
      _subjectError = null;
    });
    if (student != null) {
      _focusQuickCaptureNote();
    }
  }

  bool _isCompact(BuildContext context) =>
      ResponsiveBreakpoints.classify(MediaQuery.sizeOf(context).width) ==
      WindowSizeClass.compact;

  Widget _buildStudentField(BuildContext context) {
    final groups = _quickCaptureStudentGroups;
    if (!_isCompact(context)) {
      return DropdownButtonFormField<WorkspaceStudent>(
        key: const Key('quick-capture-student-picker'),
        initialValue: _selectedStudentPerson,
        decoration: InputDecoration(
          labelText: '学生 *',
          errorText: _studentError,
        ),
        hint: const Text('选择学生后开始'),
        items: [
          for (final group in groups)
            DropdownMenuItem<WorkspaceStudent>(
              value: group.first,
              child: Text(_studentPersonLabel(group)),
            ),
        ],
        onChanged: _saving ? null : _selectStudentPerson,
      );
    }

    final student = _selectedStudentPerson;
    final profiles = student == null
        ? const <WorkspaceStudent>[]
        : _profilesForStudentId(student.id);
    return _WorkspaceChoiceField(
      fieldKey: const Key('quick-capture-student-picker'),
      label: '学生 *',
      value: student == null ? '请选择学生' : _studentPersonLabel(profiles),
      errorText: _studentError,
      onTap: _saving ? null : _openStudentPicker,
    );
  }

  Widget _buildSubjectField(BuildContext context) {
    final profiles = _selectedStudentProfiles;
    if (!_isCompact(context)) {
      return DropdownButtonFormField<WorkspaceStudent>(
        key: const Key('quick-capture-subject-picker'),
        initialValue: _selectedStudent,
        decoration: InputDecoration(
          labelText: '学科 *',
          errorText: _subjectError,
        ),
        hint: const Text('选择这次记录属于哪个学科'),
        items: [
          for (final profile in profiles)
            DropdownMenuItem<WorkspaceStudent>(
              value: profile,
              child: Text(profile.subject),
            ),
        ],
        onChanged: _saving ? null : _selectSubject,
      );
    }

    return _WorkspaceChoiceField(
      fieldKey: const Key('quick-capture-subject-picker'),
      label: '学科 *',
      value: _selectedStudent?.subject ?? '请选择学科',
      errorText: _subjectError,
      onTap: _saving ? null : _openSubjectPicker,
    );
  }

"""
page = replace_once(
    page,
    old_student_controls,
    new_student_controls,
    'quick capture student controls',
)

old_student_picker = """  Future<void> _openStudentPicker() async {
    if (_saving || widget.students.isEmpty) {
      return;
    }
    final selectedStudent = await showModalBottomSheet<WorkspaceStudent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _WorkspaceChoiceSheet<WorkspaceStudent>(
        title: '选择学生',
        selectedValue: _selectedStudent,
        options: [
          for (final student in widget.students)
            _WorkspaceChoiceOption<WorkspaceStudent>(
              key: ValueKey<String>(
                'quick-capture-student-option-${student.profileId}',
              ),
              value: student,
              title: [student.name, student.subject].join(' · '),
            ),
        ],
      ),
    );
    if (!mounted || selectedStudent == null) {
      return;
    }
    _selectStudent(selectedStudent);
  }

"""
new_student_picker = """  Future<void> _openStudentPicker() async {
    final groups = _quickCaptureStudentGroups;
    if (_saving || groups.isEmpty) {
      return;
    }
    final selectedStudent = await showModalBottomSheet<WorkspaceStudent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _WorkspaceChoiceSheet<WorkspaceStudent>(
        title: '选择学生',
        selectedValue: _selectedStudentPerson,
        options: [
          for (final group in groups)
            _WorkspaceChoiceOption<WorkspaceStudent>(
              key: ValueKey<String>(
                'quick-capture-student-option-${group.first.profileId}',
              ),
              value: group.first,
              title: _studentPersonLabel(group),
              subtitle: _studentPersonSubtitle(group),
            ),
        ],
      ),
    );
    if (!mounted || selectedStudent == null) {
      return;
    }
    _selectStudentPerson(selectedStudent);
  }

  Future<void> _openSubjectPicker() async {
    final profiles = _selectedStudentProfiles;
    if (_saving || profiles.length <= 1) {
      return;
    }
    final selectedSubject = await showModalBottomSheet<WorkspaceStudent>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _WorkspaceChoiceSheet<WorkspaceStudent>(
        title: '选择学科',
        selectedValue: _selectedStudent,
        options: [
          for (final profile in profiles)
            _WorkspaceChoiceOption<WorkspaceStudent>(
              key: ValueKey<String>(
                'quick-capture-subject-option-${profile.profileId}',
              ),
              value: profile,
              title: profile.subject,
              subtitle: profile.context.trim().isEmpty ? null : profile.context,
            ),
        ],
      ),
    );
    if (!mounted || selectedSubject == null) {
      return;
    }
    _selectSubject(selectedSubject);
  }

"""
page = replace_once(
    page,
    old_student_picker,
    new_student_picker,
    'quick capture pickers',
)

old_build_selection = """                  if (widget.initialStudent != null)
                    _WorkspaceContextLine(
                      label: '学生',
                      value: [
                        widget.initialStudent!.name,
                        widget.initialStudent!.subject,
                      ].join(' · '),
                    )
                  else
                    _buildStudentField(context),
                  if (currentCases.isNotEmpty) ...[
"""
new_build_selection = """                  if (widget.initialStudent != null)
                    _WorkspaceContextLine(
                      label: '学生',
                      value: [
                        widget.initialStudent!.name,
                        widget.initialStudent!.subject,
                      ].join(' · '),
                    ),
                  if (widget.initialStudent == null) _buildStudentField(context),
                  if (widget.initialStudent == null && _needsSubjectSelection) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildSubjectField(context),
                  ],
                  if (currentCases.isNotEmpty) ...[
"""
page = replace_once(
    page,
    old_build_selection,
    new_build_selection,
    'quick capture student subject layout',
)

page_path.write_text(page, encoding='utf-8')


test_path = Path('test/features/teacher_workspace_test.dart')
test = test_path.read_text(encoding='utf-8')
anchor = """  testWidgets('uses bottom sheets for compact Quick Capture selectors', (
"""
new_test = r"""  testWidgets(
    'Quick Capture chooses a unique student before choosing the subject',
    (tester) async {
      final repository = _FakeLearningRepository(
        _workspaceWithStudents([
          _studentFixture(
            id: 'shared-math',
            name: '林同学',
            studentId: 'student-shared',
            profileId: 'profile-math',
            subject: '数学',
            context: '函数基础',
          ),
          _studentFixture(
            id: 'shared-chinese',
            name: '林同学',
            studentId: 'student-shared',
            profileId: 'profile-chinese',
            subject: '语文',
            context: '现代文阅读',
          ),
          _studentFixture(
            id: 'other',
            name: '陈同学',
            studentId: 'student-other',
            profileId: 'profile-english',
            subject: '英语',
          ),
        ]),
      );
      await _pumpWorkspace(tester, repository);

      await tester.tap(find.text('记录新问题').first);
      await tester.pumpAndSettle();

      final studentPicker = find.byKey(const Key('quick-capture-student-picker'));
      expect(studentPicker, findsOneWidget);
      expect(find.byKey(const Key('quick-capture-subject-picker')), findsNothing);

      await tester.tap(studentPicker);
      await tester.pumpAndSettle();
      expect(find.text('林同学 · 数学'), findsNothing);
      expect(find.text('林同学 · 语文'), findsNothing);
      await tester.tap(find.text('林同学').last);
      await tester.pumpAndSettle();

      final subjectPicker = find.byKey(const Key('quick-capture-subject-picker'));
      expect(subjectPicker, findsOneWidget);
      await tester.tap(subjectPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('语文').last);
      await tester.pumpAndSettle();

      final noteField = find.byKey(const Key('quick-capture-title-field'));
      expect(tester.widget<TextField>(noteField).focusNode?.hasFocus, isTrue);
      await tester.enterText(noteField, '现代文阅读概括时遗漏限制词。');
      final saveButton = find.byKey(const Key('workspace-quick-capture-save'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repository.commands.single.profileId, 'profile-chinese');
    },
  );

""" + anchor
test = replace_once(test, anchor, new_test, 'quick capture student-first widget test')
test_path.write_text(test, encoding='utf-8')
