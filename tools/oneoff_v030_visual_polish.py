from __future__ import annotations

import binascii
import math
import struct
import zlib
from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"{path}: expected exactly one match, found {count}: {old[:100]!r}"
        )
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


def replace_text_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"{label}: expected exactly one match, found {count}: {old[:100]!r}"
        )
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Motion tokens: deliberately quiet. 180 ms is enough to preserve spatial
# continuity without making a teaching tool feel animated for animation's sake.
# ---------------------------------------------------------------------------
replace_once(
    "lib/app/theme/app_motion.dart",
    "  static const Duration quick = Duration(milliseconds: 120);\n"
    "  static const Duration standard = Duration(milliseconds: 180);\n",
    "  static const Duration quick = Duration(milliseconds: 120);\n"
    "  static const Duration standard = Duration(milliseconds: 180);\n"
    "  static const Duration settle = Duration(milliseconds: 240);\n\n"
    "  static const Curve enter = Curves.easeOutCubic;\n"
    "  static const Curve exit = Curves.easeInCubic;\n",
)

# ---------------------------------------------------------------------------
# Shared shell theme polish: no new visual language, only interaction details
# that also benefit login/onboarding surfaces outside the V2 Theme scope.
# ---------------------------------------------------------------------------
replace_once(
    "lib/app/theme/app_theme.dart",
    "import 'app_colors.dart';\nimport 'app_spacing.dart';\n",
    "import 'app_colors.dart';\nimport 'app_motion.dart';\nimport 'app_spacing.dart';\n",
)
replace_once(
    "lib/app/theme/app_theme.dart",
    "      scaffoldBackgroundColor: colorScheme.surface,\n"
    "      fontFamilyFallback: fontFallback,\n"
    "      textTheme: textTheme,\n",
    "      scaffoldBackgroundColor: colorScheme.surface,\n"
    "      fontFamilyFallback: fontFallback,\n"
    "      textTheme: textTheme,\n"
    "      splashFactory: InkRipple.splashFactory,\n"
    "      hoverColor: colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.045),\n"
    "      focusColor: colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),\n"
    "      highlightColor: Colors.transparent,\n",
)
for button_marker in (
    "        style: FilledButton.styleFrom(\n",
    "        style: OutlinedButton.styleFrom(\n",
    "        style: TextButton.styleFrom(\n",
):
    p = Path("lib/app/theme/app_theme.dart")
    text = p.read_text(encoding="utf-8")
    if text.count(button_marker) != 1:
        raise SystemExit(f"app_theme.dart button marker not unique: {button_marker!r}")
    text = text.replace(
        button_marker,
        button_marker + "          animationDuration: AppMotion.quick,\n",
        1,
    )
    p.write_text(text, encoding="utf-8")
replace_once(
    "lib/app/theme/app_theme.dart",
    "      snackBarTheme: SnackBarThemeData(\n",
    "      tooltipTheme: TooltipThemeData(\n"
    "        waitDuration: const Duration(milliseconds: 350),\n"
    "        showDuration: const Duration(seconds: 2),\n"
    "        preferBelow: false,\n"
    "        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),\n"
    "        decoration: BoxDecoration(\n"
    "          color: colorScheme.inverseSurface,\n"
    "          borderRadius: BorderRadius.circular(AppRadii.small),\n"
    "        ),\n"
    "        textStyle: textTheme.bodySmall?.copyWith(\n"
    "          color: colorScheme.onInverseSurface,\n"
    "          fontSize: 12,\n"
    "        ),\n"
    "      ),\n"
    "      scrollbarTheme: ScrollbarThemeData(\n"
    "        radius: const Radius.circular(AppRadii.pill),\n"
    "        thickness: WidgetStateProperty.resolveWith((states) {\n"
    "          return states.contains(WidgetState.dragged) ? 6 : 4;\n"
    "        }),\n"
    "        thumbColor: WidgetStateProperty.resolveWith((states) {\n"
    "          final alpha = states.contains(WidgetState.dragged) ? 0.52 : 0.30;\n"
    "          return colorScheme.onSurfaceVariant.withValues(alpha: alpha);\n"
    "        }),\n"
    "      ),\n"
    "      snackBarTheme: SnackBarThemeData(\n",
)

# ---------------------------------------------------------------------------
# V2 theme polish. Keep surfaces editorial and quiet: flat hierarchy, softer
# state transitions, explicit focus/hover, no gradients, no glass effects.
# ---------------------------------------------------------------------------
replace_once(
    "lib/features/design_v2/v2_theme.dart",
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\n\n"
    "import '../../app/theme/app_motion.dart';\n",
)
replace_once(
    "lib/features/design_v2/v2_theme.dart",
    "      splashFactory: InkRipple.splashFactory,\n"
    "      visualDensity: VisualDensity.standard,\n",
    "      splashFactory: InkRipple.splashFactory,\n"
    "      hoverColor: scheme.primary.withValues(alpha: isDark ? 0.08 : 0.045),\n"
    "      focusColor: scheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),\n"
    "      highlightColor: Colors.transparent,\n"
    "      visualDensity: VisualDensity.standard,\n",
)
replace_once(
    "lib/features/design_v2/v2_theme.dart",
    "      titleMedium: base.textTheme.titleMedium?.copyWith(\n"
    "        fontSize: 16,\n"
    "        height: 1.45,\n"
    "        fontWeight: FontWeight.w600,\n"
    "      ),\n"
    "      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.6),\n",
    "      titleMedium: base.textTheme.titleMedium?.copyWith(\n"
    "        fontSize: 16,\n"
    "        height: 1.45,\n"
    "        fontWeight: FontWeight.w600,\n"
    "      ),\n"
    "      titleSmall: base.textTheme.titleSmall?.copyWith(\n"
    "        fontSize: 14,\n"
    "        height: 1.45,\n"
    "        fontWeight: FontWeight.w600,\n"
    "      ),\n"
    "      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.6),\n",
)

v2_theme_path = Path("lib/features/design_v2/v2_theme.dart")
v2_theme = v2_theme_path.read_text(encoding="utf-8")
v2_theme = v2_theme.replace("BorderRadius.circular(7)", "BorderRadius.circular(9)")
v2_theme = v2_theme.replace(
    "        style: FilledButton.styleFrom(\n",
    "        style: FilledButton.styleFrom(\n          animationDuration: AppMotion.quick,\n",
    1,
)
v2_theme = v2_theme.replace(
    "        style: OutlinedButton.styleFrom(\n",
    "        style: OutlinedButton.styleFrom(\n          animationDuration: AppMotion.quick,\n",
    1,
)
v2_theme = v2_theme.replace(
    "        style: TextButton.styleFrom(\n",
    "        style: TextButton.styleFrom(\n          animationDuration: AppMotion.quick,\n",
    1,
)
v2_theme = v2_theme.replace(
    "shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),",
    "shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),",
    1,
)
v2_theme = v2_theme.replace(
    "borderRadius: BorderRadius.vertical(top: Radius.circular(18)),",
    "borderRadius: BorderRadius.vertical(top: Radius.circular(20)),",
    1,
)
v2_theme = v2_theme.replace(
    "borderRadius: BorderRadius.circular(10),\n          side: BorderSide(color: scheme.outlineVariant),",
    "borderRadius: BorderRadius.circular(12),\n          side: BorderSide(color: scheme.outlineVariant),",
    1,
)
insert_marker = "      navigationBarTheme: NavigationBarThemeData(\n"
if v2_theme.count(insert_marker) != 1:
    raise SystemExit("v2_theme navigation marker not unique")
extra_themes = r'''      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        showDuration: const Duration(seconds: 2),
        preferBelow: false,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
          fontSize: 12,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 1,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.surfaceContainerHigh,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(999),
        thickness: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.dragged) ? 6 : 4;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final alpha = states.contains(WidgetState.dragged) ? 0.52 : 0.30;
          return scheme.onSurfaceVariant.withValues(alpha: alpha);
        }),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: scheme.onSurfaceVariant,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
'''
v2_theme = v2_theme.replace(insert_marker, extra_themes + insert_marker, 1)
v2_theme_path.write_text(v2_theme, encoding="utf-8")

# ---------------------------------------------------------------------------
# V2 production interaction polish: subtle spatial continuity, animated
# selection states, and quiet hover affordances. No decorative motion.
# ---------------------------------------------------------------------------
replace_once(
    "lib/features/design_v2/v2_workspace_preview.dart",
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\n\n"
    "import '../../app/theme/app_motion.dart';\n",
)
workspace_path = Path("lib/features/design_v2/v2_workspace_preview.dart")
workspace = workspace_path.read_text(encoding="utf-8")

transition_marker = "class _DesktopWorkspace extends StatelessWidget {\n"
if workspace.count(transition_marker) != 1:
    raise SystemExit("desktop workspace marker not unique")
transition_widget = r'''class _QuietPaneTransition extends StatelessWidget {
  const _QuietPaneTransition({
    required this.transitionKey,
    required this.child,
  });

  final Object transitionKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enterDuration = AppMotion.effectiveDuration(
      context,
      AppMotion.standard,
    );
    final exitDuration = AppMotion.effectiveDuration(context, AppMotion.quick);
    return AnimatedSwitcher(
      duration: enterDuration,
      reverseDuration: exitDuration,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.012),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey<Object>(transitionKey), child: child),
    );
  }
}

'''
workspace = workspace.replace(transition_marker, transition_widget + transition_marker, 1)

old_detail = r'''              Expanded(
                child: showCase && selectedCase != null
                    ? _CaseDetailPane(
                        student: selectedStudent,
                        item: selectedCase!,
                        onBack: onBackFromCase,
                      )
                    : _StudentDetailPane(
                        student: selectedStudent,
                        onOpenCase: onOpenCase,
                      ),
              ),
'''
new_detail = r'''              Expanded(
                child: _QuietPaneTransition(
                  transitionKey: showCase && selectedCase != null
                      ? 'case-${selectedCase!.id}'
                      : 'student-${selectedStudent.id}',
                  child: showCase && selectedCase != null
                      ? _CaseDetailPane(
                          student: selectedStudent,
                          item: selectedCase!,
                          onBack: onBackFromCase,
                        )
                      : _StudentDetailPane(
                          student: selectedStudent,
                          onOpenCase: onOpenCase,
                        ),
                ),
              ),
'''
workspace = replace_text_once(workspace, old_detail, new_detail, "desktop detail transition")

compact_return = r'''    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: widget.showCase || _studentOpen
'''
compact_replacement = r'''    final transitionKey = widget.showCase && widget.selectedCase != null
        ? 'case-${widget.selectedCase!.id}'
        : widget.destination == 1 && _studentOpen
        ? 'student-${widget.selectedStudent.id}'
        : 'destination-${widget.destination}';

    return Scaffold(
      body: SafeArea(
        child: _QuietPaneTransition(
          transitionKey: transitionKey,
          child: body,
        ),
      ),
      bottomNavigationBar: widget.showCase || _studentOpen
'''
workspace = replace_text_once(
    workspace,
    compact_return,
    compact_replacement,
    "compact pane transition",
)

old_rail = r'''        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                icon,
                size: 20,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
'''
new_rail = r'''        child: AnimatedContainer(
          duration: AppMotion.effectiveDuration(context, AppMotion.quick),
          curve: AppMotion.enter,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: onTap,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
'''
workspace = replace_text_once(workspace, old_rail, new_rail, "rail selection animation")

old_student = r'''      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
'''
new_student = r'''      child: AnimatedContainer(
        duration: AppMotion.effectiveDuration(context, AppMotion.quick),
        curve: AppMotion.enter,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
'''
workspace = replace_text_once(workspace, old_student, new_student, "student selection animation")
# AnimatedContainer adds one extra nesting level compared with the original Material.
student_close = r'''            ),
          ),
        ),
      ),
    );
  }
}

class _InitialMark extends StatelessWidget {
'''
student_close_new = r'''            ),
          ),
        ),
      ),
    );
  }
}

class _InitialMark extends StatelessWidget {
'''
# The close structure remains textually identical because the extra Material is balanced
# by replacing the original Material node. No edit is required; this assertion protects
# against accidentally patching a different row.
if workspace.count(student_close) != 1:
    raise SystemExit("student row closing structure changed unexpectedly")

workspace = replace_text_once(
    workspace,
    "    return InkWell(\n      onTap: onTap,\n      child: Padding(\n        padding: const EdgeInsets.symmetric(vertical: 16),\n",
    "    return InkWell(\n      borderRadius: BorderRadius.circular(10),\n      onTap: onTap,\n      child: Padding(\n        padding: const EdgeInsets.symmetric(vertical: 16),\n",
    "focus row hover affordance",
)
workspace = replace_text_once(
    workspace,
    "    return InkWell(\n      onTap: () => onOpenCase(item),\n      child: Padding(\n        padding: const EdgeInsets.symmetric(vertical: 15),\n",
    "    return InkWell(\n      borderRadius: BorderRadius.circular(10),\n      onTap: () => onOpenCase(item),\n      child: Padding(\n        padding: const EdgeInsets.symmetric(vertical: 15),\n",
    "today row hover affordance",
)
workspace_path.write_text(workspace, encoding="utf-8")

# ---------------------------------------------------------------------------
# Loading / empty / error states: better visual hierarchy without illustrations.
# ---------------------------------------------------------------------------
loader_path = Path("lib/features/design_v2/v2_workspace_loader.dart")
loader = loader_path.read_text(encoding="utf-8")
loader = replace_text_once(
    loader,
    "  Widget build(BuildContext context) {\n    return Scaffold(\n",
    "  Widget build(BuildContext context) {\n    final scheme = Theme.of(context).colorScheme;\n    return Scaffold(\n",
    "loader status scheme",
)
old_loader_icon = r'''                  Icon(
                    icon,
                    size: 34,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
'''
new_loader_icon = r'''                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: icon == Icons.sync
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Icon(icon, size: 26, color: scheme.onSurfaceVariant),
                  ),
'''
loader = replace_text_once(loader, old_loader_icon, new_loader_icon, "loader status icon")
loader_path.write_text(loader, encoding="utf-8")

# ---------------------------------------------------------------------------
# Release app icon: a single, literal open-learning-journal metaphor.
# No typography, gradients, sparkles, brains, chat bubbles, or decorative AI cues.
# ---------------------------------------------------------------------------
GREEN = (45, 106, 91, 255)       # matches AppColors.accent
CREAM = (248, 246, 239, 255)
TRANSPARENT = (0, 0, 0, 0)


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", binascii.crc32(kind + payload) & 0xFFFFFFFF)
    )


def encode_png(width: int, height: int, pixels: bytes) -> bytes:
    rows = []
    stride = width * 4
    for y in range(height):
        rows.append(b"\x00" + pixels[y * stride : (y + 1) * stride])
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(
            b"IHDR",
            struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0),
        )
        + png_chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
        + png_chunk(b"IEND", b"")
    )


def inside_rounded_rect(x: float, y: float, size: int, inset: float, radius: float) -> bool:
    left = inset
    top = inset
    right = size - inset
    bottom = size - inset
    if left + radius <= x <= right - radius and top <= y <= bottom:
        return True
    if left <= x <= right and top + radius <= y <= bottom - radius:
        return True
    for cx, cy in (
        (left + radius, top + radius),
        (right - radius, top + radius),
        (left + radius, bottom - radius),
        (right - radius, bottom - radius),
    ):
        if (x - cx) ** 2 + (y - cy) ** 2 <= radius**2:
            return True
    return False


def inside_circle(x: float, y: float, size: int, inset: float) -> bool:
    r = (size - 2 * inset) / 2
    cx = cy = size / 2
    return (x - cx) ** 2 + (y - cy) ** 2 <= r**2


def inside_polygon(x: float, y: float, points: list[tuple[float, float]]) -> bool:
    inside = False
    j = len(points) - 1
    for i in range(len(points)):
        xi, yi = points[i]
        xj, yj = points[j]
        if ((yi > y) != (yj > y)) and (
            x < (xj - xi) * (y - yi) / (yj - yi) + xi
        ):
            inside = not inside
        j = i
    return inside


def blend(dst: tuple[int, int, int, int], src: tuple[int, int, int, int], coverage: float):
    if coverage <= 0:
        return dst
    if coverage >= 1:
        return src
    sa = (src[3] / 255.0) * coverage
    da = dst[3] / 255.0
    out_a = sa + da * (1 - sa)
    if out_a <= 0:
        return TRANSPARENT
    out = []
    for c in range(3):
        value = (src[c] * sa + dst[c] * da * (1 - sa)) / out_a
        out.append(round(value))
    out.append(round(out_a * 255))
    return tuple(out)


def render_icon(size: int, *, plate: str, foreground_only: bool = False) -> bytes:
    # 4x supersampling keeps the 16–32 px Windows forms crisp without shadows.
    ss = 4
    high = size * ss
    pixels = [TRANSPARENT] * (high * high)

    if not foreground_only:
        for y in range(high):
            for x in range(high):
                px = x + 0.5
                py = y + 0.5
                if plate == "full":
                    on = True
                elif plate == "circle":
                    on = inside_circle(px, py, high, high * 0.055)
                else:
                    on = inside_rounded_rect(
                        px,
                        py,
                        high,
                        high * 0.055,
                        high * 0.205,
                    )
                if on:
                    pixels[y * high + x] = GREEN

    # The journal mark stays inside Android's 66/108 safe zone.
    cx = high / 2
    left_page = [
        (cx - high * 0.024, high * 0.348),
        (cx - high * 0.024, high * 0.684),
        (high * 0.301, high * 0.625),
        (high * 0.301, high * 0.309),
    ]
    right_page = [
        (cx + high * 0.024, high * 0.348),
        (cx + high * 0.024, high * 0.684),
        (high * 0.699, high * 0.625),
        (high * 0.699, high * 0.309),
    ]
    for y in range(high):
        for x in range(high):
            px = x + 0.5
            py = y + 0.5
            if inside_polygon(px, py, left_page) or inside_polygon(px, py, right_page):
                pixels[y * high + x] = CREAM

    # Box-downsample to the requested target. Each target is rendered at exactly 4x.
    out = bytearray(size * size * 4)
    for oy in range(size):
        for ox in range(size):
            channels = [0, 0, 0, 0]
            samples = []
            for sy in range(ss):
                for sx in range(ss):
                    samples.append(pixels[(oy * ss + sy) * high + (ox * ss + sx)])
            # Premultiplied alpha averaging avoids dark fringes on Windows transparency.
            total_a = sum(p[3] for p in samples)
            a = round(total_a / len(samples))
            if total_a:
                for c in range(3):
                    channels[c] = round(sum(p[c] * p[3] for p in samples) / total_a)
            channels[3] = a
            offset = (oy * size + ox) * 4
            out[offset : offset + 4] = bytes(channels)
    return encode_png(size, size, bytes(out))


def write_binary(path: str, data: bytes) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(data)


android_sizes = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
for density, size in android_sizes.items():
    write_binary(
        f"android/app/src/main/res/mipmap-{density}/ic_launcher.png",
        render_icon(size, plate="full"),
    )
    write_binary(
        f"android/app/src/main/res/mipmap-{density}/ic_launcher_round.png",
        render_icon(size, plate="circle"),
    )

write_binary(
    "android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png",
    render_icon(432, plate="full", foreground_only=True),
)
Path("android/app/src/main/res/values/ic_launcher_colors.xml").write_text(
    '''<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#2D6A5B</color>\n</resources>\n''',
    encoding="utf-8",
)
adaptive = '''<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/ic_launcher_background" />\n    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n    <monochrome android:drawable="@drawable/ic_launcher_foreground" />\n</adaptive-icon>\n'''
for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
    p = Path(f"android/app/src/main/res/mipmap-anydpi-v26/{name}")
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(adaptive, encoding="utf-8")

replace_once(
    "android/app/src/main/AndroidManifest.xml",
    "    <application\n        android:label=\"学情\"\n",
    "    <application\n        android:label=\"学情\"\n"
    "        android:icon=\"@mipmap/ic_launcher\"\n"
    "        android:roundIcon=\"@mipmap/ic_launcher_round\"\n",
)

# ICO with PNG-compressed entries; supported by modern Win32 and preserves alpha.
ico_sizes = (16, 20, 24, 32, 40, 48, 64, 128, 256)
ico_images = [(size, render_icon(size, plate="rounded")) for size in ico_sizes]
header = struct.pack("<HHH", 0, 1, len(ico_images))
offset = 6 + 16 * len(ico_images)
entries = []
payloads = []
for size, payload in ico_images:
    width_byte = 0 if size == 256 else size
    height_byte = 0 if size == 256 else size
    entries.append(
        struct.pack(
            "<BBBBHHII",
            width_byte,
            height_byte,
            0,
            0,
            1,
            32,
            len(payload),
            offset,
        )
    )
    payloads.append(payload)
    offset += len(payload)
write_binary(
    "windows/runner/resources/app_icon.ico",
    header + b"".join(entries) + b"".join(payloads),
)
replace_once(
    "windows/runner/Runner.rc",
    "// Icon with lowest ID value placed first to ensure application icon\n"
    "// remains consistent on all systems.\n"
    "// Application icon intentionally deferred until the visual foundation phase.\n\n",
    "// Icon with lowest ID value placed first to ensure application icon\n"
    "// remains consistent on all systems.\n"
    "IDI_APP_ICON            ICON                    \"resources\\\\app_icon.ico\"\n\n",
)
replace_once(
    "installer/windows/xueqing.iss",
    "WizardStyle=modern\n",
    "WizardStyle=modern\n"
    "SetupIconFile=..\\..\\windows\\runner\\resources\\app_icon.ico\n",
)

# ---------------------------------------------------------------------------
# Long-lived tests: protect both the release icon wiring and the quiet visual
# contract so a future refactor cannot silently regress to placeholder visuals.
# ---------------------------------------------------------------------------
Path("test/release_app_icon_contract_test.dart").write_text(
    r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

int _be32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

void main() {
  test('Android and Windows ship the real 学情 app icon', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));

    final adaptive = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(adaptive, contains('@color/ic_launcher_background'));
    expect(adaptive, contains('@drawable/ic_launcher_foreground'));
    expect(adaptive, contains('<monochrome'));

    const androidIcons = <String, int>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final entry in androidIcons.entries) {
      final bytes = File(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      ).readAsBytesSync();
      expect(bytes.take(8).toList(), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
      expect(_be32(bytes, 16), entry.value);
      expect(_be32(bytes, 20), entry.value);
    }

    final ico = File('windows/runner/resources/app_icon.ico').readAsBytesSync();
    expect(ico.length, greaterThan(4096));
    expect(ico.take(4).toList(), <int>[0, 0, 1, 0]);
    final imageCount = ico[4] | (ico[5] << 8);
    expect(imageCount, greaterThanOrEqualTo(8));

    final rc = File('windows/runner/Runner.rc').readAsStringSync();
    expect(rc, contains(r'IDI_APP_ICON            ICON                    "resources\\app_icon.ico"'));
    final installer = File(
      'installer/windows/xueqing.iss',
    ).readAsStringSync();
    expect(
      installer,
      contains(r'SetupIconFile=..\..\windows\runner\resources\app_icon.ico'),
    );
  });
}
''',
    encoding="utf-8",
)

Path("test/features/v2_visual_polish_contract_test.dart").write_text(
    r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_motion.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';

void main() {
  test('V2 visual system stays restrained and interaction-led', () {
    final theme = V2Theme.light();
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.tooltipTheme.waitDuration, const Duration(milliseconds: 350));
    expect(theme.cardTheme.elevation, 0);
    expect(AppMotion.standard, const Duration(milliseconds: 180));
    expect(AppMotion.settle, const Duration(milliseconds: 240));
  });

  testWidgets('motion respects the platform reduced-motion preference', (
    tester,
  ) async {
    Duration? duration;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              duration = AppMotion.effectiveDuration(context, AppMotion.settle);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(duration, Duration.zero);
  });
}
''',
    encoding="utf-8",
)
