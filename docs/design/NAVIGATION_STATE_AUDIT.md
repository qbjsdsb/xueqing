# V2 Navigation State Continuity Audit

Date: 2026-09-13

## Problem

Compact and Medium previously owned `studentOpen` inside their local widget State. When a Windows window crossed a responsive boundary, Flutter replaced one shell with another and that local drill-down state disappeared even though the selected student remained valid.

This made resize behave like accidental navigation. A teacher could be reading a student, resize the window, and land back on the student list.

## Contract

Meaningful navigation state belongs above adaptive presentation.

- destination, selected student, selected case, case-detail state and student-detail state are workspace state;
- Compact / Medium / Expanded only decide how that state is presented;
- explicit student selection opens student detail;
- resizing does not itself navigate backward;
- system back and the explicit back button still close student detail before leaving Students;
- on Medium, selecting the already-active Students rail destination remains a deliberate shortcut back to the list;
- opening a Case from Today / Learning does not invent a hidden Student-detail history entry.

## Frozen boundaries

No data projection, permissions, responsibility, write command, Supabase or Organization behavior changes.

## Organization scope continuity

For a manager who also teaches, the embedded Organization workspace is one continuous supervisory work surface even when the outer Personal shell changes between Compact, Medium and Expanded.

- the current Organization section (Learning / Management) must survive resize;
- Learning search text and attention filter must survive resize;
- the selected student in expanded supervision must survive a round trip through a narrower shell;
- preserving these presentation states must not change Personal responsibility, Organization authority, Case owner, Profile Lead, or write semantics.

The loader therefore gives the embedded Organization workspace a stable identity across adaptive shell replacement. Window width may change presentation, but it must not recreate the supervisor's current working context.
