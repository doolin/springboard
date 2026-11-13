# INC-2026-05-12-002 — Pipeline gate disabled for 16 days during a CI budget freeze

**Status:** Closed — settings restored 2026-05-28; this report written retroactively on 2026-11-13
**Window:** 2026-05-12 (between 21:48 and 22:35 UTC) to 2026-05-28
**Severity:** Medium — a documented compensating measure was not in force; no security-boundary impact found
**Authoring agent:** Ron (security and compliance persona, Straylight family) running on Claude Fable 5.2 (Claude Code)
**Authorizing Official (interim):** maintainer (`doolin`)
**Incident ticket:** [SB-GL-65](https://gitlab.com/doolin/springboard/-/work_items/65)

---

## Summary

On 2026-05-12 the project exhausted its GitLab.com compute minutes. To
stop further consumption and keep work moving, two project settings
were changed:

| Setting | Before | During the window | Now (checked 2026-11-13) |
|---|---|---|---|
| `shared_runners_enabled` | `true` | `false` | `true` |
| `only_allow_merge_if_pipeline_succeeds` | `true` (set by [SB-GL-23](https://gitlab.com/doolin/springboard/-/work_items/23)) | `false` | `true` |

`only_allow_merge_if_all_discussions_are_resolved` and
`allow_merge_on_skipped_pipeline` were not changed.

For 16 days, merges to `master` were not bound by configuration to a
successful GitLab pipeline, and GitLab produced no evidence bundle for
the commits that landed. Seventeen commits reached `master` in that
state. Fourteen of them have a successful run of the GitHub pipeline
(the downstream mirror runs the same gates); three do not.

The deviation was recorded at the time only in agent session notes.
This report is the in-repository record.

## How this was reconstructed

Sources, all read on 2026-11-13:

- **GitLab pipelines API** for `master`, 2026-05-11 to 2026-06-01
  (`GET /projects/doolin%2Fspringboard/pipelines?ref=master`).
- **GitHub Actions run list** for `master`, 2026-05-12 to 2026-05-29
  (`gh run list --branch master`).
- **Current GitLab project settings**
  (`GET /projects/doolin%2Fspringboard`).
- **Agent session notes** from May 2026 for the two setting changes,
  their dates, and the restoration. These statements are marked
  *(session notes)* below. GitLab's audit events for project-setting
  changes were not consulted, so the exact times of the two changes
  are not established here.

## Timeline (UTC)

| Time | Event | Source |
|---|---|---|
| 2026-05-12 21:48 | Last successful GitLab pipeline on `master` before the window ([2520486812](https://gitlab.com/doolin/springboard/-/pipelines/2520486812), `e56feb6`) | pipelines API |
| 2026-05-12 | Compute minutes exhausted; both settings changed; two running branch pipelines canceled | *(session notes)* |
| 2026-05-12 22:34 | Pipeline [2520575738](https://gitlab.com/doolin/springboard/-/pipelines/2520575738) created for `665cf5d`; it never received a runner and was marked failed at 2026-05-13 00:41 | pipelines API |
| 2026-05-13 to 2026-05-17 | Thirteen further commits land on `master`; GitLab creates three pipelines, all failed | pipelines API |
| 2026-05-28 | Both settings restored | *(session notes)* |
| 2026-05-28 22:08 | First successful GitLab pipeline after the window ([2560304137](https://gitlab.com/doolin/springboard/-/pipelines/2560304137), `ad72e00`) | pipelines API |
| 2026-11-13 | Settings confirmed at their documented values; this report written | project API |

## Commits that landed without a successful GitLab pipeline

Listed oldest first. "none" means GitLab created no pipeline for that
commit.

| Commit | Work item | GitLab pipeline | GitHub pipeline (`CI/CD`) |
|---|---|---|---|
| `72527e6` | SB-GL-24 | canceled ([2520563487](https://gitlab.com/doolin/springboard/-/pipelines/2520563487)) | failure |
| `06944f1` | SB-GL-42 | canceled ([2520572961](https://gitlab.com/doolin/springboard/-/pipelines/2520572961)) | no run |
| `1927aa5` | SB-GL-9 | canceled ([2520574274](https://gitlab.com/doolin/springboard/-/pipelines/2520574274)) | no run |
| `665cf5d` | SB-GL-7 | failed ([2520575738](https://gitlab.com/doolin/springboard/-/pipelines/2520575738)) | success |
| `5c20b0a` | SB-GL-2 | none | success |
| `cca1aa2` | SB-GL-46 | none | success |
| `9171f2a` | SB-GL-45 | none | success |
| `bc7a997` | SB-GL-26 | none | success |
| `2fef75c` | SB-GL-27 | none | success |
| `57ce8ed` | SB-GL-28 | failed ([2522770653](https://gitlab.com/doolin/springboard/-/pipelines/2522770653)) | success |
| `4c3b181` | SB-GL-47 | none | success |
| `ffdba12` | SB-GL-48 | none | success |
| `8e60aed` | SB-GL-49 | none | success |
| `4c56e58` | SB-GL-51 | none | success |
| `285c749` | SB-GL-50 | none | success |
| `92303a8` | SB-GL-29 | failed ([2523957112](https://gitlab.com/doolin/springboard/-/pipelines/2523957112)) | success |
| `92aa25e` | SB-GL-52 | failed ([2531987617](https://gitlab.com/doolin/springboard/-/pipelines/2531987617)) | success |

Notes on the table:

- The three canceled pipelines were each superseded within a minute by
  the next push (the project auto-cancels pending pipelines). They are
  included because no later GitLab pipeline succeeded on a tree that
  contains them until 2026-05-28.
- The jobs of one failed pipeline (2523957112) were inspected: its
  first job failed with `stuck_pending_no_matching_runners` and the
  rest were skipped. That is the expected result of disabled shared
  runners. The other three failed pipelines were not inspected job by
  job.
- `06944f1` and `1927aa5` have no GitHub run of their own. They were
  pushed together with `665cf5d`, whose successful GitHub run tested a
  tree that includes both.
- `72527e6` has a failed GitHub run. The cause was not examined. The
  next GitHub run on a tree containing it (`665cf5d`) succeeded.

## Impact

- **AC-5 compensating measure 1 was not in force.** `SECURITY.md`
  describes merges to `master` as bound to pipeline success by
  configuration. During the window that binding was off; merges were
  gated by maintainer review only, the convention-enforced form that
  existed before SB-GL-23.
- **GitLab evidence gap.** No GitLab evidence bundle (OSCAL assessment
  results, SBOM, scan results, audit events, evidence manifest,
  attestation) exists for the 17 commits above. The statement in
  `SECURITY.md` that every commit on `master` produces a full evidence
  bundle does not hold for them on the primary forge.
- **Partial substitute.** The GitHub pipeline ran the same gates and
  succeeded on 14 of the 17 commits, including the head of the window
  (`92aa25e`). Its artifacts are retained for 90 days and have expired;
  whether copies exist in the S3 compliance bucket was not checked.
- **Content of the changes.** The window includes the CVE suppression
  and remediation series (SB-GL-26 to SB-GL-29, SB-GL-47 to SB-GL-51)
  and the coverage-floor enforcement (SB-GL-2). All of it has since
  been through successful GitLab pipelines as part of later trees,
  starting with `ad72e00` on 2026-05-28. No defect attributable to the
  window has been found.
- **No security-boundary impact identified.** No access control was
  bypassed and no secret was exposed. The incident is a gap in
  enforcement and in evidence, bounded to 16 days.

## Root cause

**Direct cause.** The GitLab.com compute-minute quota ran out. With
shared runners unable to run and the merge gate requiring a successful
pipeline, no merge request could be merged. Disabling the gate was the
only way to continue without buying minutes or attaching a runner.

**Contributing factors.**

1. *Pipeline cost was unmanaged.* The GitLab project was created on
   2026-05-11. On 2026-05-12 the pipeline ran its full job graph on
   every push, and some pushes created several pipelines each (five
   for `ebe6916` alone). The quota was gone by the end of that day.
2. *No fallback runner.* The project depends entirely on GitLab.com
   shared runners. There is no project runner that would keep the gate
   enforceable when the shared quota is exhausted.
3. *The deviation was not recorded where an assessor would look.* It
   was written to agent session notes, with a reminder to file this
   report after restoration. The report was not filed, and the project
   then sat idle for five months.

## Remediation

**Done.**

- Settings restored on 2026-05-28 *(session notes)*; confirmed at
  `shared_runners_enabled: true`,
  `only_allow_merge_if_pipeline_succeeds: true`,
  `allow_merge_on_skipped_pipeline: false` on 2026-11-13.
- Pipeline cost reduced after restoration: `interruptible` defaults
  ([SB-GL-55](https://gitlab.com/doolin/springboard/-/work_items/55))
  and lockfile-keyed caches
  ([SB-GL-54](https://gitlab.com/doolin/springboard/-/work_items/54)).
- This report, and a pointer to it from `SECURITY.md`.
- Path filters on merge request pipelines
  ([SB-GL-56](https://gitlab.com/doolin/springboard/-/work_items/56),
  merged 2026-11-13): a documentation-only merge request runs two
  jobs instead of nine, and a backend-only one skips e2e. Pipelines
  on `master` still run every job. Backend and frontend tests are
  still one job, so a frontend-only change does not skip the backend
  build.
- CI image audit
  ([SB-GL-57](https://gitlab.com/doolin/springboard/-/work_items/57),
  merged 2026-11-13): every image is pinned by digest. No slimmer
  image could be swapped in, so this did not reduce minutes.

**Open.**

- No fallback runner exists. If the quota runs out again, the same
  choice between stopping work and disabling the gate will recur.
- The GitLab evidence for the 17 commits cannot be regenerated as it
  would have been at the time; scanner databases and dependency
  advisories have moved on. The gap stands as recorded here.

## If the quota runs out again

The gate SHOULD stay on. If the maintainer, acting as interim AO,
decides to disable it:

1. Record the decision, the time and the two setting values in a work
   item on the day it happens, not afterwards.
2. Keep pushing to the GitHub mirror so its pipeline runs on every
   commit, and download its evidence artifacts before the 90-day
   retention ends.
3. On restoration, confirm the settings through the project API,
   confirm that a failing pipeline blocks a merge, and file the
   incident report in the same session.

## Control mapping

| Control | Relevance |
|---|---|
| [NIST SP 800-53 Rev. 5 AC-5](https://doi.org/10.6028/NIST.SP.800-53r5) — Separation of Duties | The configuration-bound merge gate is compensating measure 1 for AC-5 in `SECURITY.md`; it was off for the window. |
| [SP 800-53 CM-3](https://doi.org/10.6028/NIST.SP.800-53r5) — Configuration Change Control | Changes were merged without the automated gate; commit-to-ticket traceability (the `SB-GL-` prefix) held throughout, as the table shows. |
| [SP 800-53 CA-7](https://doi.org/10.6028/NIST.SP.800-53r5) — Continuous Monitoring | Per-commit evidence generation on the primary forge stopped for 16 days. |
| [SP 800-53 SI-7](https://doi.org/10.6028/NIST.SP.800-53r5) — Software, Firmware, and Information Integrity | No anchored evidence bundle exists on GitLab for the 17 commits. |
| [SP 800-53 IR-5](https://doi.org/10.6028/NIST.SP.800-53r5) — Incident Monitoring | This report documents the deviation; it was written five months late. |
| [SP 800-37 Rev. 2](https://csrc.nist.gov/pubs/sp/800/37/r2/final) — RMF Step 7 (Monitor) | The report is continuous-monitoring evidence for the authorization package. |

## References

- Earlier incident the same day:
  [INC-2026-05-12-001](./2026-05-12-001-duplicate-work-items.md)
- Merge-gate configuration:
  [SB-GL-23](https://gitlab.com/doolin/springboard/-/work_items/23)
- Posture text affected:
  [`SECURITY.md`, AC-5 — Separation of duties](../../../SECURITY.md#ac-5--separation-of-duties)
- This incident's authorizing record:
  [SB-GL-65](https://gitlab.com/doolin/springboard/-/work_items/65)

## Sign-off

This report serves as the interim AO acknowledgment that the deviation
occurred, that its extent was reconstructed from forge records, and
that the evidence gap is accepted as recorded. A future Authorize-step
assessment SHALL include this report in the system's authorization
package.

---

*Authored 2026-11-13 by Ron via Claude Fable 5.2 (Claude Code), for review by the interim AO (`doolin`).*
