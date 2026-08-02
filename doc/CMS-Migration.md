# CMS → cafe-grader Migration (c2.thailandoi.org)

**Goal.** Move the task archive on the CMS server `c2.thailandoi.org` into
cafe-grader, ending on a **production** cafe server. Repeatable and reusable —
this is a migration we expect to re-run (new tasks appear on c2; other CMS
instances may follow), not a one-off copy.

**Status: 1 of 95 transferable tasks cloned (to dev).** Pipeline built and
validated end-to-end on that one task. Bulk clone and the Tier-1 validation
sweep are the current work. Nothing has been imported to production yet.

Related documents:
- Design: `docs/superpowers/specs/2026-08-02-cms-clone-import-design.md`
- Plan: `docs/superpowers/plans/2026-08-02-cms-clone-import.md`
- Earlier interop design (Italian/TPS packages, CMS export, replay modes):
  `doc/problem-import-export-design-2026-07-14.md`
- Open items: `doc/backlog.md` → "Import/Export & CMS interop"

---

## 1. Inventory (surveyed 2026-08-02 against the live server)

c2 holds **112 tasks** (107 in the `practice` contest), **24,589 submissions**,
60 GB of CMS database. Of those tasks:

| | tasks | testcases | submissions |
|---|---|---|---|
| **Transferable today** | **95** | 6,733 | 22,289 |
| **Blocked** (needs judge capability work) | **17** | — | 2,300 |

Every Batch task on this server is **stdio** — there are no file-I/O tasks, so
that rejection class is empty here.

### 1.1 Blocked tasks — cannot be transferred (full list)

These are refused by the importer with an explicit message; they are **not**
silently degraded. Each needs a cafe capability that does not exist yet.

**Communication tasks (4)** — need manager process + FIFO support in the judge:

| task | score type | submissions |
|---|---|---|
| `mar2023_cheatsheet` | GroupMin | 139 |
| `may2022_forbiddenwords` | GroupMin | 29 |
| `may2023_hats` | GroupAvgPlus | 178 |
| `oct2024_reunion` | GroupMin | 223 |

**OutputOnly tasks (5)** — need OutputOnly grading support:

| task | score type | submissions |
|---|---|---|
| `may2022_circuit` | Sum | 39 |
| `may2023_beaver` | Sum | 74 |
| `may2023_sticker` | GroupMin | 234 |
| `may2024_sofa` | GroupMin | 190 |
| `sofa_2` | GroupMin | 32 |

**GroupMinPrereq scoring (8)** — Batch tasks, but need the prerequisite-DAG
score type in `app/engine/scorer.rb` (rejected rather than silently rescored):

| task | submissions |
|---|---|
| `may2025_abcd` | 353 |
| `may2025_pizza` | 261 |
| `may2025_starter` | 145 |
| `may2025_icecream` | 114 |
| `may2025_packing` | 108 |
| `may2025_souvenirshop` | 92 |
| `may2025_sacredstone` | 86 |
| `test-groupminprereq` | 3 (test fixture, ignorable) |

`may2023_hats` also uses `GroupAvgPlus`, a second unsupported score type — it
needs both Communication and that score type.

**Practical note.** The 8 GroupMinPrereq tasks are the cheapest unblock (one
score type in the scorer, no judge-process work) and are all from `may2025`,
i.e. the most recent camp. If any of this archive matters most, it is likely
these.

### 1.2 Risk inside the transferable set

**22 of the 95 use comparator checkers** (CMS `comparator` → cafe
`custom_cms`). This path is **unvalidated**: our end-to-end validation covered
white-diff tasks only, and CMS stores checkers as *compiled binaries*, so
whether they execute correctly under cafe's judge on the target host is an
open question. Validate one before trusting the batch:

`apr2022_die, apr2022_findpermutation, feb2022_askask, feb2022_goatforget,
mar2023_updown, mar2024_alienlang, mar2024_immigration, mar2024_mapping,
mar2025_antenna, mar2025_muddy, may2022_canvas, may2022_mergedmedian,
may2023_abc, may2024_convexhull, may2024_sailing, may2025_prefixcircuit,
oct2022_rockpaperscissors, oct2022_sortingtapes, oct2022_spectrophotometer,
oct2022_stick, oct2023_longest, oct2024_moodeng`

Only two tasks use CMS `Sum` scoring (`please_ignore`, `tennisballs`); the rest
are `GroupMin`.

---

## 2. Transfer pipeline

```
c2 (CMS)  --ssh--> dev cafe box  --zip--> production cafe box
          clone            export           existing import page
```

**Step 1 — clone from CMS to a box with ssh access to c2:**

```bash
rails "cms:clone[<task_name>]"
```

Wraps the official `cmsDumpExporter` on the server, filters one task's subtree
(user rows and password hashes never leave c2), fetches only that task's blobs
via CMS `FileCacher`, converts, and imports through the trusted
`ProblemImporter`. Connection settings: `config/cms_remote.yml` (gitignored;
sample committed). Requires passwordless `sudo -u cms` on the CMS host.

**Step 2 — export a cafe-native package:** problem page → **Download (all
datasets)** (or `rails "problems:export[<name>,all]"`).

**Step 3 — import on production:** admin → **Problems → Import**, upload the
zip.

**Why this shape.** Production never needs ssh or sudo on the CMS host — the
dev box is the extraction staging area and the zip is the transport. Verified
2026-08-02: export → re-import of a cloned problem is identical on every
compared field (both datasets, all testcases, weights, managers, statement,
testcase bytes).

**Known gap in step 3:** the **live** dataset's *name* is not preserved through
a plain zip import (auto-named `Dataset N`; additional datasets keep their
names). Content is unaffected. `cms:clone` renames explicitly; the web import
path does not.

**Post-import checklist per problem (production):** set `available`, place in
the right group, confirm `permitted_lang`, confirm the statement PDF opens.
Clones land `available: false` deliberately.

---

## 3. Validation strategy

Structural checks (field-by-field) prove a problem *looks* right; they cannot
prove it *grades* right. For that we replay real c2 submissions — whose CMS
scores are the oracle — through the cloned problem and diff.

Full-corpus replay of all 24,589 submissions is **268 CPU-hours** by CMS's own
recorded timings (914,980 s execution + 48,931 s compilation), before any
sandbox/transfer overhead — roughly two weeks single-threaded. That cost is not
where the bug-catching value is, because **one full-score submission already
exercises every testcase** in a task; further submissions on the same task
mostly re-verify the same bytes. Value lives in *task* diversity and in
checker behaviour, so:

| tier | scope | cost | purpose |
|---|---|---|---|
| **1** | all 95 tasks × ~10 submissions stratified across score bands (100 / high / mid / low / 0) ≈ 950 | ~9–15 h (overnight) | the gate: every task, every score type, all 22 comparators |
| **2** | full corpus for any task Tier 1 flags, plus comparators if suspicious | bounded by Tier 1 findings | depth where it is earned |
| **3** | all 24,589 | ~268 CPU-h | optional soak; mostly measures judge/environment differences, not import fidelity |

**Benign vs real differences.** Our judge is faster than c2's, so `T→P` and
`x→P` per-testcase transitions are expected and benign (the convention in
CLAUDE.md and `Replay::ReplayDiff`). Any other transition — especially a
wrong-answer disagreement — is a real finding.

### Validation results so far

**`mar2025_eatingfish` (2026-08-02, dev):** 8 submissions replayed
(3 × 100, 2 × 69, 2 × 30, 1 × 7). **8/8 score-exact.** 6/8 identical
testcase-for-testcase; the 2 with differences were cafe-passes-where-CMS-failed
on testcases CMS recorded as `Execution timed out` (20/25) or
`Execution killed (memory limits)` (10/10) — benign, zero wrong-answer
divergence. Structural check also exact: 2 datasets, live `fish_rev2` with 42
testcases in groups 7/6/6/5/6/12 weighted 7/19/13/23/27/11 = 100, sibling
`Default` with 40 testcases in 7/6/6/7/5/9.

---

## 4. Progress tracker

| stage | state |
|---|---|
| Extraction channel (ssh + official exporter + FileCacher) | ✅ done, rev 1964/1968 |
| Converter + trusted-importer integration | ✅ done, revs 1961–1962 |
| `cms:clone` operator surface | ✅ done, rev 1965 |
| Single-task end-to-end proof (`mar2025_eatingfish`) | ✅ done, dev problem 717 |
| Submission-replay validation of that task | ✅ done, 8/8 exact (hand-rolled script) |
| Replay gate committed as a reusable tool | ⬜ Tier-1 prerequisite |
| Bulk clone of 95 tasks (dev) | ⬜ in progress |
| **Tier 1 sweep across 95 tasks** | ⬜ in progress |
| Comparator-checker (`custom_cms`) validation | ⬜ **highest risk — 22 tasks** |
| First production import (one task, end-to-end) | ⬜ not started |
| Bulk production import | ⬜ not started |
| Unblock GroupMinPrereq (8 tasks) | ⬜ backlog |
| Unblock OutputOnly (5 tasks) | ⬜ backlog |
| Unblock Communication (4 tasks) | ⬜ backlog |

**Re-running the survey** (counts change as c2 gains tasks): the queries used
here are read-only `SessionGen` scripts over `Task`/`Dataset`/`Submission`;
see this document's git history and the session notes under
`.superpowers/sdd/2026-08-02-cms-clone-import/`.
