from pathlib import Path

path = Path('test/features/release_ux_acceptance_matrix_test.dart')
source = path.read_text(encoding='utf-8')
needle = """    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(dark: true, textScale: 1.5));
"""
replacement = """    ]) {
      // Each viewport is an independent release scenario. Destroy the previous
      // workspace first so root-navigation state cannot leak across sizes.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(dark: true, textScale: 1.5));
"""
if source.count(needle) != 1:
    raise SystemExit('compact matrix insertion point drifted')
source = source.replace(needle, replacement, 1)

needle_desktop = """    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(dark: true, textScale: 2));
"""
replacement_desktop = """    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(dark: true, textScale: 2));
"""
if source.count(needle_desktop) != 1:
    raise SystemExit('desktop matrix insertion point drifted')
source = source.replace(needle_desktop, replacement_desktop, 1)
path.write_text(source, encoding='utf-8')
Path('.github/scripts/fix_final_ux_matrix_state.py').unlink()
