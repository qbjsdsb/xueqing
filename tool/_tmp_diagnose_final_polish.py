from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


composer_path = Path('lib/features/design_v2/v2_composers.dart')
composer = composer_path.read_text()
old_media_actions = """        Row(
          children: [
            TextButton.icon(
              key: const Key('v2-media-add'),
              onPressed: attachments.length >= 3 ? null : onAdd,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(attachments.isEmpty ? '拍照 / 相册' : '继续添加'),
            ),
            const SizedBox(width: 6),
            Text(
              '${attachments.length}/3',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
"""
new_media_actions = """        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              key: const Key('v2-media-add'),
              onPressed: attachments.length >= 3 ? null : onAdd,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(attachments.isEmpty ? '拍照 / 相册' : '继续添加'),
            ),
            Text(
              '${attachments.length}/3',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
"""
composer_path.write_text(
    replace_once(
        composer,
        old_media_actions,
        new_media_actions,
        'responsive media action strip',
    )
)

test_path = Path('test/features/v037_final_teacher_flow_resilience_test.dart')
test = test_path.read_text()
old_fixture = """    const item = V2FocusItem(
      id: 'case-existing',
      studentId: student.id,
"""
new_fixture = """    const item = V2FocusItem(
      id: 'case-existing',
      studentId: 's-existing',
"""
test_path.write_text(
    replace_once(test, old_fixture, new_fixture, 'focused regression fixture')
)
