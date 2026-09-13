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

Switching between Organization Learning and Management is also presentation/workspace navigation, not a request to clear the supervisor's Learning context. Learning search, attention filter and selected student remain alive while Management is visited. Management is initialized lazily on first entry so preserving state does not add eager management work to the default Learning view.

## Organization refresh coherence

The Organization header owns the visible scope-level refresh action. Once Management has been activated, that refresh must reload both the outer Organization projection and the management repository snapshot without recreating the manager's local working context.

- embedded Management does not show a duplicate refresh button;
- while Organization is selected on Medium/Expanded, the Personal rail yields refresh ownership to the Organization header instead of exposing a second refresh path;
- the outer refresh increments an explicit management refresh revision only after Management has been activated;
- `OrganizationManagementPage` reloads its snapshot when that revision changes, while its `_ManagementOverview` state (active area, student search, history disclosures) remains mounted;
- Management remains lazy before first entry, so a supervisor who only uses Organization Learning does not pay management-loading cost;
- refresh semantics do not alter responsibility, permissions, case ownership or write attribution.

## Truthful Organization refresh feedback

The explicit Organization refresh path is awaitable and separate from mutation notifications.

- `onRefresh` is reserved for the user-triggered scope refresh and owns visible pending feedback;
- `onChanged` remains a fire-and-forget mutation notification after committed writes;
- while a manual Organization refresh is pending, the header keeps the refresh control in place, replaces its glyph with a small progress indicator, and disables repeat taps;
- refresh failure messaging continues to come from the shared loader soft-refresh boundary, while current content remains visible.
- callers that arrive during an in-flight soft refresh join the same coalesced cycle and only complete after queued reloads drain; failure feedback reflects the final attempt in that cycle rather than a stale intermediate failure.

## Cross-scope visit continuity

Opening Organization is a temporary change of work scope, not navigation inside Personal. A manager-teacher should therefore return to the Personal location they deliberately left.

- entering Organization remembers the current Personal destination;
- Personal student/case drill-down state may stay dormant while Organization is visible;
- returning from Organization restores that Personal destination and still-valid detail/case context;
- explicitly choosing a different Personal rail/bottom destination remains real navigation and clears drill-down state by the existing rules;
- if refreshed data invalidates the selected student/case, normal reconciliation still fails safe instead of reviving stale context.

Adaptive shells must ignore dormant Personal detail flags while Organization is the active destination. Both `canPop` and the pop callback must use the same visible-destination guard, so one system-back gesture cannot be consumed once by Organization and again by hidden Personal history.


## Navigation simplification after v0.3.10

Organization is a work scope, not a fourth Personal page. Personal continues to own Today / Students / Learning. On Compact, managers enter Organization from the More menu instead of repeating an Organization action in every page header. On Medium/Expanded, the rail exposes an Organization group with Learning supervision and Management as sibling sub-destinations. The embedded Organization header therefore does not repeat the desktop section switch.

The existing cross-scope continuity contract remains unchanged: returning from Organization restores the Personal destination and any still-valid student/case drill-down state.


## Organization management area continuity

Members / Students / Settings is now explicit Organization workspace navigation state instead of private state owned only by the Management body. The Management body still chooses its existing setup-aware initial area when no area has been established, then reports that resolved area upward. Refresh and Learning / Management round trips therefore preserve the manager's current area without changing Organization authority, teaching responsibility, or persistence semantics.
