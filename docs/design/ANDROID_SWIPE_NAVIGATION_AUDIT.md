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
- The root pager does not install a competing custom edge gesture recognizer; Android system Back keeps platform priority. Edge behavior remains a real-device acceptance gate.
- Page swipe is disabled while the soft keyboard is visible.
- One committed gesture moves at most one destination.
- There is no circular wrap from Today to Learning or Learning to Today.
- Android predictive Back is explicitly enabled in the manifest and existing `PopScope` hierarchy remains authoritative for Back behavior.

## Motion

Root destination swipes use direct manipulation: content tracks the finger through `PageView` and settles with platform paging physics. Bottom-navigation taps jump directly to the selected peer without animating through intermediate destinations. The root pager suppresses only its own overscroll indicator; inner lists keep platform scrolling behavior.

## State continuity

The Personal root pager stays mounted while Student detail, Case detail, or the embedded Organization workspace is in the foreground. Today / Students / Learning therefore retain their local search and scroll state instead of being rebuilt as a side effect of drill-down navigation. Workspace destination remains the canonical navigation state above the adaptive Compact presentation.

## Non-goals

This change does not alter:

- Personal / Organization scope semantics;
- Case / Student drill-down history;
- role or responsibility semantics;
- Supabase, RLS, RPC, or persistence;
- Medium / Expanded navigation;
- Windows interaction patterns.
