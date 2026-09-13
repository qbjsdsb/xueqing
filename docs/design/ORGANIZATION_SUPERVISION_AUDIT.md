# Organization Supervision Layout Audit

Date: 2026-09-13

## Goal

Organization Learning is a supervision workbench, not a KPI dashboard and not a long accordion report.

The primary hierarchy remains:

**Student → Subject → active Learning Case → Responsible Teacher → Next Action**

## Adaptive contract

- Compact `<600`: one stacked supervision list; student rows expand in place.
- Medium `600–1023`: one stacked supervision work surface beside the rail.
- Expanded local pane `>=1024`: student list on the left, selected student supervision detail on the right.

The split decision is based on the Organization Learning pane's real local constraints, not the physical device type.

## Expanded supervision rules

1. Search and attention filters stay with the student index.
2. Selecting a student changes the detail pane; it does not create a new route or responsibility state.
3. Quick Capture is attached to the selected student detail rather than repeated across every visible row.
4. Student detail exposes subject/Lead facts before cases, then current cases, then history.
5. Existing Case owner remains authoritative. Profile Lead is only the responsibility source for creating a new Case.
6. Organization actions never auto-assign the manager as teacher.

## Visual intent

- Use whitespace, alignment, dividers and typography before containers.
- Selection may use a very low-alpha primary surface; cases remain text-first.
- No KPI cards, no dashboard tile grid, no repeated action wall.
- Wide space should express relationships rather than stretching one accordion list across the window.

## Frozen business boundaries

This layout does not change RLS, permissions, Personal projection, Case owner, Profile Lead, Action assignee, Quick Capture fail-closed behavior, or historical continuity.
