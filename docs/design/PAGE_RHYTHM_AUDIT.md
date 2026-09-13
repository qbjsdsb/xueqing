# V2 Page Rhythm Audit

Date: 2026-09-13

## Why this layer exists

The adaptive workspace contract fixes **where** the app changes structure. This document fixes **how a page begins** once that structure has been chosen.

Before Organization features were integrated, V2 pages largely started inside one quiet content surface: title, small context, the work itself. Later Organization integration introduced a second visual grammar: AppBar, a separate section-switch strip, then the page content. On compact manager accounts Personal also gained a permanent scope strip above the page.

Those additions were functionally valid, but they made the product feel like different applications stitched together.

## Frozen page-rhythm contract

Top-level V2 workspaces use one editorial content header:

- headline first;
- small neutral context second;
- restrained actions beside or directly below the title block;
- a local section switch may appear as the header footer;
- no card or colored banner is used only to announce the current page;
- a nested workspace must not add a second AppBar when the parent shell already defines navigation.

This contract applies to:

- Personal / 今日;
- Personal / 学生;
- Personal / 学情;
- Organization / 学情;
- Organization / 管理.

## Personal vs Organization

The visual unification does **not** merge the two scopes.

Personal remains the default teaching workspace. Compact Personal keeps exactly three bottom destinations: 今日 / 学生 / 学情. A manager-teacher reaches Organization through a quiet header action; Organization is not added as a fourth bottom-navigation item.

Organization remains a separate supervision scope. On compact embedded layouts it exposes an explicit back-to-Personal affordance. System back keeps the same semantic order: Management → Organization Learning → Personal.

## Organization header

Organization no longer needs a permanent nested AppBar plus a second switch strip. Its page header owns:

- title: 机构;
- organization name and current management role as metadata;
- a short scope description;
- refresh / update / sign-out actions when allowed;
- the 学情 / 管理 section switch as a local footer.

The business authority model is unchanged. This is a presentation-layer change only.

## Embedded management

When Organization Management is embedded under the Organization header, it must not repeat the organization name / role identity block. Standalone management may still show its own title and identity because it has no parent Organization header.

Embedded Organization Learning and Management share the same centered content width and horizontal rhythm so switching sections feels like changing the work, not changing applications.

## Review matrix

| Surface | Compact | Medium | Expanded |
| --- | --- | --- | --- |
| Personal top-level | editorial header + bottom nav | editorial header + rail | editorial header + rail |
| Organization | editorial header + visible return to Personal | editorial header inside rail shell | editorial header inside rail shell |
| Management embedded | no duplicate identity/header | no duplicate identity/header | no duplicate identity/header |
| Local section switch | header footer | header footer | header footer |
| Modal choice | Bottom Sheet | Dialog | Dialog |

## Non-goals

This layer does not change Supabase, RLS, role permissions, Personal/Organization projection, Case ownership, Profile Lead, Action assignment, actor attribution, Today buckets, or write responsibility.
