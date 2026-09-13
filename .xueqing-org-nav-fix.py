from pathlib import Path
import re

areas_path = Path('lib/features/organization_management/presentation/organization_management_areas.dart')
areas = areas_path.read_text(encoding='utf-8')
areas = areas.replace('OrganizationManagementAreaCard', '_ManagementAreaCard')
areas_path.write_text(areas, encoding='utf-8')

layout_path = Path('lib/features/organization_management/presentation/organization_management_layout.dart')
layout = layout_path.read_text(encoding='utf-8')
layout, count = re.subn(r'\b_ManagementArea\b', 'OrganizationManagementArea', layout)
if count == 0:
    raise SystemExit('no management area type references found in layout')
layout_path.write_text(layout, encoding='utf-8')
