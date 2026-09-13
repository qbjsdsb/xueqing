import 'package:flutter/material.dart';

/// Shared editorial header for top-level V2 workspaces.
///
/// The header deliberately stays inside the content surface instead of
/// introducing another AppBar/card layer. It keeps title, context, actions and
/// a local section switch in one visual rhythm across Personal and
/// Organization scopes.
class V2PageHeader extends StatelessWidget {
  const V2PageHeader({
    required this.title,
    this.meta,
    this.description,
    this.leading,
    this.actions = const <Widget>[],
    this.footer,
    super.key,
  });

  final String title;
  final String? meta;
  final String? description;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        if (meta?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text(
            meta!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    Widget titleRow() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(child: copy),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackActions =
            constraints.maxWidth < 520 &&
            (actions.length > 2 || (leading != null && actions.length > 1));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (actions.isEmpty || stackActions)
              titleRow()
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Expanded(child: copy),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions,
                  ),
                ],
              ),
            if (stackActions) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
            if (footer != null) ...[const SizedBox(height: 16), footer!],
          ],
        );
      },
    );
  }
}
