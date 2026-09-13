from pathlib import Path

path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = path.read_text()
old = '''            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  NavigationBar(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    selectedIndex: _compactPrimaryDestinations.indexOf(
                      widget.destination,
                    ),
                    onDestinationSelected: (index) {
                      widget.onDestinationChanged(
                        _compactPrimaryDestinations[index],
                      );
                    },
                    destinations: [
                      for (final destination in _compactPrimaryDestinations)
                        _compactNavigationDestination(destination),
                    ],
                  ),
                ],
              ),'''
new = '''            : NavigationBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedIndex: _compactPrimaryDestinations.indexOf(
                  widget.destination,
                ),
                onDestinationSelected: (index) {
                  widget.onDestinationChanged(
                    _compactPrimaryDestinations[index],
                  );
                },
                destinations: [
                  for (final destination in _compactPrimaryDestinations)
                    _compactNavigationDestination(destination),
                ],
              ),'''
if old not in text:
    raise SystemExit('compact NavigationBar divider block not found')
path.write_text(text.replace(old, new, 1))
