# Phase 0B.0-A｜Remote Supabase Security Spike

## Purpose

This runbook is the remote counterpart to the local Supabase checks already in
this repository. It answers whether the current provider-neutral identity and
assignment boundary survives a real Supabase Data API/Auth deployment.

It is a development verification harness, not a production deployment plan.

## Scope boundary

The remote target must be a disposable Supabase development project containing
fictional data only. The spike covers only:

- `organizations`;
- `app_users`;
- `memberships`;
- `students`;
- `teacher_assignments`;
- Password Auth, REST/Data API, RLS, logout and live-session checks.

It does not create or test Learning Cases, Lessons, Evidence, Assessments,
Actions, parent communication, AI, Storage or production data.

## Safety gates

The script refuses to run unless all of these are true:

1. `XUEQING_SPIKE_CONFIRM_DEV_ONLY=YES` is explicitly set;
2. the expected project ref is supplied;
3. the HTTPS URL host exactly matches that project ref;
4. only a publishable/anon key is supplied to the client-side test;
5. all three accounts are fictional fixture accounts.

Access tokens are held in process memory and are never written to a file or
printed. The test output contains only pass/fail messages and HTTP status
codes.

Do not point this harness at a project whose purpose or data is uncertain. In
particular, do not use `supabase db reset --linked` unless the target has been
independently confirmed to be throwaway development infrastructure; that
command is destructive.

## Prepare a dedicated development target

Use a clearly identified development project or branch. Confirm the project
ref, region and plan in the Supabase dashboard before applying anything.

From a clean checkout, use the reviewed migration workflow:

```bash
supabase login
supabase link --project-ref <fictional-dev-project-ref>
supabase db push --dry-run
supabase db push --include-seed
```

`--include-seed` is allowed here only because the target is a fresh,
fictional-data development project. Never use it for production.

If the remote project already contains unknown schema or data, stop. Do not
pull it into this repository and do not overwrite it as part of this spike.

## Run the remote security harness

Inject the values through an ephemeral shell, a local secret manager, or the
manual GitHub Actions workflow. Do not commit them or put them in a tracked
file.

```bash
export XUEQING_SPIKE_CONFIRM_DEV_ONLY=YES
export XUEQING_SPIKE_PROJECT_REF=<fictional-dev-project-ref>
export XUEQING_SUPABASE_URL=https://<fictional-dev-project-ref>.supabase.co
export XUEQING_SUPABASE_PUBLISHABLE_KEY=<publishable-or-anon-key>
export XUEQING_SPIKE_TEACHER_A_EMAIL=<fictional-teacher-a-email>
export XUEQING_SPIKE_TEACHER_A_PASSWORD=<fictional-teacher-a-password>
export XUEQING_SPIKE_TEACHER_B_EMAIL=<fictional-teacher-b-email>
export XUEQING_SPIKE_TEACHER_B_PASSWORD=<fictional-teacher-b-password>
export XUEQING_SPIKE_NO_MEMBERSHIP_EMAIL=<fictional-no-membership-email>
export XUEQING_SPIKE_NO_MEMBERSHIP_PASSWORD=<fictional-no-membership-password>

bash supabase/tests/remote_security_spike.sh
```

The fixture names and expected student IDs are intentionally tied to the
repository's fictional `supabase/seed.sql`. If a remote target uses different
fixtures, change the development fixture deliberately and update both the
seed and the test in the same reviewed change; do not weaken the assertions.

## Automated checks performed

The harness verifies:

| Check | Expected result |
| --- | --- |
| Teacher A identity | Resolves only to the matching `app_users` row |
| Teacher A membership | One active membership in Organization A |
| Teacher A assignment | One active assignment to Student A |
| Teacher A student read | Student A is visible |
| Teacher A cross-student read | Student B returns no rows or an authorization error |
| Teacher A cross-organization read | Organization B returns no rows or an authorization error |
| Teacher B boundary | Symmetric access to Student B only |
| No-membership user | No membership, organization or student rows |
| Old Teacher A token | After logout, no protected rows are returned |

The old-token assertion accepts either `401/403` or `200` with an empty result
set. The latter is a valid pass for this schema: the transport can still parse
the JWT while the live-session RLS helper refuses to resolve the business
identity. It proves business-data denial, not that every Supabase edge layer
immediately rejects the JWT.

## Flutter device gate

After the remote harness passes, run the existing Cloud Connection Test page on
both target form factors with the same remote development configuration:

```bash
flutter run -d windows \
  --dart-define=XUEQING_SUPABASE_URL=https://<fictional-dev-project-ref>.supabase.co \
  --dart-define=XUEQING_SUPABASE_PUBLISHABLE_KEY=<publishable-or-anon-key>

flutter run -d <android-device> \
  --dart-define=XUEQING_SUPABASE_URL=https://<fictional-dev-project-ref>.supabase.co \
  --dart-define=XUEQING_SUPABASE_PUBLISHABLE_KEY=<publishable-or-anon-key>
```

Open `Cloud Spike` from the bootstrap page and verify:

- login succeeds;
- the displayed user, organization, role and accessible student count are
  correct;
- killing and reopening the app restores the session without asking for the
  password again;
- global logout clears the session and the summary;
- no password, service-role key or token is placed in ordinary preferences or
  application logs.

The existing Flutter implementation uses `flutter_secure_storage` through
Supabase's `LocalStorage` boundary. The device restart and storage checks still
require execution on the actual Windows and Android targets; a Linux CI build
cannot establish them.

## Evidence to record

For a completed gate, record only non-secret evidence:

- repository commit SHA and workflow run URL;
- remote project ref, region and plan;
- migration push result;
- remote harness result;
- Windows result;
- Android result;
- session restore and logout result;
- any provider or network limitation.

Do not record API keys, access tokens, passwords, database passwords or real
student information.

## Decision rule

Phase 0B.0-A is complete only when the local database tests, remote harness and
both device checks pass. Until then:

- no production migration;
- no production Auth or real student data;
- no Learning Case or Lesson implementation is authorized by this runbook.

Once the gate passes, stop the spike and begin the separately scoped
Phase 0B.0-B Identity & Learning Data Foundation work.
