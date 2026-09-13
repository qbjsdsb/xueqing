# Android Compact Root Swipe Navigation Audit

## Intent

Android Compact adds horizontal swipe as a convenience gesture for the three Personal root destinations only:

- Today
- Students
- Learning

Bottom Navigation remains the visible and authoritative navigation control. Swipe never replaces it.

## Safety boundaries

- Android only.
- Compact layout only.
- Root Personal destinations only.
- Student detail, Case detail, and Organization do not participate.
- The system gesture edge insets are excluded from page swipe handling so Android Back keeps priority.
- Page swipe is disabled while the soft keyboard is visible.
- One committed gesture moves at most one destination.
- There is no circular wrap from Today to Learning or Learning to Today.
- Android predictive Back is explicitly enabled in the manifest and existing `PopScope` hierarchy remains authoritative for Back behavior.

## Motion

Root destination changes use the existing short motion token and a restrained fade / very small horizontal translation. There are no spring, overshoot, glow, gradient, or decorative navigation effects.

## Non-goals

This change does not alter:

- Personal / Organization scope semantics;
- Case / Student drill-down history;
- role or responsibility semantics;
- Supabase, RLS, RPC, or persistence;
- Medium / Expanded navigation;
- Windows interaction patterns.
