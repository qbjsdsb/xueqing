# Organization Management Density Audit

Date: 2026-09-13

## Problem

After the shared visual, adaptive, and page-rhythm layers were unified, Organization Management still retained a few older Material-heavy patterns: every data row looked like a small card, role/status metadata was rendered as full `Chip` components, member initials used a strong primary-colored avatar, and setup guidance used a broad primary-tinted banner.

None of these patterns were individually wrong, but together they made the management surface feel denser and more SaaS-like than the Personal and Organization Learning workspaces.

## Contract

Organization Management should remain operationally dense without becoming visually loud.

- **Rows are information, not cards.** Repeated members, students, assignments, and scopes use quiet list rows separated by thin dividers rather than a rounded surface for every record.
- **Metadata is metadata.** Roles, grade/class details, and ordinary status labels use compact custom labels; they do not need the padding and visual weight of Material `Chip` components.
- **State may keep restrained color.** Positive/negative state can use a very light semantic tint, but role or identity metadata stays neutral.
- **One next step may stand out.** Setup guidance remains actionable, but emphasis comes from a slim semantic edge and typography, not a large green block.
- **Actions stay near the object they affect.** This pass does not hide lifecycle, handoff, invite, export, or setup actions merely to make the page look sparse.

## What stays unchanged

This is a presentation-only density pass. It does not change:

- Owner / Admin / Teacher authority;
- member provisioning or invitation behavior;
- student lifecycle or teaching pause/resume;
- subject service lifecycle;
- Profile Lead, teacher assignment, or handoff semantics;
- Case type management;
- exports;
- Supabase, migrations, RPC, or RLS.

## Visual acceptance

A management page should read in this order:

1. current area and its short explanation;
2. the records themselves;
3. small metadata/state facts;
4. relevant local actions.

The eye should not first see a wall of rounded rectangles and colored pills.
