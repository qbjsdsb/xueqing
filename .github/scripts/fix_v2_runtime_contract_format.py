from pathlib import Path

path = Path('test/features/design_v2_real_preview_contract_test.dart')
text = path.read_text()
old = "    expect(workspace, contains('listForEvidence(widget.evidenceId)'));\n"
new = (
    "    expect(workspace, contains('widget.repository.listForEvidence('));\n"
    "    expect(workspace, contains('widget.evidenceId'));\n"
)
if text.count(old) != 1:
    raise SystemExit(f'photo contract assertion: expected 1, found {text.count(old)}')
path.write_text(text.replace(old, new, 1))
