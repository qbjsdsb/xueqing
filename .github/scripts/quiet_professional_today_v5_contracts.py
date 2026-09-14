from pathlib import Path

path = Path("test/features/v2_visual_polish_contract_test.dart")
text = path.read_text()

old = '''    expect(
      source,
      contains(
        "_SectionTitle(title: recentStudents.isEmpty ? '我的学生' : '最近学生'),",
      ),
    );
'''
new = '''    expect(
      source,
      contains(
        "_SectionTitle(title: showRecentActivity ? '最近学生' : '我的学生'),",
      ),
    );
    expect(source, contains('wideDesktop: expandedRail,'));
    expect(
      source,
      contains(
        'final useDesktopColumns = wideDesktop && data.students.isNotEmpty;',
      ),
    );
    expect(source, isNot(contains('constraints.maxWidth >= 960')));
'''

assert old in text, "expected legacy Today recent-student contract was not found"
path.write_text(text.replace(old, new, 1))
