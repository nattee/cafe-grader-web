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

## Viva grade display — narrative doesn't belong in `grader_comment` / main list

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

## OpenRouter LLM provider — design sketch (no implementation scheduled)

Per the 2026-07-30 placement decision (`doc/decisions.md`), OpenRouter is a
**master-side** provider: any deployment with its own API key can use it, so it
must never require the chula_cp branch.

**Shape when it lands:**
- `Llm::OpenRouterChat` — sibling of `Llm::SelfHostChat`. Extract the shared
  OpenAI-compatible payload build + `choices`/`usage` parsing into a mixin
  (e.g. `Llm::OpenAiCompatPayload`) at that point, not before. Differences
  from self-host: `Authorization: Bearer` header (key from
  `Rails.application.credentials.llm.openrouter.api_key` — NEVER in llm.yml,
  which is checked in), real `compute_cost` (OpenRouter returns usage/cost;
  per-1K fallback rates in config), slash-namespaced model ids
  (`anthropic/claude-…`), no `/v1/models` identity guard (the hosted API
  validates model names itself).
- Config: a separate `openrouter:` section in `llm.yml` (model list + default),
  NOT extra fields on `self_hosted_models:` — keeping the self-host invariants
  (no auth, cost 0, swap-slot identity guard) explicit rather than optional.
- Registration reuses both existing mechanisms unchanged: per-model map entry
  (`OpenRouterAssist: anthropic/claude-…,google/gemini-…`) for the assist
  picker; `submission_repair_service: Llm::SubmissionRepairOpenRouterAssist`
  as an alternative repair provider.

## Near-Miss: Genie repair provider (chula_cp-side follow-up)

`Llm::SubmissionRepairGenieAssist` can only live on chula_cp
(`Llm::GenieAssist`/`Llm::TokenManager` exist only there). Small class:
subclass `Llm::SubmissionRepairAssist`, implement `execute_chat` via the Genie
connection/token plumbing, set per-1K rates in `compute_cost`, wire via
`submission_repair_service:` if Genie repair is ever preferred over self-host.
