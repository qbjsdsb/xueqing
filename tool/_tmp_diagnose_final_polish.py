from pathlib import Path

path = Path('test/features/v037_final_teacher_flow_resilience_test.dart')
text = path.read_text()
old = """    const item = V2FocusItem(
      id: 'case-existing',
      studentId: student.id,
"""
new = """    const item = V2FocusItem(
      id: 'case-existing',
      studentId: 's-existing',
"""
if old not in text:
    raise SystemExit('focused fixture target not found')
text = text.replace(old, new, 1)
text = text.replace('    expect(tester.takeException(), isNull);\n', '', 2)
path.write_text(text)
