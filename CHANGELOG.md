# Changelog

All notable changes to this project are recorded here. Format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The `[Unreleased]` section at the top accumulates changes between releases.
When a release is cut: rename it to `[X.Y.Z] — YYYY-MM-DD`, bump
`APP_VERSION`, and (optionally) tag the commit in hg/git.

## [Unreleased]

### Fixed

- **Viva grading model no longer depends on how the interview ended** —
  the done-sentinel path passed the interview model into
  `Llm::VivaGradeAssistJob` while the hard-cap path used the grade
  service's default, so one cohort could be graded by two different
  models. Both paths now use the grade service's default; only the admin
  "Re-run grading" picker passes an explicit model. (rev 2011)

### Added

- **Failed-attempts tab on the Login report** — the Logins report
  (Report → Login) gains a third tab listing failed password attempts (web
  and API) in the selected date range: attempted login string, matched user
  (when the account exists), time with seconds, and source IP. The user/group
  filter deliberately does not apply — most failures match no user. Data
  comes from the failure rows recorded since rev 2002. (rev 2003)

- Viva grounding: one-click PDF→markdown extraction producing a review-first draft (author must copy/edit into the body; body text replaces per-turn PDF re-sending once saved).
- Viva: alert-review admin page (Graders → Viva alerts) listing flagged sessions with the triggering student utterance — the jailbreak-calibration instrument for the practice month.
- Viva: examiner briefing (`viva_prompt`), turn caps, and per-turn jailbreak-alert flags — schema + model groundwork (Phase 1 of the 2026-07-20 deployment-readiness design).
- Viva retakes: students restart their own viva session themselves (archives the old one, subject to the daily start limit); admin archive-and-retake remains available for any viva.
- Viva: `viva:migrate_prompt_tags` rake task (report-first, `APPLY=1` to execute) migrating legacy per-problem `llm_prompt` tags into `viva_prompt` and shared ones to `viva_conduct`.
- Viva turn caps: per-problem soft cap (examiner pacing instruction, default 10) and hard cap (force-finish + grade, default 15).
- **`problems:replay_validate` rake task** — validates the problem import/export
  path by re-importing a problem and replaying a stratified sample of its
  submissions through the grader, diffing per-testcase results against the
  originals' stored grades (only `T→P`/`x→P` treated as benign). Dev diagnostic;
  self-cleaning, with `problems:replay_purge` as a backstop.
- **Problem import warns when a `group_min` group has mixed testcase
  weights** — group-min scoring uses one weight per group (the minimum);
  heterogeneous weights inside a group are an authoring error.
- **Dataset editor also warns about mixed `group_min` weights** — the same
  check now runs live on the Testcases tab (shared `Dataset#mixed_weight_groups`):
  a banner lists each offending group with its weights and effective (minimum)
  weight, and a per-row marker flags the affected testcases. Only shown under
  Group Min scoring.
- **Testcase config accepts CMS-style codename regexps** — the weight/group tool
  now takes `[[weight, "1-.*"], [weight, "2-.*"]]`, grouping testcases by a
  regexp matched against `code_name` (start-anchored, mirroring CMS `re.match`),
  alongside the existing `[weight, count]` form. The box gains inline examples
  and a "Syntax & CMS notes" help drawer; the full grammar and how it differs
  from CMS `GroupMin` parameters (normalized weights vs absolute points) are
  documented in `doc/dataset-scoring-and-evaluation.md`.
- **Multi-dataset problem export/import** — a problem's non-live datasets can now
  be included in its export archive ("Download (all datasets)" on the problem
  page, `Problem#export(all_datasets: true)`, or `rails "problems:export[name,all]"`),
  and are re-imported as additional (non-live) datasets. The zip format is a
  backward-compatible superset: old archives import unchanged, and the default
  "live dataset only" export is structurally compatible with previous versions
  (same files; imports identically).
- **Grounding materials: a dedicated model + admin library** (Manage → Grounding)
  for viva reference material, replacing `viva_grounding` tags. Files are sent
  to the interviewer/grader as PDF `image_url` parts; the library shows a
  per-item token estimate and problem-reuse count.
- **Near-Miss Grading (batch instrument)**: `rake near_miss:repair` runs bounded
  LLM repair over a contest's failing submissions (deterministic budget gate;
  accepted fixes graded by the normal judge as student-invisible shadow
  submissions linked via `submissions.repaired_from_id`), and
  `rake near_miss:report` produces rescue-rate / mechanical-gap / budget-compliance
  analysis. Spec: `docs/superpowers/specs/2026-07-30-near-miss-grading-design.md`. (revs 1928–1937)
- **Self-hosted LLM provider**: generic OpenAI-compatible transport
  (`Llm::SelfHostChat`, configured via `self_hosted_models:` in `config/llm.yml`)
  with a submission-assist provider (`Llm::SelfHostAssist`) and the Near-Miss
  repair provider. Model identity is config data; no credentials (intranet). (revs 1928–1937)
- **Near-Miss run browser** (Report → Near-Miss Runs, admin-only): web report
  over repair batch runs — run list with outcome/token/cost rollups, per-problem
  rescue-rate / mechanical-gap / budget-compliance tables (multiple runs render
  side by side for budget and model comparisons), and per-attempt drill-down
  showing the measured patch, rounds log, category, tokens/cost, and links to
  the original and shadow submissions. (rev 1949)
- CMS task clone: `rails "cms:clone[task]"` imports a Batch task (all datasets)
  straight from a live CMS server over ssh — official dump subtree + selective
  blob fetch on the server, converted to the cafe package layout and imported
  through the trusted importer. GroupMin (count and regex forms) maps to
  `group_min`; Communication/OutputOnly, file-I/O, and GroupMinPrereq tasks are
  rejected with clear messages (per-dataset skip when non-active). Connection
  settings live in `config/cms_remote.yml` (gitignored; sample committed). (revs 1960–1965)
- **`cms_comparator` evaluation type**: user checker invoked with CMS's own
  argv order (`input, correct, user`), distinct from the legacy `custom_cms`
  order (`input, user, correct`) that existing cafe problems depend on;
  `Converters::CmsDumpConverter` now maps CMS's `comparator` evaluation mode to
  it, unblocking correct import/grading of checker-based CMS comparator tasks.

### Changed

- **Submit authorization now flows through one predicate**
  (`User#can_submit_to_problem?`): the web submit, the JSON API, viva start,
  the submit-form UI, and the model-layer validation all share the same gate.
  An editor's test-submit right on draft/hidden problems in their own groups —
  previously web-only — now also applies to the API and to starting a viva
  (intended design: viva authorization matches normal problems). (rev 1996)
- Viva: the examiner prompt now lives on the problem (`viva_prompt`, audited/redacted) layered with optional shared `viva_conduct` tags in a fixed order; `llm_prompt` tags are again exclusively the AI-helper's namespace.
- **Viva grounding is now attached to problems via a viva-only "Grounding
  materials" selector** (with a per-problem token total) instead of the mixed
  Tags dropdown; the `viva_grounding` Tag kind is retired and existing tags
  backfilled.
- Viva jailbreak handling: the examiner now only *detects* (staying in character); the backend applies policy — flags are logged and a notice is shown to the student, never terminating the interview (was: immediate termination on any detection). The warn-then-terminate machinery from the original design stays in the codebase, dormant, for the Phase B per-contest policy below.
- Viva authoring: the Description tab is now the "Scenario (markdown)" for viva problems (sent verbatim to the examiner; side-PDF generation disabled), with the examiner briefing, conduct profile, and turn caps edited together in the problem form; only `viva_conduct` tags are hidden from the generic tag picker (they have their own dedicated Conduct-profile select) — `llm_prompt` tags remain in the generic picker since it's the only UI that attaches them (to the AI-helper) and can never be public.
- **Viva: practice/exam mode replaced by context-based policy** — every viva is practice outside contests, limited by a per-problem daily start limit (blank = site default, 0 = contest-only); exam strictness returns as per-contest retake budgets in Phase B.
- **Near-Miss LLM-call hardening** — the self-host transport allows 600s reads
  (16384-token reasoning generations legitimately exceed the stock 300s); a
  round truncated at `max_tokens` with empty content now fails the attempt
  immediately with a "raise max_tokens" remark instead of burning retry
  rounds; compile-error verdicts no longer decode the literal "Compilation
  error" string into nonsense per-testcase lines. (rev 1954)

### Fixed

- **Problems manage page: viva rows offer Start Viva / View Viva** instead of
  the code-editor Submit button, which bounced viva problems to the main list
  — a dead end for a student-hidden viva (in-group switch off), since the
  student-scoped main list never shows it. Together with the editor
  test-start right (rev 1996) this makes hidden vivas actually startable by
  the group's editors and admins. (rev 2000)
- **Model-layer submit-authorization validation was a silent no-op since the
  Rails 6.1 era** — `Submission#must_have_valid_problem` refused via
  `errors[:base] <<`, which registers nothing on modern Rails, and skipped
  binary submissions entirely (`return if source==nil`). Resurrected with
  `errors.add` on the shared submit gate; trusted server-side tooling (repair
  shadows, replay engines, model-solution import) bypasses explicitly with
  `save!(validate: false)`. (rev 1996)
- **Reporters no longer get a submit form they can't use** — on a problem
  hidden from students (in-group switch off) a reporter can view the problem
  but not submit; the editor page now renders view-only with a notice instead
  of a Submit button that always failed after the fact. (rev 1996)
- **Near-Miss report: ungradeable shadows are no longer counted as 0-point
  grades** — accepted attempts whose shadow has no real judge outcome
  (`grader_error`, or still in flight) are excluded from gap/rescue statistics
  and surfaced as an explicit `ungradeable` count in the rake report, CSV, and
  run browser (a judging-infrastructure failure previously read as mass
  negative gaps — the void a68_final lesson). (rev 1953)
- Viva: archive now refreshes the page, viva submissions no longer open the code editor (evaluations/download/compiler_msg included), students see retake policy and remaining daily starts.
- **"Import testcases" is stricter and no longer crashes on errors** — replacing
  into a dataset that no longer exists now shows an error toast instead of
  silently creating a new dataset; the testcases-only flow no longer overwrites
  the problem's public attachment when the uploaded zip contains an
  `attachment/` directory; and all import-testcases error paths surface as a
  toast (they previously raised a template error by re-rendering the standalone
  import page).
- **Problem import: `code_name_regex` now actually applies** — the custom
  code-name extraction regex accepted by `ProblemImporter` was parsed but its
  result discarded; testcase code names always fell back to the raw wildcard
  match.
- **Problem import: model solutions survive round-trips** — imported model
  solutions had garbled source filenames (`cpp_fibo.cpp` → `p_fibo.cpp`), were
  not tagged as model solutions (so the *next* export silently dropped them),
  and were attributed to an arbitrary user; they are now split on the first
  `_`, tagged `:model`, and owned by the importing user.
- **Problem import: empty "Full name" no longer blanks the title** — it now
  falls back to the short name (a `config.yml` `full_name` still wins).
- **Problem export now round-trips everything the author created** — the
  markdown description, `markdown` flag, `score_param`, and dataset data
  files were silently dropped by export (or never imported); an exported zip
  re-imports field-identical. `ProblemExporter.dump_problems` (console bulk
  export) no longer crashes on a typo'd default, and the exported statement
  is named `statement.pdf` (was `statment.pdf`).
- **Downloading the archive of a problem with no live dataset** shows an
  alert instead of a 500 error page.
- **Grounding material PDF/image attachments no longer crash the LLM
  request builder** — `GroundingMaterial#grounding_file_parts` iterates raw
  `ActiveStorage::Attachment` records (from a `has_many_attached` collection),
  which don't respond to `#attached?`; `Llm::Request.encode_pdf_part` was
  unconditionally calling it, so any viva turn/grade request for a problem
  with an attached grounding file raised `NoMethodError` instead of sending
  the file.
- Viva: API description endpoint no longer exposes the interview scenario to students; bulk dataset rejudge, hall-of-fame, admin testcases API, and grader backlog now handle viva submissions correctly.
- Viva: submissions stuck in "evaluating" after a worker crash are now swept to grader_error (regradable) and surfaced on the graders monitoring page.

### Security

- **Login brute-force throttling, pooled across the web form and the API** —
  failed password attempts are counted per client IP and per attempted
  account (30 failures within a sliding 3-minute window, sized well above
  real frustrated-student retry bursts at exam starts); once a budget is
  exhausted, further attempts are refused before any password check — web
  gets a redirect with an alert, the API its existing 429 — until the window
  drains. Both doors draw down the same counters, replacing the API's old
  per-controller `rate_limit` (which an attacker could sidestep by splitting
  attempts across doors, and which counted successful logins too). Failed
  attempts are now also recorded in `logins` (`success` flag +
  `attempted_login` column, migration required); login/cheat reports and the
  heartbeat user lookup were scoped to successful logins so failures don't
  pollute multi-IP cheat detection. A successful login clears the account
  counter (proof of ownership) but deliberately not the IP counter. No
  permanent per-account lockout on purpose: that would let anyone lock a
  victim out of an exam by hammering their login name. (rev 2002)
- **A disabled group membership row now revokes editor/reporter problem
  access** — previously a membership with `enabled=false` still conferred the
  editor's full problem-level powers (view, edit, test-submit, rejudge) and a
  reporter's view access; a disabled membership now grants no role at all,
  matching members (intended design: disabled editor IS NOT an editor).
  (rev 1996)
- **Problem import/export no longer builds shell strings** — unzip/zip run
  with argv-style exec (a hostile problem name could previously inject shell
  syntax), extraction directories are derived via `parameterize`, and a
  containment check rejects archives whose entries or symlinks escape the
  extraction directory (zip-slip).
- **Importing a problem under an existing name now requires edit rights on
  that problem** — previously any group editor could silently overwrite any
  problem in the system by importing a zip with the same short name. Admin
  re-import-to-update behavior is unchanged.
- **Viva: transcript/grade pages now enforce submission-view authorization**
  (were open to any logged-in user) — archived viva attempts are visible
  only to their owner and staff.
- **API `GET /api/v1/problems/:id/description` no longer leaks the viva
  interview scenario to students** — the description IS the hidden scenario
  for viva problems; the endpoint was missing the same `can_view_problem_pdf?`
  gate the sibling PDF endpoint already enforced.
- **API now honors single-user (lockdown) mode** (rev 1992) — enabling
  `system.single_user_mode` blocked web sessions but not the JSON API: a JWT
  obtained beforehand kept submitting, and `auth/login` even issued fresh
  tokens (exploited on 2026-08-19 during a pre-quiz lockdown; submissions
  934223–934226 on the algo grader). Non-admins are now rejected per-request
  and at login while the mode is on, and tokens issued before the last
  lockdown (`min_last_login_time`, bumped when the mode is switched on) are
  retroactively invalid — the API parallel of the web session kill. A new
  route-enumerating sweep spec asserts the no-token and lockdown gates on
  every `/api/v1` endpoint, so future endpoints are covered automatically.

## [4.4.2] — 2026-07-01

### Fixed

- **Report filters: user-group dropdown now respects reporter scope** — on the
  report filter pages (Best Score / Submissions / User Activity / AI Assist),
  the "Only users from this group" dropdown listed **every** group in the
  system for non-admins; it now lists only the groups the user can report on
  (`@groups`), matching the problem-group dropdown. No user data leaked (results
  were already intersected with `reportable_users`), but group names no longer
  do. The `login` analytics report now sets `@groups` so its user filter renders.

### Added

- **Role-aware scope help on the report pages** — each report filter page (Best
  Score / Submissions / User Activity / AI Assist) now shows an always-visible
  line stating what *you* can see (Admin: everything; Editor: full access incl.
  archived, listing your courses; Reporter: live courses only), with a
  "What you can see" drawer detailing every course you edit/report on and the
  three visibility switches. Answers "who can see what?" at the point of use.
- **Empty-report explanation for reporters** — a non-admin reporter whose
  problems are all unavailable or whose group is archived (disabled) reaches the
  report screen but sees no data (by design — `available` is an absolute
  student-exposure switch only admins bypass). The report filter pages now show
  an info notice counting the hidden problems and explaining why, instead of a
  silent empty table.

### Changed

- **Group editors are now content curators of their groups** — an editor can
  see, edit, and report on **every** problem in a group they edit, regardless of
  the problem's `available` flag or whether the group itself is disabled
  (archived). Previously the editor scope required `available: true` **and** an
  enabled group, so editors were locked out of their own draft (unavailable)
  problems and of any finished/archived course exactly like students — only an
  admin could get in. Reporters are unchanged: they remain scoped to available
  problems in enabled groups, and editor visibility stays a strict superset of
  reporter visibility. **Operational note:** to give a non-admin access to a
  finished/archived course, make them an **editor** of its group (a reporter
  still sees only live courses).
- **Report filters are archive-aware** — the group dropdowns now list an
  archived (disabled) group only for users who can still report on it (its
  editors), and mark it with an "archived" pill; reporters no longer see
  archived groups as dead-end filter options, and a reporter left with no live
  groups is turned away at the report gate instead of shown a blank screen.
- **Config templates pruned and made consistent** — `config/application.rb`
  is now tracked directly (it was ignored behind a byte-identical sample); the
  redundant `llm.yml` / `cafe_grader.rb` `.SAMPLE` files and the dead 2016-era
  `abstract_mysql2_adapter.rb.SAMPLE` were removed (the real configs are
  tracked and secret-free), and the identifiers in `credentials.yml.SAMPLE`
  were scrubbed. Fresh clones now boot without hand-copying samples (rev 1769).

## [4.4.1] — 2026-06-13

### Added

- **Per-user activity summary report** — one row per user over a
  time / submission-id range × problem set: submission count, problems
  tried, problems solved (raw_sum-scored datasets excluded — they have
  no defined full score), first/last submission, and distinct IPs.
  Optionally lists zero-activity users for the selected filter
  (highlighted, off by default). Runs as a single `GROUP BY` pass over
  submissions without touching the scoring engine, so even an
  all-problems window stays fast (rev 1758).

### Changed

- **Profile page redesigned** as a two-column identity card + settings
  layout — left: initials avatar, name, login badge, read-only
  email / default language / member-since; right: a Preferences card and
  a Change-password card. Controller and permitted params unchanged
  (rev 1763).
- **Per-problem "my submissions" table** restyled into the carded,
  hover/condensed UI used elsewhere, with real empty states, a `#id`
  link, filename-as-download with a language badge, a compact AI-assist
  badge, and an icon-only Edit button (rev 1764).
- **Grader-processes "Recent Submissions" card** gains a whitelisted
  `?limit=` toggle (20 / 100 / 500, default 20); Refresh and the
  10-minute auto-refresh preserve the chosen limit (rev 1761).
- **Footer slimmed** from a ~41px bar to a ~30px centered watermark —
  coffee mark, cafe-grader wordmark linking to GitHub, and a monospace
  `rev X.Y.Z` (rev 1762).
- **Updated-announcement cards** keep their shadow instead of going
  flat; the "updated" state now adds a 50%-opacity red border on top of
  the standard `shadow-sm` rather than replacing it (rev 1760).

## [4.4.0] — 2026-06-11

### Added

- **Management (write) API** under `/api/v1/` — the API is no longer
  read-only. All endpoints reuse the model-layer authorization
  (`can_edit_problem?`, group-editor scope, admin role) and write
  attributed audit rows:
  - **Problems**: `POST /problems` (creates the default dataset and live
    pointer atomically), `PATCH`/`DELETE /problems/{id}`,
    `PUT /problems/{id}/statement` (PDF upload).
  - **Datasets**: list/create under the problem,
    `PATCH /datasets/{id}` (settings), `DELETE` (refused for the live or
    last dataset), `POST /datasets/{id}/set_live`,
    `POST /datasets/{id}/files` + `DELETE /datasets/{id}/files/{attachment_id}`
    (checker / managers / data files / initializers).
  - **Testcases**: `POST /datasets/{id}/testcases` (file upload or plain
    text, CRLF-normalized), `PATCH`/`DELETE /testcases/{id}`, and
    `POST /problems/{id}/testcases/import` — bulk zip import through
    `ProblemImporter` with a single consolidated `import_testcases`
    audit row.
  - **Users** (admin only): paginated/filterable index, show, create,
    update (blank password = keep), delete (self-delete refused). Role
    granting stays web-only by design.
  - Every content-affecting dataset/testcase write invalidates workers'
    cached copy of the dataset (`WorkerDataset`), so judges re-download.
- **`expires_at` in the API login response** so clients know when to
  re-authenticate.
- **`bin/rails check`** — one task running every test suite plus the
  swagger freshness check (rev 1745).

### Changed

- **API token lifetime reduced from 7 days to 12 hours**
  (`Api::V1::AuthController::TOKEN_TTL`). Bearer tokens cannot be
  revoked server-side, so the TTL is the whole exposure window for a
  leaked token. Tokens issued before the deploy keep their original
  7-day expiry.
- **Submission language authority**: the problem's permitted-language
  set is now authoritative in the new-submission UI and enforced again
  at submit time (revs 1740-1741).
- **Announcement body previews render markdown** instead of stripped
  text (rev 1742).
- **Daily cleanups moved into Solid Queue's `recurring.yml`**
  (rev 1739).
- **Database collation standardized on `utf8mb4_0900_ai_ci`** across
  every table (MySQL 8 only; MariaDB unsupported), enforced by test
  (rev 1746).

### Fixed

- **`Dataset#invalidate_worker` never invalidated anything** — it
  referenced a nil instance variable, so the worker-cache delete
  matched zero rows. Also wired the (previously missing) invalidation
  into the web `testcase_delete` action: workers no longer keep grading
  against deleted testcases.
- **Dataset edit form adapts to checker/manager/main_filename state**
  (issue #48) and the score_type / evaluation_type UI now matches the
  engine semantics (revs 1737-1738).
- **API testcase endpoints de-confused `id` vs per-problem `num`**, and
  scores are emitted as JSON numbers (BigDecimal was serialized as a
  string); problem detail exposes `last_submission_id` (revs 1743-1744).

### Security

- **API login rate limiting** — 10 attempts/minute per client IP on
  `POST /api/v1/auth/login` (was unthrottled).
- **Disabled accounts are now refused API tokens and rejected
  per-request** even with a still-valid token (previously the `enabled`
  flag was only enforced by the web session flow).
- **API mutations carry audit actors** — `Current.user`/`Current.ip`
  are set for API requests, so audit rows from API writes are
  attributed instead of anonymous.
- **Viva exam hardening**: jailbreak attempts terminate the interview
  (`[[VIVA_ALERT]]` flow); answering restricted to the submission
  owner; problem PDFs hidden from students for viva problems; stuck
  assistant turns recover instead of silently hanging (revs 1722-1736).

## [4.3.3] — 2026-05-19

### Added

- **Help drawer on `/problems/:id/edit`** — a Bootstrap offcanvas panel
  opened by a labeled `? Help` button in the page header. Documents the
  Detail-card fields, dataset structure, operations, and links out to
  the project wiki. Pattern codified in `CLAUDE.md` as
  "context-dependent help" (inline knowledge cards on index/overview
  pages; offcanvas drawers on edit/detail pages).
- **`Live` badge in the dataset selector** marking the currently-live
  dataset. The `Set as live` button is shown only on non-live ones, so
  the state is never ambiguous.
- **PDF Export sub-section** on the Description tab with an explicit
  Delete button (uses a hidden-form pattern so it can't produce
  nested `<form>` tags).
- **CU pink + KU yellow-green gradient `C` favicon and navbar brand
  mark.** Single asset (`app/assets/images/icon.svg`) serves both the
  browser-tab favicon and the in-app brand mark — single source of
  truth.
- **`CHANGELOG.md`** itself (this file).
- **Dev-environment additions**: `listen` gem with
  `ActiveSupport::EventedFileUpdateChecker` replaces polling-based file
  watching (fixed multi-second WSL2 cascading-turbo-frame slowness);
  `rack-mini-profiler` + `stackprof` for in-app perf diagnostics.
- **`doc/backlog.md`** as the project's convention for tracking
  deferred design work (linked from `CLAUDE.md`).

### Changed

- **General tab of the problem editor** reorganized into 5 labeled
  sections (Identity / Statement & Files / Categorization / Visibility
  & Listing / Grading & Compilation), with `permitted_lang` moved into
  Grading & Compilation. Column split changed from 5/7 to 6/6 to give
  the form more room.
- **Description tab**: yellow info-card removed (content moved into the
  help drawer), textarea grown to 20 monospaced rows, dead `markdown`
  / `url` fields cleaned up.
- **Hint tab**: alert-wrapped selector replaced with a flat row,
  redundant labels dropped, Add/Delete separated, body field now a
  textarea, friendlier empty state.
- **Dataset selector**: alert wrapper stripped, redundant labels
  dropped, dropdown gets select2 styling, Add + Set-as-live remain
  visible while Rejudge + Delete move behind a `⋮` dropdown (per
  CLAUDE.md's Progressive Condensation rule).
- **Section headers unified** across both the problem form column AND
  the dataset card (Settings/Testcases/Files tabs) using
  `h5 fw-bold text-body-emphasis pb-2 border-bottom`.
- **`compilation_type` field** switched from a `<select>` (with an
  off-feeling blank option) to vertically-stacked styled radio buttons.
- **Server-mutating clicks across dataset views** migrated from legacy
  `link_to … data: { turbo_method: … }` to `button_to` and
  hidden-form + HTML5 `form="..."` patterns per CLAUDE.md.
- **Per-testcase row actions** redesigned as three visible icon-only
  buttons (input / output / delete) with tooltips, sharing three
  hidden forms (Flavor B); the testcase table also picks up the
  project's standard admin-table classes.
- **Per-file row actions** in the Files tab (managers / checker /
  initializers / data files) redesigned same way.
- **Grammar / wording sweep** across the problem editor: tooltip
  rewrites, confirm-dialog standardization ("Really delete X?" →
  "Delete X? This cannot be undone."), `score_type` option text
  rephrased, sentence-case consistency, etc.
- **`finance` Material Symbol replaced with `query_stats`** wherever it
  meant Statistics — clearer metaphor.
- **`llm.yml.SAMPLE` refreshed** to mirror the real config's schema,
  documentation, and environments.

### Fixed

- **AuditLog `destroy` callback** no longer raises "Auditable must
  exist" — the polymorphic `belongs_to` is now declared
  `optional: true`, matching the helper's already-correct treatment of
  destroyed records.
- **Quick-create on `/problems`** now refreshes the list. The previous
  `turbo_stream.append` of a `datatable:reload` event had no listener
  on this page; switched to a `redirect_to` with `status: :see_other`.
- **select2 dropdowns** now reliably fire `change` events into
  Stimulus. select2 v4 dispatches events through jQuery's event system,
  which doesn't always reach native `addEventListener` listeners that
  Stimulus' `data-action` relies on. A bridge in
  `init_ui_component_controller.js` listens for the jQuery
  `select2:select` event and re-dispatches it as a native `change`.
- **`simple_form_for` data-attribute collision**: passing both a
  top-level `data:` and an `html: { data: { … } }` silently dropped the
  top-level one. The dataset and hint selectors now consolidate
  everything into `html: { data: { … } }`. Footgun documented in
  `CLAUDE.md`.
- **Tooltip data-attribute encoding**: Rails' `link_to`-and-friends
  JSON-encode nested `data: { bs: { toggle: … } }` hashes (HAML
  flattens them with hyphens). Several tooltips on problem/contest/
  dataset edit pages were silently broken because the rendered attribute
  was `data-bs='{"toggle":"tooltip"}'` instead of `data-bs-toggle="tooltip"`.
  Migrated to flat `data: { bs_toggle: … }` form across the codebase.
- **WSL2 dev-mode cascading-turbo-frame slowness** (~2 s per concurrent
  request) diagnosed and fixed: the default polling
  `FileUpdateChecker` runs `Dir.glob` on every request and concurrent
  calls serialize on WSL2 inode locks. Switched to the evented variant
  (see Added).
- **`Language` model**: `name` is now enforced unique (via DB index) and
  immutable after create (via model validator). A migration
  idempotently re-runs `Language.seed`, so newly-added entries (e.g.
  `viva`) land on existing installations via `db:migrate` without a
  manual `db:seed` step. Language seed itself uses
  `find_or_create_by!` / `update!` so partial failures raise instead
  of leaving half-created rows.

### Internal

- Convention notes added to `CLAUDE.md`: flat data-attribute form for
  Bootstrap data attrs; offcanvas help-trigger labeling exception;
  context-dependent help-pattern split; backlog pointer; development
  environment (file watcher and profiler).
- Project-history memory entries added (branch workflow, simple_form
  data-collision gotcha, grep-existing-pattern-first principle).
- `doc/backlog.md` seeded with deferred items (help-pattern
  unification, AuditLog destroy test, orphan `contests/_contest_help`
  partial, drawer-content density rewrite).
