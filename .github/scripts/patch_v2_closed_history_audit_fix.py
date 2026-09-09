from pathlib import Path

path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = path.read_text(encoding='utf-8')

replacements = [
    (
        """                  Text(
                    '下一步  ${item.nextStep}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
""",
        """                  Text(
                    item.closed ? item.nextStep : '下一步  ${item.nextStep}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
""",
    ),
    (
        """    final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
    final pendingAction = controller?.pendingActionFor(item.id);
""",
        """    final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
    final pendingAction = item.closed
        ? null
        : controller?.pendingActionFor(item.id);
""",
    ),
    (
        """                  Text('下一步', style: Theme.of(context).textTheme.titleMedium),
""",
        """                  Text(
                    item.closed ? '状态' : '下一步',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
""",
    ),
]
for old, new in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'expected one match, found {count}: {old[:100]!r}')
    text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8')
print('closed history audit fix applied')
