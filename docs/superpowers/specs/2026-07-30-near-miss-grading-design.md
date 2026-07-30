# Near-Miss Grading (v1: batch instrument) + Qwen LLM provider — Design

- **Date:** 2026-07-30
- **Status:** approved design, pre-implementation
- **Feature name:** Near-Miss Grading (student-facing name deferred; shortlist: "Second Chance", "Lifeline")
- **Internals name:** `SubmissionRepair` (mechanism-named); rake namespace `near_miss:`
- **Key metric:** *mechanical gap* = `repaired_score − original_score`

## 1. Problem & motivation

The grader is rigidly summative: a submission that fails input parsing, output
format, or compilation scores 0, indistinguishable from a submission with no
algorithmic understanding at all. The current instrument has a **floor effect**
— it measures nothing below "compiles and parses I/O correctly", which is
exactly where below-average students live.

Near-Miss Grading removes that floor with **bounded-repair evaluation**: an LLM
proposes the smallest fix it can within an explicit modification budget (e.g.
2 lines / 20 chars), a deterministic gate rejects any over-budget patch, and
the *real judge pipeline* grades the patched code. A small budget naturally
captures mechanical failure classes (I/O format, parsing, syntax, off-by-one)
and excludes algorithmic rewrites — precisely the pedagogical line: forgive
mechanical errors, not conceptual ones.

**v1 is a research instrument, not a student feature.** It runs from the
command line over a contest's submissions and produces data (mechanical-gap
distribution, fix-category histogram, repair-size distribution) so the
student-facing pedagogy (lifeline economy, staged hints, real-time repair) can
be chosen from evidence later. No UI, no score changes, no student visibility.

## 2. Goals (v1)

1. Repair engine: LLM proposes a bounded fix → deterministic LLM-free gate →
   accepted patches graded by the normal judge as linked shadow submissions.
2. Batch CLI: `rake near_miss:repair` over a contest (or narrower target) +
   `rake near_miss:report` producing the analysis tables.
3. **Qwen provider (second feature):** a shared OpenAI-compatible transport for
   the department's self-hosted DGX models, wired into *both* Near-Miss repair
   and the existing submission assist (`Llm::CommentAssist` family).
4. Full accounting per attempt: tokens, dollar cost, rounds, fix category, raw
   response — viva-style, so `/report/ai`-grade cost visibility exists from
   day one.

## 3. Non-goals (v1)

- No student-facing UI, lifeline economy, or real-time repair flow.
- No effect on real scores — shadow submissions are excluded from every
  student-visible query and quota count; scoring policy (penalties, caps) is
  deliberately undesigned until the batch data exists.
- No new `GraderConfiguration` keys — budgets are rake parameters. Admin-editable
  defaults arrive with the student-facing phase.
- No web report page; console/CSV output only.
- No AST-based or comment-stripping diff metrics (keep the gate explainable).

## 4. Decisions already made (brainstorm outcomes)

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Fixed budget, stated to the LLM, **enforced by a deterministic gate** computable without any LLM | Owner decision. The score is never an LLM opinion; the gate is auditable and immune to prompt injection via source code |
| D2 | Evaluation channel = **shadow submissions** through the normal judge pipeline, with explicit linkage to the original | Real scores with identical semantics (sandbox, dataset, partial credit); zero judge-worker changes. Alternatives rejected: separate channel (requires external-worker changes), in-task evaluation (non-comparable scores) |
| D3 | LLM returns the **complete corrected file**, never a diff | Models mangle diff syntax; the gate diffs original-vs-returned deterministically anyway |
| D4 | Rounds hard-capped at **1 + 1** (one attempt, one retry with the rejection reason) | Per-submission cost ceiling |
| D5 | Batch target selection defaults to **latest submission per (user, problem) scoring below full marks** | 10–20× volume cut with no loss for the research question |
| D6 | **Qwen is the default provider** for repair; ChulaGenie secondary | Self-hosted DGX ⇒ marginal API cost ≈ 0; this *is* the cost strategy |
| D7 | Interaction model (staged ladder vs one-click vs mode-split) **deferred** until batch data exists | Owner decision |

## 5. Data model

### 5.1 New table `submission_repairs` — one row per attempt, including failures

| Column | Type | Notes |
|---|---|---|
| `original_submission_id` | FK → submissions, indexed, required | |
| `repaired_submission_id` | FK → submissions, nullable | set only when the gate accepts; the shadow submission |
| `status` | string/enum | `pending → processing → accepted \| over_budget \| no_change \| error` |
| `patch` | text | normalized unified diff **we** computed (display/analysis) |
| `changed_lines`, `changed_chars` | int, nullable | measured by the gate (null when no parseable file returned) |
| `budget_lines`, `budget_chars` | int | budget in force at generation |
| `rounds_used` | int | 1 or 2 |
| `fix_category` | string, nullable | LLM self-report, validated against `io_format \| parsing \| syntax \| boundary \| logic \| other`; invalid ⇒ `other` |
| `llm_model` | string | |
| `token_count_in`, `token_count_out` | int | from `usage`; reasoning tokens count in `completion_tokens` |
| `cost` | float | dollars; 0.0 for Qwen but tokens still recorded |
| `llm_response` | mediumtext | raw final response body, for auditing |
| `remark` | text, nullable | LLM's one-sentence reason / error detail |
| `run_label` | string, indexed | groups a batch run; makes budget experiments comparable |
| timestamps | | |

Grading state and score of the repaired code live on the shadow `Submission`
row — **not duplicated here**. Reports join.

Status meanings: `accepted` = gate passed, shadow created and sent to judge;
`over_budget` = LLM produced code but every round exceeded budget;
`no_change` = normalized sources identical or LLM declared it unfixable within
budget; `error` = LLM/transport failure after job retries.

### 5.2 `submissions` gains `repaired_from_id`

Nullable self-referencing FK, indexed. Presence = shadow submission.

- New scope **`Submission.regular`** = `where(repaired_from_id: nil)`.
- **Rule: every student-visible query and every quota count reads
  `Submission.regular`.** Known sites to audit during implementation (the plan
  greps exhaustively): MainController list/max-score rollups
  (`prepare_list_information`), SubmissionsController index cost rollup,
  contest scoring reports (`Contest`, `ReportController` scoreboards),
  plagiarism/submission comparison, the viva daily-start-limit count
  (`viva_sessions_controller`), per-problem submission stats.
- Shadow submissions are **admin-visible only** in v1 (`can_view_submission?`
  denies students for shadows; simplest: shadows fail the ownership check by
  policy, since students should not discover the instrument through the UI).

Linkage is written twice — `repaired_from_id` on the shadow row and
`repaired_submission_id` on the attempt row — created in the **same
transaction** so they cannot drift.

### 5.3 Shadow submission semantics

Created via direct model create (no controller policy checks): same `user`,
`problem`, `language`; `source` = patched full file; `submitted_at` = creation
time (harmless — shadows are excluded from window-scoped queries);
`repaired_from_id` = original. Graded through the standard
`add_judge_job`-style path at **batch priority, below interactive rejudge**
(rejudge uses −10, dataset rejudge −50; near-miss uses a lower priority still —
exact value fixed in the plan after reading the priority ordering).

## 6. Budget gate (deterministic, LLM-free)

Pure service `SubmissionRepair::Gate` — heavily unit-tested; no I/O, no LLM.

1. **Normalize** both sources: CRLF/CR → LF; strip trailing whitespace per
   line; ensure single trailing newline. Nothing else (no comment stripping,
   no reindentation — keep it explainable).
2. **Diff** with `diff-lcs` (add as an explicit runtime dependency; today it is
   only a transitive RSpec dep), producing unified hunks. `patch` column stores
   this diff.
3. **Measure:**
   - `changed_lines`: per hunk, pair deletions with additions in order; a
     paired (delete, add) counts as **1 modified line**; unpaired lines count
     1 each. Hunk contribution = `max(deletions, additions)`; sum over hunks.
   - `changed_chars`: for each paired line, the character-level Levenshtein
     distance between the two normalized lines; for unpaired added/deleted
     lines, the full normalized line length. Sum over hunks.
4. **Accept** iff `changed_lines ≤ budget_lines` **AND**
   `changed_chars ≤ budget_chars`.
5. Identical normalized sources ⇒ `no_change`.

## 7. LLM service layer (viva registration pattern)

### 7.1 `Llm::SubmissionRepairAssist < Llm::Request` (abstract)

- `prepare_data` builds the prompt from:
  - problem statement PDF part (`encode_pdf_part`, as `CommentAssist` does);
  - original source (wrapped with the existing prompt-injection defense
    framing — source is untrusted input);
  - human-readable verdict: per-testcase results decoded from
    `grader_comment`, compiler output when the submission failed to compile;
  - the budget, stated explicitly ("you may change at most N lines and M
    characters");
  - output contract: *return the complete corrected file* in a fenced block,
    plus one category token from the `fix_category` enum and one sentence of
    reason. If no within-budget fix exists, say so explicitly (⇒ `no_change`).
- `handle_response`: extract file → `Gate` → on accept, one transaction
  creates the shadow submission + marks the row `accepted`; on gate rejection
  (or unparseable output, per §10), **one** retry with the rejection reason
  appended; a second gate rejection ⇒ `over_budget`.
- `compute_cost(usage)` — viva-style token/cost extraction.
- Abstract hooks per the existing pattern: subclasses supply `provider_name`,
  `execute_call(data)`, cost rates, `DEFAULT_MODEL`.

### 7.2 Concrete providers & registration

- `Llm::SubmissionRepairQwenAssist` (default) and
  `Llm::SubmissionRepairGenieAssist`.
- Registered via a new `submission_repair_service:` key in `config/llm.yml`
  (same pattern as `viva_turn_service:`), overridable per-run by the rake
  `SERVICE=` parameter.

### 7.3 `Llm::SubmissionRepairJob < Llm::RequestJob`

Standard retry taxonomy inherited; `on_retries_exhausted` marks the
`SubmissionRepair` row `error` so nothing freezes in `processing`.

## 8. Qwen transport & submission-assist provider (second feature)

### 8.1 `Llm::QwenChat` — shared transport

OpenAI-compatible `POST {base_url}{completion_path}` (`/v1/chat/completions`),
JSON, **no auth** (intranet-only DGX), via the existing Faraday factory
(`Llm::Request.connection`, 300s timeouts — comfortably above the 120s the
reasoning models need). Ported lessons from cp-api
(`~/cp-api/docs/llm-api.md`, `llm_service.rb#chat_completion`):

- **omit `repetition_penalty`** (degrades reasoning traces);
- **`max_tokens ≥ 4096`** (reasoning tokens count against the budget; small
  budgets yield empty `content`);
- tolerate `reasoning_content` in responses; answer text is
  `choices[0].message.content`;
- extract `usage.prompt_tokens` / `usage.completion_tokens`;
- connection refused / host unreachable is **normal operation** for a
  swapped-out DGX slot (ports 8000–8002 share GPUs; exactly one is alive) —
  classify as retryable connection error, never as a code bug.

Config: `qwen:` section in `llm.yml` (`base_url`, `completion_path`, `model`,
`max_tokens`). Real values on `chula_cp`; blank/commented on `master` — same
convention as the viva service keys. No credentials involved.

### 8.2 `Llm::QwenAssist < Llm::CommentAssist`

Submission-assist provider using the shared transport. Registered in the
per-model provider map: `QwenAssist: qwen3.5` in `llm_services`, which makes it
appear in the existing assist model picker. **Known quirk to respect:** the
`llm_assist` route addresses models by *index* into
`Rails.configuration.llm[:provider].keys`, and
`_add_assist.html.haml` hardcodes `cost: 10` — the plan must verify adding a
model does not silently shift existing indices in views/links. Dollar cost for
Qwen is 0.0; token counts are still recorded (`compute_cost` returns 0 with
usage logged).

## 9. Batch runner & report

### 9.1 `rake near_miss:repair`

```
rake near_miss:repair CONTEST=<id> [PROBLEM=<id>] [SUBMISSION=<id>]
     [BUDGET_LINES=2] [BUDGET_CHARS=20] [SERVICE=qwen|genie]
     [RUN=<label>] [LIMIT=<n>] [DRY=1]
```

- Target selection (default): latest submission per (user, problem) within the
  contest with score below full marks — including compile errors. `Submission.regular`
  only (never repair a shadow).
- `DRY=1` prints target count + breakdown and exits. `LIMIT` caps targets for
  pilot runs. `RUN` defaults to a generated label (`contest<id>-<date>`).
- Enqueues one `Llm::SubmissionRepairJob` per target; Solid Queue's queue
  concurrency naturally throttles the DGX. Attempt rows are created `pending`
  up front so a crashed run is enumerable and resumable (re-run skips
  submissions that already have a row with the same `run_label`).

### 9.2 `rake near_miss:report RUN=<label>` (or `CONTEST=<id>`)

Per-problem table: targets, attempts by status, repaired-and-improved count,
**rescue rate** (fraction of below-full targets whose shadow scored higher),
mean/median mechanical gap, fix-category histogram, distribution of measured
repair sizes (which shows how much of the budget real fixes actually used).
Plus a run-level cost line: total tokens in/out, dollar cost, LLM rounds.
Console table + CSV export (path printed).

## 10. Error handling

- Transport/HTTP errors follow the existing `RequestJob` retryable taxonomy;
  exhaustion ⇒ row `error` with the exception in `remark`.
- Unparseable LLM output (no fenced file found) consumes a round like a gate
  rejection (the retry says so); two failures ⇒ `error` with raw body stored.
- The gate itself cannot fail soft: any exception there is a bug and should
  raise loudly (no rescue).
- Shadow-submission grading failures are ordinary judge errors, visible on the
  shadow row like any submission; the report counts them separately.

## 11. Testing

Written after the feature (owner's stated preference), all minitest:

- **Gate:** heavy pure-function coverage — pairing rules, both caps,
  normalization, no-change, unparseable input.
- **Scopes:** `Submission.regular` exclusion asserted at each audited site
  (model/controller level).
- **Service:** `handle_response` paths (accept/over-budget/retry/no-change/
  garbage) with a stubbed transport; transaction atomicity of shadow+row.
- **QwenChat:** request-shape (omitted `repetition_penalty`, `max_tokens`
  floor) and response parsing incl. `reasoning_content`, via stubbed Faraday.
- **Rake:** target-selection query + DRY mode smoke test.

## 12. VCS & deployment notes

- All commits on **`master`** (bookmark-gated per standing convention);
  `chula_cp` receives via the usual batch merge. `llm.yml` service keys and
  Qwen endpoints get real values on `chula_cp` during the merge, mirroring the
  viva-keys convention.
- CHANGELOG: one `### Added` bullet (instructor-facing capability) in the
  same commit series.
- The Genie concrete classes for viva exist only on `chula_cp`;
  `Llm::SubmissionRepairGenieAssist` must depend only on what `master` has
  (`Llm::GenieAssist`-level plumbing, `TokenManager`), which it does.

## 13. Future work (explicitly out of scope, recorded so it isn't relitigated)

- Student-facing surface: staged ladder (hand-edit within budget → "a fix
  exists near X" hint → show diff → apply), lifeline economy via the existing
  `comments.cost` machinery, mode-split behavior — **to be chosen from the
  batch data**.
- Naming of the student surface ("Second Chance" / "Lifeline").
- `GraderConfiguration` keys for admin-editable default budgets; per-problem
  budget overrides.
- Web report page under `/report`; budget-curve experiments via multiple
  `run_label`s.
- Practice-mode feedback surface ("your code is 12 chars from passing").
