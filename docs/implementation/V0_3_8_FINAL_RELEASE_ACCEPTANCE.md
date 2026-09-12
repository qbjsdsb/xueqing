# Xueqing v0.3.8 Final Release Acceptance

This file records the final acceptance boundary for v0.3.8. It is not a new product specification.

## Release scope

v0.3.8 closes the responsibility/supervision split and releases the already-reviewed Windows installer improvements. The final hardening branch is intentionally limited to:

- version `0.3.8+16`;
- an additive backend compatibility marker that proves the organization Profile → active Lead responsibility read model exists before a stable client is released;
- organization learning search that matches the current responsible teacher even when the student has no Case yet;
- a visible expansion affordance while preserving the separate “记录问题” action;
- behavior-equivalent organization-list lookup indexing to avoid repeated per-row rescans.

## Performance acceptance

Performance work in this release MUST NOT change authorization, persistence, ordering, teacher responsibility, navigation, refresh semantics, or the visible result set.

Verified architecture already retained:

- workspace data sets are loaded concurrently rather than per student;
- returned child rows are indexed once before workspace assembly;
- repeated soft refresh requests are coalesced;
- evidence image decoding/resizing/compression runs off the UI isolate;
- batch export keeps bounded concurrency.

The only final UI performance change precomputes immutable lookup maps once per organization-learning build instead of rescanning the same profiles/Cases for every rendered row.

## Stable release gates

Before publishing stable `v0.3.8`, require all of the following on the final main commit:

1. Dart format and Flutter analyze;
2. complete Flutter test suite;
3. Supabase full migration reset and pgTAP/RLS tests;
4. old-token security regression;
5. Android build smoke;
6. Windows release bundle, updater helper, installer build, in-place upgrade/task-preservation and uninstall smoke;
7. production backend compatibility reports all capabilities required by the release workflow;
8. release assets and update manifest are internally consistent.

No stable release is accepted from a partially compatible production backend.
