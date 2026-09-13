from pathlib import Path

path = Path('test/features/design_v2_workspace_test.dart')
text = path.read_text(encoding='utf-8')
old = """      final gesture = await tester.startGesture(tester.getCenter(surface));
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();

      final draggedPage = pageView.controller!.page!;
"""
new = """      final gesture = await tester.startGesture(tester.getCenter(surface));
      // The first move crosses Flutter's drag slop and wins the horizontal
      // gesture arena. The second move must then update the PageView before
      // the pointer is released, which is the direct-manipulation contract.
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-96, 0));
      await tester.pump();

      final draggedPage = pageView.controller!.page!;
"""
if old not in text:
    raise SystemExit('direct-manipulation test snippet not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
