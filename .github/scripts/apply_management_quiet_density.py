from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one match, found {count}')
    return text.replace(old, new, 1)


areas_path = Path(
    'lib/features/organization_management/presentation/'
    'organization_management_areas.dart'
)
areas = areas_path.read_text(encoding='utf-8')
areas = replace_once(
    areas,
    """      decoration: BoxDecoration(\n        color: colorScheme.primaryContainer.withValues(alpha: 0.32),\n        borderRadius: BorderRadius.circular(AppRadii.medium),\n      ),\n""",
    """      decoration: BoxDecoration(\n        color: colorScheme.surfaceContainerLow,\n        border: Border(\n          left: BorderSide(color: colorScheme.primary, width: 2),\n        ),\n      ),\n""",
    'quiet setup next-step surface',
)
areas_path.write_text(areas, encoding='utf-8')

rows_path = Path(
    'lib/features/organization_management/presentation/'
    'organization_management_rows.dart'
)
rows = rows_path.read_text(encoding='utf-8')
rows = replace_once(
    rows,
    """      leading: CircleAvatar(\n        radius: 20,\n        backgroundColor: colorScheme.primaryContainer,\n        foregroundColor: colorScheme.onPrimaryContainer,\n        child: Text(initials),\n      ),\n""",
    """      leading: CircleAvatar(\n        radius: 20,\n        backgroundColor: colorScheme.surfaceContainer,\n        foregroundColor: colorScheme.onSurfaceVariant,\n        child: Text(initials),\n      ),\n""",
    'neutral member avatar',
)
rows = replace_once(
    rows,
    """    return Container(\n      width: double.infinity,\n      margin: const EdgeInsets.only(bottom: AppSpacing.xs),\n      padding: const EdgeInsets.all(AppSpacing.md),\n      decoration: BoxDecoration(\n        color: colorScheme.surfaceContainerLow,\n        borderRadius: BorderRadius.circular(AppRadii.medium),\n      ),\n      child: Row(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: [\n          SizedBox(width: 40, child: Center(child: leading)),\n          const SizedBox(width: AppSpacing.sm),\n          Expanded(child: child),\n        ],\n      ),\n    );\n""",
    """    return Container(\n      width: double.infinity,\n      padding: const EdgeInsets.symmetric(\n        horizontal: AppSpacing.xs,\n        vertical: AppSpacing.md,\n      ),\n      decoration: BoxDecoration(\n        border: Border(\n          bottom: BorderSide(color: colorScheme.outlineVariant),\n        ),\n      ),\n      child: Row(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: [\n          SizedBox(width: 36, child: Center(child: leading)),\n          const SizedBox(width: AppSpacing.sm),\n          Expanded(child: child),\n        ],\n      ),\n    );\n""",
    'quiet management row shell',
)
rows = replace_once(
    rows,
    """  @override\n  Widget build(BuildContext context) {\n    return Chip(\n      label: Text(label),\n      visualDensity: VisualDensity.compact,\n      side: BorderSide.none,\n      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,\n    );\n  }\n}\n\nclass _ManagementStatusChip extends StatelessWidget {\n""",
    """  @override\n  Widget build(BuildContext context) {\n    final colorScheme = Theme.of(context).colorScheme;\n    return Container(\n      padding: const EdgeInsets.symmetric(\n        horizontal: AppSpacing.xs,\n        vertical: AppSpacing.xxs,\n      ),\n      decoration: BoxDecoration(\n        color: colorScheme.surfaceContainerLow,\n        border: Border.all(color: colorScheme.outlineVariant),\n        borderRadius: BorderRadius.circular(AppRadii.small),\n      ),\n      child: Text(\n        label,\n        style: Theme.of(context).textTheme.labelSmall?.copyWith(\n          color: colorScheme.onSurfaceVariant,\n          fontWeight: FontWeight.w500,\n        ),\n      ),\n    );\n  }\n}\n\nclass _ManagementStatusChip extends StatelessWidget {\n""",
    'quiet role metadata label',
)
rows = replace_once(
    rows,
    """  @override\n  Widget build(BuildContext context) {\n    final colorScheme = Theme.of(context).colorScheme;\n    final color = isPositive\n        ? colorScheme.primary\n        : colorScheme.onSurfaceVariant;\n    return Chip(\n      label: Text(label),\n      visualDensity: VisualDensity.compact,\n      side: BorderSide.none,\n      backgroundColor: color.withValues(alpha: 0.12),\n      labelStyle: TextStyle(color: color),\n    );\n  }\n}\n""",
    """  @override\n  Widget build(BuildContext context) {\n    final colorScheme = Theme.of(context).colorScheme;\n    final color = isPositive\n        ? colorScheme.primary\n        : colorScheme.onSurfaceVariant;\n    return Container(\n      padding: const EdgeInsets.symmetric(\n        horizontal: AppSpacing.xs,\n        vertical: AppSpacing.xxs,\n      ),\n      decoration: BoxDecoration(\n        color: color.withValues(alpha: isPositive ? 0.08 : 0.06),\n        border: Border.all(color: color.withValues(alpha: 0.18)),\n        borderRadius: BorderRadius.circular(AppRadii.small),\n      ),\n      child: Text(\n        label,\n        style: Theme.of(context).textTheme.labelSmall?.copyWith(\n          color: color,\n          fontWeight: FontWeight.w600,\n        ),\n      ),\n    );\n  }\n}\n""",
    'quiet status metadata label',
)
rows_path.write_text(rows, encoding='utf-8')

visual_path = Path('docs/design/VISUAL_FOUNDATION.md')
visual = visual_path.read_text(encoding='utf-8')
if '## Organization Management Density Contract' not in visual:
    visual = visual.rstrip() + """\n\n## Organization Management Density Contract\n\nOrganization Management remains information-dense, but repeated records should read as a quiet work list rather than a stack of mini cards.\n\n- repeated member / student / assignment rows use spacing and thin dividers instead of rounded filled containers;\n- role and identity metadata stays neutral and compact;\n- status may use a restrained semantic tint, but should not become a wall of Material Chips;\n- setup guidance may emphasize the next step with a slim semantic edge, not a large primary-tinted block;\n- local actions remain near the record they affect; visual reduction must not hide real operational capability.\n\nSee `docs/design/MANAGEMENT_DENSITY_AUDIT.md` for the audit boundary.\n"""
visual_path.write_text(visual, encoding='utf-8')

print('management quiet density patch applied')
