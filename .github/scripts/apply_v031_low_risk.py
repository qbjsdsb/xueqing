from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 match, found {count}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/export/learning_record_export.dart',
    "import 'dart:typed_data';\n\n",
    "import 'dart:io';\nimport 'dart:typed_data';\n\n",
    'export dart:io import',
)
replace_once(
    'lib/export/learning_record_export.dart',
    "import 'package:file_saver/file_saver.dart';\n",
    "import 'package:file_saver/file_saver.dart';\nimport 'package:path_provider/path_provider.dart';\n",
    'export path_provider import',
)
replace_once(
    'lib/export/learning_record_export.dart',
    """  static Future<String?> saveAsXlsx({
    required String fileNameWithoutExtension,
    required List<LearningRecordExportRow> rows,
  }) {
    final bytes = buildWorkbook(rows: rows);
    return FileSaver.instance.saveAs(
      name: sanitizeFileName(fileNameWithoutExtension),
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }
""",
    """  static Future<String?> saveAsXlsx({
    required String fileNameWithoutExtension,
    required List<LearningRecordExportRow> rows,
  }) async {
    final bytes = buildWorkbook(rows: rows);
    final name = sanitizeFileName(fileNameWithoutExtension);
    if (Platform.isWindows) {
      final downloads = await getDownloadsDirectory();
      if (downloads == null) {
        throw const FileSystemException('无法读取 Windows 下载文件夹。');
      }
      var file = File(
        '${downloads.path}${Platform.pathSeparator}$name.xlsx',
      );
      var suffix = 2;
      while (await file.exists()) {
        file = File(
          '${downloads.path}${Platform.pathSeparator}$name-$suffix.xlsx',
        );
        suffix++;
      }
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
    return FileSaver.instance.saveAs(
      name: name,
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }
""",
    'Windows direct Downloads export',
)

replace_once(
    'lib/features/design_v2/v2_workspace_preview.dart',
    """    final transitionKey = widget.showCase && widget.selectedCase != null
        ? 'case-${widget.selectedCase!.id}'
        : widget.destination == 1 && _studentOpen
        ? 'student-${widget.selectedStudent.id}'
        : 'destination-${widget.destination}';

    return Scaffold(
      body: SafeArea(
        child: _QuietPaneTransition(transitionKey: transitionKey, child: body),
      ),
""",
    """    return Scaffold(
      body: SafeArea(child: body),
""",
    'compact full-screen transition removal',
)

replace_once(
    'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
    '        android:pathData="M50.9,34.2 L50.9,78.1 L28.0,70.4 L28.0,29.2 Z M57.1,34.2 L57.1,78.1 L80.0,70.4 L80.0,29.2 Z" />',
    '        android:pathData="M51.2,35.0 L51.2,75.5 Q41.8,72.0 30.8,69.2 L30.8,31.5 Q40.2,33.0 51.2,35.0 Z M56.8,35.0 L56.8,75.5 Q66.2,72.0 77.2,69.2 L77.2,31.5 Q67.8,33.0 56.8,35.0 Z" />',
    'adaptive icon optical path',
)

# Legacy Android launchers still use raster mipmaps below API 26 and on some
# vendor launchers. Regenerate them with the same smaller, softer mark.
from PIL import Image, ImageDraw

GREEN = (45, 106, 91, 255)
CREAM = (248, 246, 239, 255)


def quad(p0, p1, p2, steps=16):
    points = []
    for i in range(steps + 1):
        t = i / steps
        u = 1.0 - t
        points.append((
            u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
        ))
    return points


def page_points(left=True):
    if left:
        pts = [(51.2, 35.0), (51.2, 75.5)]
        pts += quad((51.2, 75.5), (41.8, 72.0), (30.8, 69.2))[1:]
        pts += [(30.8, 31.5)]
        pts += quad((30.8, 31.5), (40.2, 33.0), (51.2, 35.0))[1:]
        return pts
    pts = [(56.8, 35.0), (56.8, 75.5)]
    pts += quad((56.8, 75.5), (66.2, 72.0), (77.2, 69.2))[1:]
    pts += [(77.2, 31.5)]
    pts += quad((77.2, 31.5), (67.8, 33.0), (56.8, 35.0))[1:]
    return pts


def render(size, rounded=False):
    scale = 4
    canvas = Image.new('RGBA', (size * scale, size * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    if rounded:
        draw.ellipse((0, 0, size * scale - 1, size * scale - 1), fill=GREEN)
    else:
        draw.rectangle((0, 0, size * scale, size * scale), fill=GREEN)
    factor = size * scale / 108.0
    for left in (True, False):
        points = [(x * factor, y * factor) for x, y in page_points(left)]
        draw.polygon(points, fill=CREAM)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}
for folder, size in sizes.items():
    base = Path('android/app/src/main/res') / folder
    render(size, rounded=False).save(base / 'ic_launcher.png')
    render(size, rounded=True).save(base / 'ic_launcher_round.png')
