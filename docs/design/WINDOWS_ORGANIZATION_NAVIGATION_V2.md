# Windows Organization Navigation v2

This document records the accepted presentation contract for the Windows organization workspace.

## Information architecture

Windows projects the existing Organization state as peer destinations in the left navigation rail:

- Organization Learning / supervision
- Members
- Students
- Settings

This is a presentation projection, not a new business hierarchy. `V2OrganizationSection` remains the higher-level Learning / Management state, while `OrganizationManagementArea` identifies Members / Students / Settings inside Management.

Android Compact keeps the layered presentation: enter Organization from More, then switch between Learning and Management, with Members / Students / Settings inside Management.

## Desktop behavior

- Expanded Windows navigation uses a restrained 192px sidebar at the existing expanded-rail breakpoint.
- Medium Windows keeps the icon rail.
- Main destinations can scroll vertically on short windows while refresh and More remain pinned.
- The footer command is named `更多`, because it opens the workspace More menu rather than an application-settings page.
- Icon-only tooltips are scope explicit: for example `我的学生`, `机构学情监督`, `机构成员`, `机构学生`, `机构设置`.
- Embedded Organization Management hides its duplicate area switcher because the outer Windows rail already owns those destinations.
- Compact and standalone Organization pages retain the area switcher so Members / Students / Settings are never made unreachable.
- Members / Students / Settings keep independent scroll positions while sharing one management snapshot.
- Management onboarding and export actions stay contextual to the active peer destination.

## State and safety boundaries

- Workspace navigation state remains above adaptive presentation.
- Organization management keeps one management surface and one repository snapshot; Windows does not create separate management page instances for each peer destination.
- Refresh, resize, and Learning / Management round trips preserve the established management area.
- No Supabase, RLS, RPC, role, responsibility, Case ownership, or write-command semantics are changed by this navigation work.

## Verification gate

The implementation is accepted only when all of the following pass on the stacked branch:

- `dart format` for touched Dart files;
- `flutter analyze`;
- focused Windows / Organization / adaptive navigation tests;
- the complete `flutter test` suite.

Real-device / desktop acceptance should still cover short window heights, Windows scaling, keyboard focus, Android edge Back, and cross-scope return continuity before release promotion.
