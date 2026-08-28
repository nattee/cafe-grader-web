# Backlog

Design refactors, deferred decisions, and "someday" follow-ups that don't yet
warrant a GitHub issue or fit in a single TODO comment. Each entry should be
short — title, why it matters, current state, proposed direction, rough size.
Trim or move to an issue when you start the work.

Conventions:
- One section per entry. Keep them grep-able.
- Cite file paths so the next reader (or Claude) can jump in cold.
- Don't put per-commit TODOs here — those go inline as `# TODO(scope): …`.
- Don't put scheduled or assigned work here — that goes on GitHub.

---

## API ↔ web parity: IP whitelist not enforced on `/api/v1` — RESOLVED 2026-08-28

**RESOLVED (rev 2026).** Policy chosen: full web parity — the web re-checks
the whitelist on every request (`check_valid_login`), so the API does too,
with the same exemptions (admin, `right.whitelist_ignore`,
editor-of-any-problem). One predicate, `User#allowed_from_ip?`, now backs
the web gate, a per-request 403 in
`Api::V1::BaseController#authenticate_api_user!`, and a token-issuance
refusal in `auth/login` (mirroring the single-user-mode precedent); the CIDR
matching moved to `GraderConfiguration.whitelisted_ip?`. Regression tests:
whitelist sweep over every `/api/v1` route in `authorization_sweep_spec.rb`,
login-door tests in `authorization_spec.rb`, CIDR unit tests in
`test/models/grader_configuration_test.rb`.

---

## 🔴 URGENT — `custom_cms` checker argv order may be mis-grading LIVE problems

**Severity: high. Verify on production before the next exam that uses a custom
checker.** Found 2026-08-02 while validating the CMS migration.

**The defect.** Cafe's `custom_cms` evaluation type invokes a checker as

```ruby
# app/engine/checker.rb  (check_command)
"#{@prob_checker_file} #{input_file} #{output_file} #{ans_file}"   # input, USER, correct
```

but CMS — whose name and whose "CMS/Codeforces convention" comment this type
claims to follow — invokes it the other way round:

```python
# CMS 1.4.dev3, cms/grading/steps/trusted.py:237-240
command = ["./checker", CHECKER_INPUT_FILENAME,           # input.txt
                        CHECKER_CORRECT_OUTPUT_FILENAME,  # correct_output.txt
                        output_filename]                  # USER output
```

**Arguments 2 and 3 are swapped.** Cafe's order matches testlib/Codeforces
(`input, participant, jury`), not CMS.

**Why it matters beyond the migration.** A checker written to the CMS
convention receives the *correct answer* where it expects the *student's
output*, and vice versa. Measured on a real imported task
(`oct2022_spectrophotometer`): submissions CMS scored **100 graded 0** — every
testcase "wrong", with no error anywhere. On tasks whose correct-output files
are empty (checker-only tasks, judged from the input alone) it fails
universally; on others it can fail subtly or pass by luck if the checker's
comparison happens to be symmetric.

**Live exposure — needs checking.** Four PRE-EXISTING problems use
`custom_cms` (dev DB, 2026-08-02):

| problem id | name | checker size |
|---|---|---|
| 570 | `d68_q3a_jobqueue` | 2,409,096 B |
| 606 | `a68_q1a_horse` | 2,345,736 B |
| 656 | `a68_q4z_guitar_array3` | 3,095 B |
| 659 | `a68_q4a_normal_puzzle` | 2,408,448 B |

Three are multi-megabyte compiled binaries — the same size profile as the CMS
checkers we imported. **If any of those checkers follows the CMS convention,
that problem has been grading students incorrectly.** Their blobs are not
present on the dev box, so this could not be settled locally; it must be
checked against production.

**How to check (per problem, ~10 minutes each).** Pull the checker, run it by
hand on one testcase in both argument orders against a known-correct output,
and see which order returns "correct":

```
checker <input> <correct> <user>     # CMS order
checker <input> <user> <correct>     # cafe's current order
```

Faster proxy: `strings <checker> | grep -iE 'wrong answer|quitf|testlib'` —
testlib-derived checkers are cafe-order-correct; a checker printing a bare
score plus `translate:` text is CMS-style and therefore mis-invoked today.

**Resolution options.**
1. If all four are testlib-style → nothing is broken; document the naming trap
   loudly (the type is *named* `custom_cms` but is **not** CMS-compatible) and
   consider renaming it to `custom_testlib` with a data migration.
2. If any is CMS-style → that problem's grades are wrong. Switch it to the new
   `cms_comparator` type (added 2026-08-02, enum 7, CMS-native order) and
   rejudge affected submissions.

**Already done:** `cms_comparator` exists and the CMS importer targets it, so
newly imported CMS tasks are correct. `custom_cms` was deliberately left
unchanged to avoid breaking whatever currently depends on it — which is
exactly the thing that needs verifying.

---

## Memory accounting for C/C++ — address space vs cgroup (POLICY + a real bug)

**Raised 2026-08-03 from the CMS migration validation.** Three separate things
are tangled here; separating them makes the decision much easier.

### The mechanics (verified on both sides)

Both graders run isolate. Cafe passes `-m <KB>` for C/C++ → **RLIMIT_AS**, which
caps *address space*: everything the process maps, including memory reserved and
never touched. CMS passes `--cg-mem` → **cgroup accounting**, which caps pages
actually faulted in (RSS).

Concretely: a global `int dp[5000][5000]` is 100 MB of address space the instant
the binary maps its BSS, so cafe kills it at startup even if the solution touches
2 MB. Under cgroups the untouched pages cost ~nothing and it runs. Cafe fails on
*declaration*; CMS fails on *use*.

Cafe already uses cgroups for java/digital/go/python
(`app/engine/judge_base.rb#isolate_need_cg_by_lang`) — C/C++ are the exception.
isolate supports **both** flags simultaneously (`-m` and `--cg-mem` are separate
options), which enables the hybrid below.

### Issue 1 — POLICY: should unused declared memory count? (legitimate either way)

**Cafe style (address space) — for:**
- Deterministic: the verdict never depends on which testcase or how much of the
  array gets touched. Same program, same verdict, every run.
- Teaches memory discipline explicitly: "your solution must FIT in 256 MB" is a
  real competitive-programming skill, and declaring `MAXN` far beyond the limit
  is caught immediately rather than tolerated.
- Prevents lucky passes: a solution declaring 1 GB but touching little passes the
  given tests under cgroups, then dies on data that touches more. Address-space
  limiting rejects it consistently.
- Fails fast (cheaper to grade).

**Cafe style — against:**
- Counts things the student does not control: the static binary's mappings,
  allocator arenas, thread stacks, libstdc++'s own reservations. A solution
  genuinely using 50 MB can show substantially more address space.
- Penalises a widely-taught idiom (declare `dp[MAXN][MAXN]`, use a submatrix).
- Diverges from IOI / CMS / Codeforces, where limits are RSS-based. Students
  trained elsewhere — and problems authored elsewhere — assume the other model.
- Linux over-commits by default, so reserved-but-untouched memory costs the
  machine nothing; the limit measures something that is not a real resource cost.

**cgroup style — for:** measures what the machine actually pays; matches the
convention every imported problem was authored against; enables correct MLE
reporting (see Issue 2). **Against:** allows declare-huge-touch-little
solutions to pass; verdict can vary by testcase; may count page cache for files
the sandbox reads (needs testing on large-input tasks).

### Issue 2 — A BUG, independent of the policy choice

```
Evaluation.count                          6,922,221
Evaluation.where(result: :memory_limit)           0     <-- never, not once
Evaluation.where(result: :crash)            555,119     (8.0%)
```

**Cafe has never once reported "memory limit exceeded" for C/C++.** Under
`RLIMIT_AS`, an over-limit allocation makes `malloc` return NULL or throw
`bad_alloc`; the process dies by signal and isolate reports a runtime error, so
cafe records `crash` (`x`). Students exceeding memory are told their program
crashed — indistinguishable from a segfault. isolate can only report a genuine
memory-limit kill through cgroup accounting (`cg-oom-killed`), so **accurate MLE
verdicts require cgroups regardless of which policy is chosen for the limit.**

### Issue 3 — Imported CMS problems are effectively stricter than authored

Their `memory_limit` values were calibrated against RSS semantics. Enforced as
address space, the same number is a tighter budget, so students lose points they
earned on the source instance. Measured in the migration sweep: submissions CMS
scored 100 scored **0** here; enabling cgroups took two affected tasks from 8-9/10
to **10/10 exact** (`doc/CMS-Migration.md` §5.1).

### Measured behaviour (isolate experiments, 2026-08-03)

**How RSS/cgroup accounting actually charges.** A program declaring a 1 GiB
global array, touching the first 64 MiB, then the last 64 MiB, leaving the
middle untouched:

| point | RSS |
|---|---|
| declared, nothing touched | 1.6 MB |
| after touching FIRST 64 MiB | 67 MB |
| after touching LAST 64 MiB | **133 MB** |

So cgroup accounting charges the **sum of every distinct page ever touched** —
not the maximum of the regions, not the whole array. Untouched pages are never
charged; once an anonymous page is faulted in it stays charged (a judge box has
no swap, so nothing is reclaimed). Granularity is one page: touching a single
byte charges 4 KB. Note transparent hugepages are `madvise` on this host; under
`always`, a single byte could charge a 2 MB huge page and inflate sparse
patterns considerably.

**What `-m` and `--cg-mem` do together.** They are independent limits and both
are enforced — whichever binds first wins. Measured with a 128 MiB limit and a
program declaring 256 MiB:

| flags | declares 256 MiB, touches 0 | declares 256 MiB, touches 200 MiB |
|---|---|---|
| `-m` only (today) | killed, **signal 11**, `max-rss: 816 KB` | killed at startup, same |
| `--cg-mem` only | **runs fine** | killed, **signal 9**, `cg-mem` exactly at limit |
| both, equal | killed, **signal 11** (AS binds first) | killed at startup |
| `--cg-mem` limit + generous `-m` (1 G) | **runs fine** | killed, **signal 9** at exactly the limit |

**The decisive detail: signal 11 vs signal 9.** An address-space kill reports
SIGSEGV with `max-rss` of a few hundred KB — the process died having used almost
no memory, because the kernel refused the mapping, and *nothing in isolate's meta
indicates memory was the cause*. That is precisely why this repo has 555,119
`crash` verdicts and zero `memory_limit` ones. A cgroup kill reports SIGKILL with
`cg-mem` sitting exactly at the limit — unambiguous, and mappable to a proper `M`
verdict.

**Consequence for the policy debate:** "declaring `dp[5000][5000]` beyond the
limit should show MLE" is **not achievable through `-m`**. Address-space
enforcement can fail the program but can only ever report it as a crash. Wanting
both fail-on-declaration *and* an honest MLE verdict means `-m` cannot supply the
second half.

### Options

1. **Keep `-m` alone (status quo).** Your policy, but over-declaration keeps
   reading as "crash" and imported problems stay stricter than authored.
2. **Both flags, equal limits.** Byte-for-byte the same declaration behaviour as
   today, but a program that stays within address space and then over-uses gets a
   clean MLE. Strictly better reporting, zero loosening — the conservative fix.
3. **`--cg-mem` at the limit, `-m` generous (e.g. 4x).** Real memory overuse gets
   an accurate verdict; absurd declarations still fail fast; the common idiom
   (declare `MAXN`, use a submatrix) passes as it does on CMS/IOI/Codeforces.

Older framing kept below for reference:

1. **Keep cafe policy, fix the verdict.** Run with cgroups for accounting/reporting
   but keep an address-space cap too (`--cg-mem=<limit>` *and* `-m=<limit>`):
   students get a correct MLE verdict, and declaring beyond the limit still fails.
   Closest to today's behaviour while fixing Issue 2.
2. **Adopt CMS semantics** (`--cg-mem` only): full fidelity for imported problems,
   matches IOI convention. Strictly more permissive, so no existing grade can fall.
3. **Hybrid, per origin:** CMS semantics for imported problems, cafe semantics for
   native ones. Most faithful, but two grading models to explain and maintain —
   probably not worth it.
4. **Do nothing**, and raise imported problems' memory limits to compensate.

### Rollout requirement whichever is chosen

Use the existing Mode A replay harness (`problems:replay_validate`) to re-grade a
sample of **existing, non-imported** problems before/after and diff against stored
grades. Expect only `x -> P` transitions; **any `P -> x` means the page-cache
effect is real and stops the rollout.** Include tasks with large inputs. ~1 hour
of machine time; converts "should be safe" into "measured".

**Size:** the code change is one line (plus one more for the hybrid). The
decision and the verification are the work.

---

## Grounding materials — deferred follow-ups (from the 2026-07-19 design)

**Context.** Viva grounding was extracted off `Tag` into a dedicated
`GroundingMaterial` model with its own admin library (Manage → Grounding) and
a viva-only attach select on the problem form — see
`docs/superpowers/specs/2026-07-19-viva-grounding-materials-design.md` and
`doc/Viva-Exam.md` §3. Three items were explicitly deferred out of that work:

- **Unify `llm_prompt` into a shared `LlmAsset` model** (deferred alternative
  C from the spec). `llm_prompt` stays on `Tag` for now — small, always text,
  and working. Unifying it with `GroundingMaterial` into one LLM-asset model
  would let `Tag` become a pure label table, but rewrites the working
  rubric-injection path (`viva_turn_assist.rb`, `viva_grade_assist.rb`) for
  marginal benefit today; revisit if `llm_prompt` ever grows document-native
  needs (files, per-item token budgeting) the way grounding did.
- **Accurate page-count token estimate for grounding files.** `GroundingMaterial#compute_estimated_tokens`
  (`app/models/grounding_material.rb`) uses a byte-size proxy
  (`BYTES_PER_PROXY_TOKEN = 400`, i.e. ~1 token per 400 bytes) for attached
  PDF/image files — deliberately approximate, no PDF library in the codebase.
  A `pdf-reader`-based page count would give a tighter budgeting number.
- **Grounding image files (png/jpeg) are rejected at upload — PDF-only for v1.**
  `GroundingMaterial::ALLOWED_CONTENT_TYPES` was originally
  `image/png`/`image/jpeg`/`image/webp` plus `application/pdf`, but
  `Llm::Request.encode_pdf_part` (`app/services/llm/request.rb:124`) hard-guards
  `return nil unless attachment.content_type == 'application/pdf'`, so an
  uploaded image was accepted, token-counted, then silently never sent to the
  model — a validation/delivery mismatch fixed by narrowing
  `ALLOWED_CONTENT_TYPES` to `%w[application/pdf]`. Adding image support back
  requires extending BOTH `ALLOWED_CONTENT_TYPES` (validation) AND
  `encode_pdf_part` (or a sibling encoder emitting a plain
  `data:image/png;base64,...` `image_url` part, no PDF-specific framing)
  together — extending either alone reintroduces the same silent-drop bug.

---

## Help patterns — follow-ups under the context-dependent split

**Decision (2026-05-17).** Two patterns coexist intentionally: inline
knowledge card (`_xxx_help.html.haml`) on index/overview pages where space
is available and visibility matters for new admins; offcanvas drawer on
edit/detail pages where space is at a premium. Convention written into
CLAUDE.md under "Frontend & UI Conventions". Do NOT unify onto a single
pattern; that earlier plan was rejected.

**Discoverability.** Offcanvas trigger buttons must be labeled (`? Help`),
not icon-only. Codified in CLAUDE.md. First-visit popover pointing at the
button is a future enhancement using the existing cookie-based
`dismiss-announcement` controller pattern — deferred until we see whether
the visible label alone is enough.

**Open items under this split.**
- **Shared offcanvas helper.** ✅ DONE 2026-07-01. `app/views/shared/_help_drawer.html.haml`
  now provides the offcanvas chrome (header icon/title/subtitle + close + body),
  used as a layout: `= render layout: 'shared/help_drawer', locals: {id:, title:, subtitle:} do … end`.
  Both drawers migrated onto it: `problems/_edit_help` and the report scope help
  (`report/_report_help`). New drawers should use it instead of hand-rolling the chrome.
- **Edit-drawer content density.** ✅ DONE 2026-07-19. `problems/_edit_help.html.haml`
  is now a Bootstrap accordion (5 items, one open at a time, "Detail card fields"
  open by default) so the drawer opens short instead of one long scroll. Chose the
  accordion over tabs/walkthrough after a rendered side-by-side comparison of all
  three (accordion won: native to the narrow vertical drawer, keeps direct lookup,
  shortest initial scroll). Folded in two structural fixes visible in the old
  version: pulled **Compilation type** out of the Detail `dl` into its own section
  (it carried 3 sub-bullets and bloated the list), and moved the toolbar list
  (Statistics / Download / Change history) out from under *Scoring & evaluation*
  into a new *Toolbar & more* section next to the wiki link. Wording kept verbatim
  — the collapse solves density, so no prose rewrite. Collapse is data-API driven
  (no `init-ui-component` wrapper needed; survives Turbo-frame reloads). Optional
  future follow-up: trim the prose if it still feels heavy once collapsed.

**Out of scope.** `app/views/main/help.html.haml` is a full-page
student-facing help with i18n — different concern, not covered by the
admin help-pattern split.

---

## AuditLog destroy test — RESOLVED 2026-06-20

**RESOLVED.** Added `test/models/auditable_test.rb` (4 tests). Covers both
shapes: own-row destroy writes a `destroy` audit row (Contest), and the
cascade through `dependent: :destroy` writes destroy rows for the child
`ContestProblem`/`ContestUser` join models. Also asserts the destroy
snapshot stores tracked attrs as `[value, nil]`, and that `AuditLog.paused`
suppresses the row. Confirms `after_destroy_commit` does fire under
transactional tests (Rails 5+ runs `after_commit` callbacks in tests).

**Original why.** The "Auditable must exist" bug (fixed 2026-05-17 by making
`belongs_to :auditable` optional) wasn't caught because there was no test
for the destroy path on any audited model — only an integration test for
the controller read paths (`test/integration/audit_logs_controller_test.rb`).

---

## System-test suite — RESOLVED 2026-06-15

**RESOLVED.** `bin/rails test:system` is fully green — **46 tests, 0 failures, 0 errors, 0 skips** (was 20 failing on 2026-05-21). All six clusters fixed, plus a flaky `tags_test#test_update_tag` (a plain `fill_in` appended to the pre-filled name → `fill_options: {clear: :backspace}`). Two tests were briefly skipped during the cleanup, but **both turned out premature — neither was a real Selenium limitation** (2026-06-16):
- `UsersTest#test_login_then_change_password` — a normal in-form submit; the `Updated successfully` assert was just timing out under suite load → `wait: 10`.
- `ProblemsManageTest#test_set_permitted_languages` — a DOM diagnostic proved the `lang_ids` select2 pick **does** register in `#lang_ids`; the failure was the same async-turbo-submit race as Clusters 3 & 4 → wait for `.toast` before the DB read. (My earlier "select2 doesn't register" note was wrong.)

The per-cluster history below is kept as a record. Most are tests that fell behind UI / model changes, NOT broken production behavior — but they need triaging case by case because some may have caught real regressions. None are caused by the 4.3.3 release work itself; they existed before and were noticed only after we wrote a new system test that ran cleanly through `bin/rails test:system`.

**Six root-cause clusters (not 20 independent bugs).** Tackle one cluster per session.

### Cluster 1 — Name-validation rejects spaces — FIXED 2026-06-15
**Decision (2026-06-15): keep the no-spaces rule.** `Group`/`Contest` `name` is a
machine-readable identifier validated by `NameFormatValidator`
(`/\A[a-zA-Z\d\-\_\[\]()]+\z/`, no spaces) — identical to `Problem#name`; the
human-readable text lives in each model's `description`. So the constraint is
intentional, not accidental (despite landing in a "wip" commit). The 4 tests were
using spaced names for `name`; updated them to slug names (`Test_Group`,
`Updated_Group`, `System_Test_Contest`, `Updated_Contest`). `groups_test` +
`contests_test` green.

### Cluster 2 — `select2_select` helper ambiguous — FIXED 2026-06-14
The helper now scopes the search field + results to the just-opened widget
(`.select2-container--open`) and matches options by `exact_text` (so searching
"c" picks the `c` option, not `cpp` too). `test_add_tags_to_problem` and
`test_add_problem_to_group` are green.

`test_set_permitted_languages`: chased 2026-06-14, then fixed 2026-06-16. A
controller-level test
(`ProblemsControllerTest#"do_manage set_languages persists permitted_lang"`)
confirms the logic. The system test was *briefly* skipped on a wrong diagnosis
("select2 doesn't register") — a DOM diagnostic later proved the `lang_ids`
select2 pick **does** register in `#lang_ids`; the real failure was the same
async-turbo-submit race as Clusters 3 & 4. Fixed by waiting for the `.toast`
before the DB read; un-skipped and back to testing `c` + `cpp`.

### Clusters 3 & 4 — available-toggle / date_added — FIXED 2026-06-15, NOT regressions
Both verified at the controller level (new `ProblemsControllerTest` tests:
`do_manage change_enable toggles available`, `do_manage change_date_added sets
date_added`) — the bulk-action logic is correct, no regression. The system tests
were just reading the DB *immediately* after "Apply to Selected", racing the async
turbo_stream submission. Fixed by waiting for the response toast
(`assert_selector ".toast"`) before the DB assertion. All 5 tests green
(`set_available_to_yes/no`, `select_all_then_apply_action`,
`apply_action_to_multiple_individually_selected_problems`, `change_date_added`).

### Cluster 5 — "Go" button gone — FIXED 2026-06-15
The submissions index replaced the old problem-dropdown + "Go" submit button with a
select2 problem chooser (`#submission_problems`) that navigates to
`problem_submissions_path` on pick. The tests now select a problem via the chooser
(new `choose_submission_problem` helper) instead of clicking "Go". Also repointed
stale assertions: the redesigned submission show page no longer renders
"Source Code"/"Task" headings, so the tests assert "Submission Detail" /
"Grading Task Status". Both `test_admin_view_submissions` and
`test_user_view_submissions` are green (confirmed stable over two runs).

### Cluster 6 — Users-page UI drift — FIXED 2026-06-15
Five distinct drifts, all resolved:
- **DataTable never initialised** (created users never showed): the users-index init
  did `document.querySelector('meta[name="csrf-token"]').getAttribute(...)`, which
  *throws* when the CSRF meta tag is absent (forgery protection is off in test) →
  the whole `DataTable()` call aborted. Made it null-safe (`?.`) in
  `user_admin/index.html.haml`, matching the null-safe jQuery `.attr()` the problems
  page already used. (See the new "CSRF meta null-safety" item below — 5 other views
  share the unguarded lookup.)
- **Unauthorized redirect** now sends *logged-in* non-admins to `list_main_path`
  (only nil/logout → `login_main_path`); tests updated.
- **Grant-admin**: the `login` text field is now a per-role select2 (`#admin_user_id`,
  options by `login_with_name`); test selects via select2 and scopes the (now
  duplicated admin/TA) "Grant" button.
- **Profile change-password button**: simple_form `f.button :submit` renders an
  `<input type=submit>`, so `button[type=submit]` no longer matched → use `click_on`.
- **The user-edit form submit** is finicky under Selenium — its prominent "Save
  Changes" button sits *outside* the form via an HTML5 `form=` association.
  `user_admin#update` (alias/remark) is covered by a `UsersControllerTest` case, and
  the system test verifies create + list-membership, leaving the edit to that
  controller test. Whether the dual-submit-button edit page is worth simplifying is
  an open UI question. (The *profile* password change — a normal in-form submit — was
  briefly skipped here but is now un-skipped and passing; see the skip note above.)

### Recommended sequence

1. ~~Clusters 1, 2 & 5~~ done (2026-06-14/15). Cluster 1: kept the no-spaces rule (intentional), updated the test names.
2. ~~Cluster 5~~ done 2026-06-15.
3. ~~Cluster 6~~ done 2026-06-15.
4. ~~Clusters 3 + 4~~ done 2026-06-15 — verified NOT regressions (controller tests pass); the system tests just raced the async turbo_stream submit.

**`bin/rails test` (non-system) is clean** — only one pre-existing failure remains there (`ReportControllerAccessTest#test_admin_can_access_cheat_report`, MySQL collation issue, separate concern).

---

## CSRF meta null-safety in DataTable inits — RESOLVED 2026-06-20

**RESOLVED.** Added `?.` to every remaining unguarded
`document.querySelector('meta[name="csrf-token"]').getAttribute('content')`
lookup. Fixed the 4 views listed below (5 sites: `groups/show` ×2,
`languages/index`, `tags/index`, `layouts/_header`) **plus 4 more sites in
the shared `app/javascript/controllers/datatables/configs.js`** that the
original scan missed — leaving the shared DataTables config module unguarded
would have left the same latent breakage in any table built from it.
Grep for the unguarded form now returns nothing.

**Original why.** The unguarded lookup throws when the meta tag is absent —
aborting the whole `DataTable()` init (empty table). The meta is always
present in production (no user impact), but it's absent when forgery
protection is off (test env), which is how Cluster 6 surfaced it.

---

## Reporter role: let it report on finished (unavailable / archived) courses — RESOLVED 2026-07-01

**RESOLVED via option 3b.** Editors are now group-scoped content curators:
`Problem.group_editable_by_user` dropped the `available` / `groups.enabled`
filters, and `group_reportable_by_user` = editor-set ∪ reporter-gated-set, so an
editor sees/edits/reports on archived courses and unavailable/draft problems in
their groups while reporters stay scoped to live content (`app/models/problem.rb`).
`Group.reportable_by_user` was made role-aware to match, keeping the report gate,
the filter dropdowns, and `reportable_users` consistent (`app/models/group.rb`).
The report filters tag an editor's archived groups; a reporter with no live
groups is turned away at the gate. Covered by `test/models/problem_scope_authorization_test.rb`
+ report controller tests. **Operational rule:** to grant a non-admin access to a
finished course, make them an *editor* of its group. The option-B "scores-only
split" below was **not** taken (3b delivers the need without decoupling the
content predicates). Kept for history.

---

**Problem (confirmed 2026-06-30 on production).** A non-admin `reporter`/
`editor` only sees report data for problems that are **`available = TRUE`** in
an **enabled** group — that's what `Problem.group_actionable_by_user`
(`app/models/problem.rb:92`) filters on. But reporters are assigned to
*finished* courses/exams, which are exactly the ones whose problems get set
unavailable and whose group gets disabled. Result: **every** non-admin reporter
on production currently sees 0 reportable problems. They can still *reach* the
report screen, because the gate (`groups_for_action(:report)` →
`Group.reportable_by_user`, `app/models/group.rb:15`) ignores `group.enabled`
and the problem-level flags — hence "reaches screen, sees nothing".

The data-hiding itself is **working as intended**: `available` is meant to be
an absolute, student-exposure kill-switch (admins bypass via `Problem.all`,
everyone else is blocked across submit / report / edit / PDF / view-submission /
view-testcase). The 2026-06-30 session fixed the two *surface* defects (scoped
the user-group dropdown to `@groups`; added an empty-state notice explaining
hidden problems) but deliberately left the policy unchanged.

**Open design decision — should reporters self-serve finished-course reports?**
If yes, the clean approach is **option B: split scores from content.** Add a
scores-only report scope that ignores `available` / `group.enabled`, while the
problem *content* surfaces (PDF/statement via `User#can_view_problem_pdf?`,
source via `can_view_submission?`) stay gated by `available`. This honours
"availability is absolute" for *content* while letting a TA pull aggregate
scores for a finished exam. The work is the decoupling: today
`group_reportable_by_user` is reused by those content predicates, so loosening
it in place would leak PDFs/source to reporters — the scope must be split first.

**Alternative (no code): workflow change.** Stop disabling the group when a
course ends; rely on `groups_problems.enabled` / `available` for student hiding
and keep the group enabled so reporters retain access. Cheaper but relies on
operator discipline.

**Size.** Option B ~ half a day (new scope + audit every caller of
`group_reportable_by_user` + tests). Decide intent first.

**Leaning (2026-07-01 discussion).** Prefer **option 3b**: make the *Editor*
role a group-scoped content curator that bypasses **both** `group.enabled` and
`available` within its groups, while *Reporters* stay gated by both. Editor
stays a strict superset of Reporter; admin remains the user-management tier.
Keep `group.enabled = off` meaning "archived for everyone by default", and
surface archived groups to editors as a **read-only "View archived" area** (no
re-enable, no student re-exposure, no stateful toggle). This also fixes a
latent bug — `group_editable_by_user` currently requires `available: true`, so a
non-admin editor can't even edit a draft/unavailable problem in their own group
(likely why production has zero functional non-admin editors). Rejected the
"editor temporarily re-enables the group to read" idea: re-enabling re-exposes
the course to students, is a shared-state write that destroys the "finished"
cue, and doesn't even work when problems are `available: false`.

---

## Publish "Users, Roles & Access Control" wiki page — RESOLVED 2026-07-01

**RESOLVED.** Published to the upstream wiki:
https://github.com/cafe-grader-team/cafe-grader-web/wiki/Users-Roles-and-Access-Control
(wiki commit `54b2c8d`). The `doc/Users-Roles-and-Access-Control.md` in this repo
is the source draft; it's current with the shipped 3b behavior (editors are
group-scoped curators, reporters see live courses only, filters tag archived
groups). If the model changes again, update the draft here and re-push to the
wiki repo (`git@github.com:cafe-grader-team/cafe-grader-web.wiki.git`, a separate
repo — clone, copy the page in, commit, push).

**Note:** the wiki's `Home.md` is intentionally minimal (no page TOC); pages
surface via GitHub's auto-generated sidebar, so no Home edit was needed.

---

## Import/Export & CMS interop (from doc/problem-import-export-design-2026-07-14.md)

**Status 2026-08-02.** A *live-server* CMS import path shipped (master revs 1960–1968;
spec `docs/superpowers/specs/2026-08-02-cms-clone-import-design.md`):
`rails "cms:clone[task]"` ssh's to the CMS host, wraps the official `cmsDumpExporter`,
filters one task's subtree, fetches its blobs via `FileCacher`, and converts through
`Converters::CmsDumpConverter` into the trusted `ProblemImporter`. Validated against
c2 (`mar2025_eatingfish`): structure exact, and a replay of 8 real c2 submissions
scored 8/8 identical to CMS (only benign `T→P`/`x→P` per-testcase diffs). None of the
capability items below are closed by that work — Communication / OutputOnly / file-I/O
/ GroupMinPrereq are now *detected and rejected with a clear message* pointing here,
which is the interim behavior the 2026-07-14 design specified.

**Production transport that works today** (verified 2026-08-02, no new code needed):
clone on a box that has ssh to the CMS host → problem page **Download (all datasets)** →
upload that zip on the production server's existing **Problems → Import** page. Export→
import was round-tripped on the cloned problem: every field identical (both datasets,
42 testcases, weights, managers, statement, testcase bytes). This keeps production from
ever needing ssh/sudo access to the CMS host. Known cosmetic gap: the **live** dataset's
name is not preserved through a plain zip import (root `ds_name` is inert — the importer
auto-names the live dataset `Dataset N`; additional datasets keep their names). `cms:clone`
renames it explicitly; the web import path does not.

**Open, in the order that serves "import c2 → production, repeatably":**

- **UI-facing CMS *package* import (unbuilt).** The 2026-07-14 design's UI decision —
  "existing import page with format auto-detect" — is still unimplemented. Note the
  shape difference: `CmsDumpConverter` consumes a *dump bundle* produced by our own
  extractor, NOT a CMS-native package, so the upload path needs the originally-planned
  `CmsItalianConverter` (`task.yaml`) and/or `TpsConverter` (`problem.json`) plus
  sniffing in `problems_controller#do_import`. They slot into `app/engine/converters/`
  behind the same `convert(src, dest) → {log:, warnings:, errors:}` contract and can
  reuse the staging-layout knowledge (notably: a converter MUST emit `managers_dir` +
  `managers_pattern` or the importer silently skips `managers/*`). Needed when someone
  hands over a package file and there is no DB access; NOT needed for the c2→production
  flow above. Size: ~1 day per format + fixtures.
- **Mode B replay gate (CMS-source) before any bulk clone.** The 2026-08-02 validation
  was a hand-rolled script. Committing it as a CMS source mode in the existing
  `Replay::` harness (reuse `ReplayGrader`/`ReplayDiff`; new pieces are a CMS submission
  sampler and a CMS-outcome→cafe-verdict-char translator) turns per-task validation into
  one command. Matters because the 8-submission check only exercised white-diff +
  integer GroupMin + grader compilation; `Sum`, regex GroupMin params, and comparator
  (`custom_cms`) checkers have never been run against a real task. Size: ~half a day.
- Communication task support in the judge (manager process + FIFOs) — unblocks CMS Communication import/export.
- OutputOnly grading support — unblocks CMS OutputOnly import/export.
- GroupMinPrereq scoring in cafe's scorer (`score_param` to hold the prereq DAG) — unblocks importing dae's CMS camp tasks that use the custom score type.
- File-I/O task support (or a permanent-rejection decision) for Italian-format tasks with `infile`/`outfile`.
- Checker protocol adapter so `custom_cafe` checkers can be exported to CMS.
- C++ relative comparator (CMS-side equivalent of `lib/checker/relative.rb`).
- ✅ DONE 2026-07-19. Group-weight uniformity validation in the dataset edit UI
  (import already warns). Shared `Dataset#mixed_weight_groups` now backs both the
  import warning and a live warning on the Testcases tab (banner + per-row marker,
  group_min only). Same session also added CMS-style **codename-regex** grouping to
  the Testcase config tool (`[[weight, "1-.*"], …]`, start-anchored like CMS
  `re.match`) with inline examples + a "Syntax & CMS notes" drawer, and documented
  the whole weight/group grammar + the CMS-divergence caveat in
  `doc/dataset-scoring-and-evaluation.md`.
- Approach-C IR refactor of import/export — only if supported formats multiply beyond Italian+TPS.
- **✅ AUDITED 2026-07-19.** Reviewed every single-string shell invocation on the
  grading path (`isolate_runner.rb:12,36,45`, `checker.rb:155`,
  `compiler/postgres.rb:69`, plus the ones the original item missed:
  `judge_base.rb:320`, `grader.rb:206,268`). **Finding: no untrusted (student)
  input reaches any command string.** Inputs are deployment config, engine-built
  ID-based paths, the admin-managed `languages` table (compile/run templates),
  and problem-author files — and authors already have arbitrary code execution
  by design (custom checkers run *unsandboxed* at `checker.rb:155`), so an author
  filename is not an escalation. This is unlike the import/export fix, where zip
  entry / problem names were attacker-influenced. **Action taken:** converted
  `judge_base.rb:320` (`run_initializer`) to argv `system(*init_cmd)` — its
  `String#dump` pseudo-quoting was Ruby escaping, not shell escaping (fragile on
  a space/`$`/backtick, and left one of four args unquoted). **Left as-is with
  rationale:** `isolate_runner.run_isolate` deliberately relies on `${UID}` shell
  expansion (line 32) and takes no untrusted input; `checker.rb:155` and the
  `grader.rb`/`postgres.rb` sites take only config/ID/author-trusted strings.
  Optional future hardening (not required): make `check_command` return argv, and
  replace `${UID}` with `Process.uid` so `run_isolate` can drop the shell.
  **Separate, larger item worth its own backlog entry:** custom checkers execute
  unsandboxed on the judge host — a deliberate trust choice today, but if we ever
  accept checkers from less-trusted authors it should move inside isolate.
- Test-class naming: `test/controllers/` and `test/integration/` must not declare the same class name (Ruby merges them and cross-contaminates `setup`); scope-name new controller test classes (e.g. `ProblemsImportExportControllerTest`). **✅ FIXED 2026-07-19** for the known instance: the integration file was renamed to `test/integration/report_controller_access_test.rb` with `class ReportControllerAccessTest`; `test/controllers/report_controller_test.rb` keeps `ReportControllerTest`. The naming rule stands for future test files.

---

## Viva `answer` action — concurrent at-cap POSTs can double-enqueue the grade job

**Context (noted 2026-07-21 during viva Phase 1 review).** `VivaSessionsController#answer`
(`app/controllers/viva_sessions_controller.rb`) hard-caps the interview: when
`@submission.viva_turns.where(role: :student).count >= @submission.problem.viva_hard_cap`
it writes a closing system turn, sets `status: :evaluating`, and enqueues
`Llm::VivaGradeAssistJob.perform_later(@submission)` — all without a row lock.
Two truly concurrent POSTs at the cap (double-click, two tabs, a retried
request) can both read the same pre-cap count and both take the force-finish
branch, enqueuing the grade job twice for one submission. This is a
pre-existing pattern across the whole controller (no action here takes a row
lock), not something specific to this branch.

**Impact.** Regrading is idempotent (the grader recomputes from the
transcript), so a double-enqueue costs an extra LLM grading call — noise/cost,
not a correctness or grade-manipulation bug.

**Fix direction.** Either `@submission.lock!` around the check-and-transition,
or a unique-job guard on `Llm::VivaGradeAssistJob` keyed by submission id.
Small; low priority given the impact is cost only.

---

## `datatables/configs.js` render functions interpolate unescaped HTML

**Context (noted 2026-07-21 during viva Phase 1 review).**
`app/javascript/controllers/datatables/configs.js` builds several DataTables
column `render` functions with raw template-literal interpolation of
server-supplied fields — `${data}` (lines 102, 184, 197) and
`${row.full_name}` (lines 108, 203) — dropped straight into HTML strings with
no escaping. `data`/`row.full_name` here are problem names / user full names,
which admins and group editors can set via ordinary edit forms.

**Impact.** These are all admin/editor-only management tables, so this isn't
a privilege-escalation vector (an admin who can already do arbitrary damage
would be attacking themselves or other admins). But it's a live class of bug:
a problem or user name containing HTML/script content would render
unescaped for the next admin who views that table, which is worth closing.

**Fix direction.** Add a small `escapeHtml` helper in the configs module and
wrap every user-controlled interpolation (`data`, `row.full_name`, and any
other free-text row field) with it. Bounded, mechanical change once the
helper exists — the main work is grepping the file for every interpolation
site so none are missed.

---

## Viva grade display — narrative doesn't belong in `grader_comment` / main list — RESOLVED 2026-08-28

**RESOLVED (rev 2036).** Shape chosen after a per-reader-site design pass
(dae, 2026-08-28): the success path writes `Submission#viva_result_marker`
(`viva` / `viva:terminated`, derived from `viva_terminated_at`, never from
the narrative text) into `grader_comment`; the narrative stays on
`viva_grades.narrative` only. `_submission_short` branches on
`problem.viva_exam?` (the problem is passed in / read from `@problem` to
avoid a per-row query): graded rows show the score plus a badge that *is*
the link to the viva page (grey `viva`, red `terminated`), no evaluations
icon and no compiler-msg link; ungraded rows say "Interview in progress" /
"Grading in progress…", and `grader_error` rows (which never get
`graded_at`) show a red "Grader error" badge instead of "Waiting to be
graded…" forever. Every other reader (stat tables, Submission report,
graders/index, API `last_result`) prints the marker automatically and needed
no view change — their ID links already redirect vivas to the viva page.
One-off cleanup: `bin/rails viva:clean_grader_comments [APPLY=1]`
(`Viva::GraderCommentCleaner`, report-first; rewrites only `done` rows whose
`grader_comment` contains the narrative). Tests: service write path,
main-list integration (6 cases), cleaner report/apply/idempotence.

Original write-up kept below for the record.

**Context (dae, 2026-07-21 smoke test).** The viva grading pass stores its
output on the submission like a normal grading run, and the long narrative
text ends up rendered inline on the student's main/list page through the same
path that shows per-testcase verdict strings (`P-Tx-s…`). A paragraph of
LLM feedback visually clutters the list and abuses a field designed for
compact per-testcase codes.

**Direction (needs a real design pass, not a quick patch).** Viva grades
already have a first-class home (`viva_grades` + the grade card on the viva
page). The main/list view should show only a compact chip for viva
submissions — score (and maybe a terminated/flagged marker) linking to the
viva page — and whatever currently copies narrative into `grader_comment`
should stop, with a data cleanup for existing rows. Touches: grading
completion path in `Llm::VivaGradeAssist`/job, main list rendering, possibly
reports that read `grader_comment`. Backlogged per dae: "requires full design
change".

**Re-raised 2026-08-28 (confirmed, still unfixed).**
- Write site: `app/services/llm/viva_grade_assist.rb:176-181` —
  `@submission.update!(…, grader_comment: data['narrative'])`, immediately
  after the same text is saved to `viva_grades.narrative` (`:170-174`). The
  copy is redundant: the grade card (`submissions/_viva_grade`) already
  reads from `viva_grade`.
- Main-list render site: `app/views/application/_submission_short.html.haml:50-51`
  — `%span.grader-comment.text-break = " [#{submission.grader_comment}]"`
  beside the score whenever `ui.show_score` is on. Dev-DB narratives are
  316–417 chars ("Your performance in this viva was outstanding. You
  demonstrated…") in a span designed for a 10–50-char `P-Tx…` string;
  `text-break` wraps it into a paragraph inside the "last submission" cell.
- The same string also surfaces in `problems/stat.html.haml:61`,
  `user_admin/stat.html.haml:96`, `report/submission_query.json.jbuilder:8`
  (Result column), `graders/index.html.haml:183,217`,
  `comments/_llm_assist_header.html.haml:10`.
- Keep the *error* path: `viva_sessions/_viva_session.html.haml:19`,
  `viva_grade_assist.rb#handle_error`, and `viva_grade_assist_job.rb:20`
  legitimately use `grader_comment` for the short "Grader error: …" text —
  only the success-path narrative copy should go.
- Minimal shape if the full redesign keeps waiting: on success write a
  compact marker (e.g. `viva` / `viva:terminated`) or nil instead of the
  narrative; one-off cleanup `Submission.joins(:viva_grade).where(status:
  :done)` → rewrite `grader_comment`; `_submission_short` branches on
  `submission.problem.viva_exam?` to show a "View grade" link to the viva
  page instead of the bracketed string.


## OpenRouter LLM provider — MOSTLY SUPERSEDED by Llm::AiGatewayTransport (rev 2018)

The generic bearer-key OpenAI-compatible gateway provider this sketch called
for now exists: `Llm::AiGatewayTransport` + the `*AiGateway*` role subclasses
(built 2026-08-26 for the Chula AI Gateway, a LiteLLM proxy). Pointing the
`ai_gateway:` config block at OpenRouter should work as-is — bearer key from
credentials, per-model picker registration, `file`-block PDF rewrite — with
two known gaps if OpenRouter is ever actually wanted:
- `compute_cost` reads LiteLLM's `x-litellm-response-cost` response header;
  OpenRouter reports cost in the response body (`usage.cost` with
  `usage: {include: true}`). Cost would silently record 0.0 until a small
  adapter branch reads the body field.
- The config block is a **single registry** — one gateway per deployment.
  Running two bearer-key gateways side by side (e.g. Chula AI Gateway AND
  OpenRouter) needs `ai_gateway:` generalized into a keyed registry like
  `self_hosted_models:`, plus per-entry provider classes.

## Near-Miss: student-facing phase (deliberately deferred)

Interaction model (staged ladder vs one-click AI repair vs mode-split),
lifeline economy via the existing `comments.cost` machinery,
GraderConfiguration budget keys. Deferred until the batch data is digested —
the contest-scale evidence now exists; see `doc/Near-Miss-Grading.md`
(experimental record + the max(original, repaired) policy) and spec
section 13 (`docs/superpowers/specs/2026-07-30-near-miss-grading-design.md`).

## Near-Miss: `problems.statement_text` — designed 2026-07-31, deferred

Decision (dae): statements reach LLM prompts as **pdf-reader-extracted text**,
stored on the Problem as an **editable draft** (the `GroundingMaterial
#extraction_draft` pattern), because raw extraction drops Thai combining
marks and humans must be able to fix it once. Consumer: the ASSIST path
(unblocks `SelfHostAssist` in the picker) — NOT repair, which measured
better without statements. Integrity design (agreed after the
clobbering-vs-staleness discussion):

| Piece | Rule |
|---|---|
| `statement_text` (mediumtext) | machine draft or human-edited text |
| `statement_text_auto` (bool, default true) | true = safe to regenerate; any human form-save sets false |
| `statement_text_checksum` (string) | statement blob checksum the text was extracted from / edited against |
| Upload hook | re-extract ONLY if auto or blank — never clobber human edits |
| Problem form | textarea + staleness badge on checksum mismatch + explicit "Re-extract from PDF" button (resets auto) |

Plus: `pdf-reader` graduates into the Gemfile; blank extraction (scanned
PDFs) leaves the field blank and prompts omit the section; leave the column
out of the audited attrs (derived, bulky).

## CMS clone — deferred hardening batch (from 2026-08-02 final review)

- Nil CMS `time_limit`/`memory_limit` convert to `0` silently via `.to_f`/`.to_i`
  — add a reject-or-warn guard. `app/engine/converters/cms_dump_converter.rb:284-285`
  (`write_dataset_into`).
- Fractional `GroupMin` points truncate to an int weight with no warning —
  add a warn when `points` isn't a whole number.
  `app/engine/converters/cms_dump_converter.rb:172-202` (`build_group_plan`).
- `Errno::EPIPE` on the ssh stdin write surfaces as a raw backtrace instead
  of a clean `abort` — rescue it. `lib/tasks/cms.rake:36` (`stdin.write(File.read(script))`).
- Add `-o ConnectTimeout=10` to the ssh invocation so a dead/unreachable CMS
  host fails fast instead of hanging on the default TCP timeout.
  `lib/tasks/cms.rake:31` (the `ssh -o BatchMode=yes ...` cmd array).
- An empty ACTIVE dataset (0 testcases) imports with no warning — give it
  root parity with the additional-dataset warning path (non-active empty
  datasets already get a `skipped non-active dataset` warning via
  `dataset_reject_reasons`; the active one has no equivalent signal).
  `app/engine/converters/cms_dump_converter.rb:127-147` (`dataset_reject_reasons`),
  `:327` (the per-dataset testcase-count log line).
- `script/cms_extract/extract_task.py`'s module docstring documents exit
  codes `0 ok, 2 usage, 3 task not found` but not the traceback/exit-1 case
  for an unhandled exception (e.g. `cmsDumpExporter` failure) — the rake
  task already treats any nonzero exit as failure so behavior is correct,
  just undocumented. `script/cms_extract/extract_task.py:1-21` (docstring).

---

## Upstream GitHub Pages for docs/ + wiki visual-companion links

**Why it matters.** The user-facing authorization guide
(`docs/guide/authorization.html`) and the audit report are published only on
the fork's Pages site (`nattee.github.io/cafe-grader-web`) — the upstream wiki
can't link them canonically yet, and the fork wiki pointer references the
temporary URL.

**Current state.** The code alignment this entry originally tracked shipped at
rev 1996 (`User#can_submit_to_problem?` everywhere; disabled memberships grant
no role; resurrected model lock). Fork Pages serves master:/docs and works.

**What remains.** After the next /upstream-sync carries `docs/` to
cafe-grader-team: an org **admin** (dae's token is WRITE, not admin) must
enable GitHub Pages there (Settings → Pages → Deploy from a branch →
master + /docs), then (1) add the visual-companion link block to the wiki
page `Users-Roles-and-Access-Control` pointing at
`https://cafe-grader-team.github.io/cafe-grader-web/guide/authorization.html`,
(2) swap the temporary fork URLs in the fork-wiki pointer page.

**Size.** Trivial once the admin flips the Pages switch.

---

## Viva grading: harden against transcript-continuation failures

**Why it matters.** `Llm::VivaGradeAssist` sends the interview transcript as
a user message; the grader model can get absorbed into it and answer as the
*interviewer's next turn* instead of emitting the grade JSON. Observed
2026-08-23 on a real practice viva (prod sub 937805): gemini-2.5-flash did
this reproducibly (the stored grading AND a fresh rerun, 2/2). The result is
a `VivaGrade` row with `total_points: nil`, empty rubric/narrative — a
student-visible zero with no retry and no admin alert.

**Current state.** Mitigated, not fixed: the chula_cp deployment moved the
default grader to gemini-3.1-pro (chula_cp rev 2008), which graded the same
transcript cleanly. The engine-side gap in `handle_response`
(`app/services/llm/viva_grade_assist.rb`) remains: a non-JSON response is
persisted as a nil-score grade and dropped on the floor.

**Proposed direction.** (a) Detect a parse/schema failure and retry once,
optionally reinforcing "output ONLY the JSON object" in the retry prompt;
(b) surface still-failed gradings to admins (viva alert or grading-error
state) instead of storing a silent nil-score row; (c) consider pinning the
narrative language in the grading prompt — today it's model-mood-dependent
(gemini-3.1-pro answered one session in Thai, another in English, while
2.5-flash always wrote English).

**Size.** Small-medium — retry + error surfacing in one service class plus a
test with a canned non-JSON response; the language pin is a one-line prompt
edit but needs a policy decision (Thai? match the student?).

---

## Grader.watchdog duplicate-spawn → isolate box collisions (`!` results)

**Why it matters.** 2026-08-27 incident on the ISE grader (10.0.5.70): every
`Grader.start(1..8)` was running **twice**. Whenever both copies of a box
graded concurrently, isolate refused (`This box is currently in use by
another process`), the evaluation was stored as `grader_error` (`!` in
`grader_comment`), and students lost points on testcases that never ran —
195 error evaluations across ~130 submissions that day alone, with earlier
bursts Jun 23–29 and Jul 17 (350). Silent score deflation during live
classes/exams.

**Root cause — two stacked failures.**
1. *Whenever identifier drift (deploy pipeline).* `whenever
   --update-crontab` (run by the automation repo's deploy job,
   `.gitlab-ci.yml` "Syncing crontab" step) identifies "its" crontab block
   by the schedule.rb absolute path. The app dir was renamed
   `cafe-grader` → `cafe_grader` on some hosts; the next deploy wrote a
   fresh block and **orphaned** the old one → two `* * * * *`
   `Grader.watchdog` lines. On 10.0.5.70 the orphaned block's job lines had
   been hand-edited to the new path (while its Begin/End identifier
   comments kept the old path), so both lines were live.
2. *Watchdog not duplicate-safe.* `Grader.watchdog`
   (`app/engine/grader.rb`) spawns a grader when `ps` shows none for a
   box, and treats `lines.count >= 1` as healthy. Two watchdogs firing in
   the same minute race the ps-check and each spawn a full set; once
   duplicated, `>= 1` hides the problem forever.

**Proposed hardening.**
- Watchdog: treat `lines.count > 1` as unhealthy — kill the extras (keep
  the oldest), log loudly. Optionally wrap the check+spawn in an `flock`
  so concurrent watchdog invocations serialize.
- Deploy: pass a stable identifier so path changes can never orphan a
  block: `bundle exec whenever --update-crontab cafe-grader` in the
  automation repo (note: the identifier switch itself orphans the current
  block once per host — pair it with a one-time sweep for stray
  `# Begin Whenever` blocks).
- Optional deeper defense: on a box-in-use isolate error, retry the
  testcase once instead of persisting `grader_error`.
- Evaluator rerun-idempotency (second defect, found during the incident
  rejudge): an interrupted evaluation can leave
  `isolate_submission/<sub>/<tc>/output/stdout.txt` at mode 0644 owned by
  that box's uid — the post-run `chmod 0666` (`app/engine/evaluator.rb`,
  the second `run_isolate` call) is itself an isolate run and dies with
  the box. A later rejudge that lands the testcase on a *different* box
  uid then can't truncate-open the file and fails with isolate message
  `open("/output/stdout.txt")` → `grader_error` again (14 of the 142
  rejudged submissions on 2026-08-27). Fix: host-side
  `@output_file.unlink if @output_file.exist?` in
  `prepare_testcase_directory` (`app/engine/judge_base.rb`) so every run
  starts from a clean redirect target, making reruns independent of how
  the previous run ended.

**Current state.** One-time cleanup done 2026-08-27: 10.0.5.70 (crontab
deduped, duplicate graders killed, affected submissions rejudged) and
10.0.5.105 (stale block removed; it pointed at a deleted checkout, so it
was inert). Other deploy-matrix hosts swept clean the same day;
10.24.0.100 (TOI) unreachable from the office network — still unchecked.
Crontab backups: `~/crontab.backup-2026-08-27.txt` on both fixed hosts.
No code changes yet.

**Size.** Small-medium — watchdog duplicate-kill + flock with a test, plus
a one-line change in the automation repo.

---

## Viva/tag markdown fields are bare textareas — add highlighting + preview — RESOLVED 2026-08-28

**Resolution (rev 2030).** Tier 1 + tier 2 shipped together: `markdown_editor_controller.js`
(Ace `mode-markdown`, `github` theme, soft wrap) wraps all four textareas via
`ApplicationHelper#markdown_editor_data`, with an Edit / Preview toggle that
posts to `MarkdownController#preview` (`safe_markdown`, editors only).
`grounding-draft` dispatches `change` so "Copy draft into Body" still works.
Not done (by design): side-by-side edit+preview, client-side renderer.

**Why it matters.** The viva authoring surface is markdown-heavy and long.
On the dev DB the Examiner briefing (`Problem#viva_prompt`) runs ~4.7–5.5k
chars, the Scenario (`Problem#description`) ~1.4–2.5k, the shared
`viva_conduct` tag prompt (`Tag#params`) ~4.9k, and a grounding body
(`GroundingMaterial#body`) ~20k. All four are edited as plain `<textarea>`s
(monospace at best) with no syntax highlighting, no preview, and no rendered
read-only view anywhere in the admin UI — checking that the `# Rubric`
heading or a nested list is well-formed means eyeballing raw text through a
14–20-row box. Raised by dae 2026-08-28.

**Current state (confirmed 2026-08-28).**
- `app/views/problems/_form.html.haml` — `viva_prompt` (`as: :text, rows:
  14, font-monospace`, General tab) and `description` (`rows: 20,
  font-monospace`, Description tab, labelled "Scenario (markdown)" for viva).
- `app/views/tags/_form.html.haml:15` — `params` (`height: 20rem`, plain).
- `app/views/grounding_materials/_form.html.haml:5` — `body` ("Grounding
  text (markdown)", `rows: 12`).
- Server-side renderers already exist: `ApplicationHelper#markdown`
  (Redcarpet, trusted input) and `#safe_markdown` (`filter_html`, for LLM
  output). No client-side markdown library is vendored.
- Ace is already vendored and wired for code (`editor_controller.js`;
  `config/importmap.rb` pins `ace-builds` @1.42 plus per-mode files).
  `vendor/javascript/ace-noconflict/mode-markdown.js` **is on disk but not
  pinned or imported** — markdown highlighting is one pin + one import away.

**Direction (two tiers, choose per field).**
1. *Cheap, all four fields:* a small `markdown-editor` Stimulus controller
   that swaps the textarea for Ace in `ace/mode/markdown` (soft-wrap on, a
   light theme — these are prose, the merbivore dark theme used for
   submissions is wrong here) and mirrors edits back into the hidden
   textarea for submit. Pin `ace-mode-markdown` in importmap. One controller
   reused on all four forms.
2. *Preview where it earns it:* a "Preview" toggle/tab beside the editor
   rendering through the existing `markdown` helper via a tiny
   `POST /markdown/preview` turbo endpoint (server-side keeps one renderer of
   truth and matches what the LLM receives; client-side would need a new JS
   lib). Most valuable on `viva_prompt` (rubric structure) and
   `GroundingMaterial#body`. A collapsed rendered view on
   `grounding_materials/edit` and in the viva card on `problems/edit` covers
   the "even just for viewing" case.

**Cautions.** Not WYSIWYG (Trix etc.) — these are prompts consumed verbatim
by the LLM; the source text stays the primary artifact.
`grounding_draft_controller.js` writes the PDF→markdown extraction draft into
`body` via `grounding_draft_target: 'body'` — an Ace swap must keep that
working (write into the Ace session, not only the hidden textarea). Pairs
with the viva edit-page layout entry below (wider column → taller/wider
editors).

**Size.** Small for tier 1 (controller + pin + 4 view edits); small-medium
for tier 2 (endpoint + toggle).

---

## Problem stat page — per-group breakdown + deep link to the max-score report — MOSTLY RESOLVED 2026-08-28

**Resolution (rev 2029).** Direction (1) shipped, plus a group pre-pick: the
stat page's "Score report" pill opens the Best Score report with the problem
*and* a section preselected (`Problem#report_group_for` — live group with
submissions > most-submitted group incl. archived > newest live), and the
shared filter partials now honour `probs[…]` / `users[…]` URL params (the dead
prefill hooks are fixed for all four reports). **Still open:** direction (2),
a per-group summary card on the stat page itself — only worth it if switching
groups in the report proves too slow in practice.

**Why it matters.** On `/problems/:id/stat` an instructor wants "how did each
group (section) do on this problem?". The page has a submission-history
chart, Subs count, Solved/Attempted, and a flat per-submission DataTable
(`app/views/problems/stat.html.haml`, `ProblemsController#stat`) — nothing
group-aware, and no link to the report that could answer it. Today the path
is Reports → Max score → find the problem in a Select2 → pick ONE group →
run → repeat per group. Raised by dae 2026-08-28.

**Current state (confirmed 2026-08-28).**
- Stat toolbar links are Edit | Stat only (`stat.html.haml:20-22`);
  `_problem_head` has no report link either. `ReportController#problem_hof_view`
  is per-problem but aggregates by language, not by group.
- Max-score report (`ReportController#max_score` → `report/_problem_select`,
  `report/_user_select`) filters problems by `probs[use]=ids&probs[ids][]=…`
  and users by `users[use]=group&users[group_ids]=…`. The group select is
  **single** (no `multiple`), so it is one group per run; rows are per-user
  with no per-group aggregate.
- **The URL-prefill hooks in the filter partials are dead code.**
  `_problem_select.html.haml:15` reads `params[:'probs[ids][]']` — a literal
  key; Rack parses `probs[ids][]=5` into `params[:probs][:ids]`, so it is
  always nil (verified with `Rack::Utils.parse_nested_query`). Lines `:22`,
  `:29` and `_user_select.html.haml:16` read `params[:prob_group_id]`,
  `params[:prob_tag_id]`, `params[:group_id]`, which nothing sends. So
  `GET /report/max_score?probs[ids][]=123` renders an empty form. The same
  partials back `report/submission`, `activity` and `ai` — fixing the prefill
  once fixes all four reports.

**Direction.**
1. *Deep link (cheap):* make `_problem_select`/`_user_select` read
   `params.dig(:probs, :ids)` etc. and tick the matching `probs[use]` /
   `users[use]` radio; add a "Report" pill (Admin-Controls pattern, e.g.
   `table_view` icon + tooltip) to the stat toolbar →
   `max_score_report_path(probs: {use: 'ids', ids: [@problem.id]})`.
   Optionally auto-submit the filter form on arrival when prefilled (Stimulus
   `connect()` → `requestSubmit()`) so the table is populated, not just the
   form.
2. *Answer the question directly (medium):* a "By group" card on the stat
   page — one row per group the problem belongs to (or per group of the
   submitting users): users, attempted, solved, mean best score. Data:
   `Submission.regular.where(problem:)` → best points per user, joined to
   `groups_users` (honour `enabled`, drop editor/reporter roles like the
   report's "Exclude editors and reporters"). Scope to
   `@current_user.groups_for_action(:report)`. Each row links to the
   max-score report prefilled with problem + group via (1).
- Ship (1) even if (2) lands — the report keeps the per-user drill-down.

**Size.** (1) small. (2) medium — query, view, auth scoping, test.

---

## Viva problem edit page — right column is empty, left column crammed — RESOLVED 2026-08-28

**Resolution (rev 2031).** Option (A), one form over both columns: Detail card
left, Viva Exam card right (Scenario + briefing full width, then interview
setup). The Hint and Description tabs are dropped for viva problems (hints are a
code-submission feature; their frames were what kept the form from spanning the
row — `form=` was rejected because Rails does not propagate it to a multiple
select's hidden input). Type switches redraw the whole `#problem-edit` body on
save; a dataset-less problem now gets an "Add dataset" empty state.

**Why it matters.** `/problems/:id/edit` is a fixed two-column layout
(`app/views/problems/edit.html.haml`): left `.col-md-6` = Detail card holding
the whole problem form, right `.col-md-6` = Dataset card. For `viva_exam?`
problems the right card degenerates to a heading plus one explanatory
paragraph ("Test-case datasets do not apply"), while everything
viva-specific is stacked in the left half at horizontal-form width:
grounding-materials select + attached list, Examiner briefing (`rows: 14`,
~5k chars), Conduct profile, soft/hard cap, daily limit (all in
`_form.html.haml:71-99`, General tab), plus the Scenario editor (`rows: 20`,
~2k chars) on the Description tab. Half the viewport is blank; the other half
is a long scroll of narrow textareas. Raised by dae 2026-08-28.

**Current state (confirmed 2026-08-28) — constraints that shape any fix.**
- The form is **one `simple_form_for` inside `turbo_frame_tag :problem`**
  (`_form.html.haml:2,11`) and lives entirely in the left column; the right
  card is a separate turbo frame (`:dataset`) with its own controllers
  (`bs-tab dataset-mode-toggle`). Inputs cannot simply be moved to the right
  column — they would fall outside the `<form>`.
- `viva_exam_toggle_controller.js` (show/hide `showForViva` / `hideForViva`
  targets) is scoped to the `:problem` frame; it already broadcasts
  `mode:compilation-type-changed` on `window` for the right card, so
  cross-column reactivity has a precedent.
- Scenario sits under the **Description** tab and the briefing under
  **General** — authors flip tabs between "exam paper" and "marking scheme"
  even though the hints say they are written together.
- The HTML5 `form="…"` attribute trick is already used on this page (PDF
  Delete button, `_form.html.haml` ≈`:133-146`) to place a control outside
  its `<form>` element.

**Options.**
- (A) *Viva-specific layout of the same form (preferred).* When
  `@problem.viva_exam?`, let `edit.html.haml` render the `:problem` frame
  across the full `.row` and have `_form` lay out a two-column grid *inside*
  the form: left = Identity / Statement & Files / Access / Compilation (the
  existing General tab), right = a "Viva Exam" card with grounding +
  briefing + conduct + caps + daily limit, and the Scenario editor pulled
  out of the Description tab into that column (or a second right-column
  card) so briefing and scenario sit side by side. The dataset frame is
  already not rendered for viva. Cleanest DOM; touches only the viva branch.
- (B) *`form=` attribute.* Leave the form in place and render the viva
  inputs in the right card with `form: 'edit_problem_<id>'` on each input.
  Works, but simple_form wrappers and `viva-exam-toggle` targets need
  per-input `form=` plus a widened controller scope — fiddlier than (A).
- Not an option: a second `<form>` on the right posting separately (split
  save/validation).

**While there.** With the wider column, switch briefing/scenario to
`wrapper: :vertical_form` (full width, as `description` already is) and pair
with the markdown-editor entry above. Non-viva layout stays unchanged.

**Size.** Medium — `edit.html.haml` + `_form.html.haml` restructuring,
`viva-exam-toggle` scope check, system-test update (`test/system/problem*`),
rendered before/after screenshots for dae's approval (per convention).
