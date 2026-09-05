# Submission Assist ("Codey") — Change History

What we changed in the AI helper on coding submissions, why, and how it turned
out. Newest first. This is the *timeline*; the study that measures the feature
is `doc/assist-corpus-eval-2026-09-03.md`; the prompt text itself is versioned
in the local `course-prep` hg repo under `assist/`.

**How to add an entry** (rule in `CLAUDE.md` → "Viva & Assist Live Docs"): any
commit that changes assist behavior, the payload sent to the model, the prompt
text (the `codey-*` tags), the models or providers in the picker, or the
price/access policy adds an entry here *in the same commit*, shaped **Problem
observed → Change → Outcome / status**, with refs. Prompt edits cite
`course-prep rev N`. When an entry supersedes an earlier one, mark the old one
`SUPERSEDED YYYY-MM-DD by …`; never delete. Rev numbers are local hg revs of
`~/cafe-grader/web` (master unless marked `chula_cp`).

## Where the record lives

- **This repo (mirrored to GitHub):** the timeline (this file), the studies
  (`doc/assist-corpus-eval-*.md`), the platform code and its CHANGELOG. Nothing
  here may contain student code, tutor answers to real students, or the prompt
  text itself.
- **`course-prep` — a Mercurial repo on the instructor's workstation, not
  published anywhere:** path `~/cafe-grader/course-prep` on `dae-amd-2024`
  (WSL2 Ubuntu 24.04), started 2026-09-02; it holds exam papers and model
  answers, so it has no public remote by rule. Since 2026-09-04 it is mirrored
  to a **private** GitLab project (`gitlab.nattee.net/nattee/course-prep`, via
  hg-git; `hg push gitlab` after every commit there); before that the only copy
  was that disk. Contents for this feature: `assist/codey-core.md` and
  `assist/codey-thai.md` (the live prompt tags, versioned), the originals they
  replaced, and `assist/eval-<date>/` — every evaluation's data and scripts:
  the answers read, the readers' and judges' scores, the whole-corpus frames,
  the blind human-read form and its answers, UI screenshots. Cite
  `course-prep rev N` from entries here. Anyone reading this on GitHub or the
  wiki who needs the underlying data asks the instructor.
- **Production database (`grader` on 10.0.5.50):** the primary source — every
  request and answer is a `comments` row (`kind: llm_assist`), with the prompt
  tags in `tags`. Everything above is derived from it and can be regenerated
  with the scripts in `assist/eval-<date>/` against a fresh copy (the dump
  script is `~/dump_grader.sh` on the host).

## What the feature is

A student who is stuck on a graded submission can press **Get** under "AI help
by `<model>`" on the submission page. The platform sends the model a system
prompt (the `codey-*` tags), the statement PDF, the manager files, the student's
source and its verdict — since 2026-09-03 also the compiler output, the real
per-testcase table and the previous answer with a diff — and stores the reply
as a comment on the submission. The request costs the student **10 points** of
the problem's full score (the "reduced full score" mechanic: final score =
min(best score, 100 − penalties), floored at 0 since 2026-09-03). It is on
only when the site switch `system.llm_assist` is on, and in contest mode only
for contest problems flagged `allow_llm`. Only the submission's owner (or an
admin) may request it (since 2026-09-03).

## Eras at a glance

| # | Era | Dates | Characterization |
|---|-----|-------|------------------|
| 6 | Review, hardening, rebuild | 2026-09-03 | Code review found seven defects (any user could charge any student; index-addressed model; negative scores; raw-HTML answers); payload rebuilt around what the grader knows; picker guards + spend cap; dollar/token accounting; two prompt copies collapsed into `codey-core` + `codey-thai`; first corpus evaluation (291 answers read); this document. |
| 5 | New providers, new models | 2026-07-30 → 08-30 | Self-hosted DGX provider; Genie roster refresh makes gemini-3.1-pro the default and *un-breaks* Claude-Sonnet (silently downgraded since Feb); Chula AI Gateway family adds claude-opus-4-5 and gemini-3.7-flash to the picker; gateway-reported cost. |
| 4 | Tag taxonomy | 2026-07-20 → 07-21 | Viva moves off `llm_prompt`; the kind now means exactly "AI-helper system prompt"; the generic tag picker keeps offering it (D6 amendment). |
| 3 | Refactor | 2026-05-07 → 05-19 | `Llm::Request` hierarchy; comment-assembly lifted from `GenieAssist` into `CommentAssist`; the score-penalty semantics regress and are restored the same day; `preview` tooling; `llm.yml.SAMPLE`. |
| 2 | Two semesters live | 2025-07-23 → 2026-05 | ~2,370 requests each semester on gemini-2.5-pro + Claude-3.5-Sonnet via ChulaGenie; managers added to the payload; contest score views show the penalty; Claude path breaks on PDFs (Feb–Mar 2026) and the Genie rename leaves the picker effectively single-model from Feb 14. Prompt text frozen. |
| 1 | Birth | 2025-06-29 → 07-17 | Comments gain LLM columns; `GenieAssist`; "acquire" confirm dialog with the 10-point price; per-model provider map in `llm.yml`; site switch; contest `allow_llm`; tags gain `params` and the `llm_prompt` kind — the prompt moves out of code into a tag. |

## Lineages (the same story told per thread)

- **Models actually running in prod:** gemini-2.5-pro + Claude-3.5-Sonnet via ChulaGenie (2025-07-23 →). Claude-3.5-Sonnet: 74 HTTP-400s Feb–Mar 2026 (Anthropic rejects the PDF sent as `image_url`), last answer 2026-03-03. Config renamed it `Claude-Sonnet` on 2026-02-14 (rev 1498) but the class's allowlist still said `Claude-3.5-Sonnet`, so every Claude request was **silently served by gemini-2.5-pro until 2026-08-23** (rev 2006). gemini-2.5-pro last answer 2026-08-23 (dropped from the picker, not from the relay — `Llm::GenieAssist.list_model` still lists it on 2026-09-03; relay retirement expected ~2026-10). Then: gemini-3.1-pro + Claude-Sonnet (Genie, 08-24 →), claude-opus-4-5 (Gateway, 08-27 →), gemini-3.7-flash (Gateway, 08-28 →). Since 2026-08-01 no request has errored.
- **Prompt storage and text:** hard-coded in `GenieAssist` (06-29) → `llm_prompt` tags per problem (07-17); two full copies `AI-AL` (239 problems) and `AI-DS` (45), identical apart from AL's Thai-translation appendix (present by 2026-03-04 at the latest); text otherwise unchanged for the feature's life → `codey-core` + one-line `codey-thai` (2026-09-03, `course-prep` rev 3). Edits recommended by the evaluation are **pending**.
- **Payload:** system prompt + statement PDF + source + verdict string (07-17) → + manager files with a do-not-reveal instruction (08-23) → + compiler output on compile errors, per-testcase table (group, verdict, time, memory, score, limits), previous answer + line diff on repeat requests (2026-09-03, rev 2089). The prompt still carries the "How to Map" section that the table makes redundant.
- **Price and score policy:** 10 points per request, a constant in code, stated in the confirm dialog (07-11) → the same 10 as a site setting `system.llm_assist_cost` (2026-09-03, rev 2100); contest views show `final_score = min(max, 100 − llm − hints)` (09-14, summation fixed 11-25) → floored at 0 (2026-09-03, rev 2085; 10 student–problem pairs had gone negative, worst −360) → requests refused while one is running, when that model already answered, at full score, and once 100 points are spent on the problem (rev 2090).
- **Access:** site switch + contest `allow_llm` + tag present (07-10/11) → + owner-or-admin (2026-09-03, rev 2084; 11 historical requests were made by someone other than the owner, who paid).
- **Accounting:** score penalty only (`comments.cost`) → `llm_cost`, `prompt_tokens`, `completion_tokens` + backfill task (rev 2089).
- **Measurement:** none → next-submission outcome metric + mechanical checks + 291-answer read (2026-09-03) → offline old-vs-new prompt test, 100 inputs × 3 arms, blind-read (2026-09-04, Part 4 of the evaluation doc).

## Numbers for reporting (production, as of 2026-09-03 11:44)

| | |
|---|---|
| Requests | 5,264 (answered 4,787 · errored 80 · stuck "processing" 397, all Aug–Sep 2025) |
| Students who used it | 313 |
| Submissions / problems touched | 4,816 / 240 |
| By semester | 1/2568 (Aug–Dec 2025) 2,371 · 2/2568 (Jan–May 2026) 2,349 · summer 24 · 1/2569 (Aug 1 – Sep 3, 2026) 515 |
| Peak month | April 2026, 856 |
| By course (problem-name prefix) | `d*` Data Structures 2,341 · `a*` Algorithms 1,989 · `ex*` exercises 235 · `da*` 163 · `ds*` 85 |
| Repeat requests | 44% of answers were the student's 2nd+ request on that problem; max 46 on one problem; 316 students, median 9 requests each, p90 36, max 131; top tenth of students made 38% of requests |
| Score penalty charged | 47,020 points over 2,699 student–problem pairs |
| Tokens (gemini-2.5-pro, 4,206 answers) | 18.1M prompt · 23.1M completion (avg 5,500 completion — a reasoning model) |
| Tokens (Claude-3.5-Sonnet, 699) | 6.7M prompt · 0.33M completion |
| Contest use | `allow_llm` on in 12 of 39 contests |
| Effectiveness (pre-2089 payload) | paired, same student & problem: the step before the first assist improved 27%, the assisted step 38%; 37% reach full score within 3 submissions, 63% ever; 14% never resubmit. Compile errors worst (next↑ 25%), repeat requests worse than first. Aug 2026 head-to-head on 22 shared problems: current models next↑ 50% vs gemini-2.5-pro 38% (n=105). Never-asked students are not a valid baseline. |
| Quality (291 read) | hard rules hold (1% write code, 3% name a technique); 64% state the fix, 9% describe the algorithm; gemini-3.1-pro 0% wrong diagnoses (n=90), Claude-Sonnet 20% (n=40); details in the evaluation doc |

---

## Entries

### 2026-09-05 — Follow-up on the two prompt edits: keep the compile-error one, drop the TLE stop rule
**study** · `doc/assist-corpus-eval-2026-09-03.md` Part 4 "Follow-up"; `course-prep` revs 11 (v2.1 tested), 12 (v2.2 = rev 4 + one sentence), 13 (scores)
- **Problem observed:** Part 4 left two weaknesses in rev 4: compile-error answers that ended on a bare question (15 of 20 had a next step), and time-limit answers that named the allowed tool and then laid out the redesign (6–7 of 18).
- **Change:** one new arm on the 38 CE + TLE inputs with both edits (v2.1), graded blind against the rev 4 answers for the same inputs by the same three readers.
- **Outcome / status:** the compile-error sentence works — next step 7 → 20 of 20 on the stricter reading, gained on 13 inputs, lost none, no side effects. The TLE stop rule does not — hand-overs 7 → 9 of 18 (removed 2, introduced 4); reverted. **Deployable text = `course-prep` rev 12 (v2.2)**, both halves of which have been read blind. The TLE hand-over stays an open problem for a shape-level fix (template or second pass), parked. Still **pending dae**: deploy chula_cp (2112, which carries the key migration), then paste rev 12 into tag #43.

### 2026-09-04 — Offline old-vs-new prompt test: rev 4 fixes focus, not the "states the fix" line
**study** · `doc/assist-corpus-eval-2026-09-03.md` Part 4; data + scripts `course-prep/assist/eval-2026-09-03/offline-prompt-test/` (course-prep revs 6–10)
- **Problem observed:** the eight prompt edits from the 2026-09-03 evaluation (`codey-core` v2, course-prep rev 4) had been accepted on reasoning alone; nothing showed what they do to real answers before students see them.
- **Change:** 100 past stuck moments (20 compile errors, 45 repeat requests, at most 3 per problem) answered three times each by gemini-3.1-pro: old prompt + old payload, old prompt + new payload (rev 2089), new prompt + new payload. 300 throwaway answers, no comment rows, no charge. Graded blind by 12 Claude readers on Part 1's rubric; the DGX few-shot judge scored the same 300 for the cheaper-grader question.
- **Outcome / status:** one-issue answers 46 → 89 of 100 (gained on 45 inputs, lost on 2); hand-overs 11 → 8; wrong diagnoses 3 → 1; no code written; median 152 English words vs 238; numbered checklists 48 → 5. "States the fix" flat at 87–90 of 100 in every arm — the Socratic wording does not make the model withhold the fix. TLE hand-overs unchanged (7 → 6 of 18): the model names the allowed tool, then lays out the redesign anyway. Recommendation in the doc: deploy rev 4 after two small edits (Step 1 next-action sentence; a concrete stop rule after naming a tool in the TLE section), re-run the TLE + CE cells to check them. **Pending dae.** Operational: 12 readers ≈ two 5-hour windows, not one — run 6 + 6; the Thai-strip heuristic needed a fix before grading (33 bodies cut short, re-blinded, 3 re-graded).

### 2026-09-03 — Blind human read of 30 answers (the calibration anchor)
**study** · `course-prep` rev 5 (`assist/eval-2026-09-03/dae-reads.html`, `make_reads_page.py`, `dae-reads-key.json`); rev 2102–2103 (plan + this entry)
- **Problem observed:** every grade in the study so far was given by a model — the 291 read by Claude, then the DGX judges — and the two disagreed most on the line that the main finding rests on: did the tutor merely ask a leading question, or state the fix? No human had ruled on that line.
- **Change:** a single-page form with 30 answers from the 291, chosen where the graders disagreed — 12 where the Claude readers said "Socratic" and the few-shot DGX judge said "stated the fix", 12 the other way round, 6 the readers called algorithm hand-overs — shuffled, student code folded under a click, no grader's score visible. Three questions per answer in plain words (how much was given away / diagnosis right / one issue) plus a note; answers autosave in the browser and export as `dae-reads.csv` into the same directory. The selection key with the graders' scores is kept in a separate file. dae started reading 2026-09-03 evening.
- **Outcome / status:** pending `dae-reads.csv`. Next session joins it to the graders' scores on `comment_id` and reports, per disputed answer, which grader dae sided with — that decides how to read every leak figure in the study and how to calibrate the judge for the offline old-vs-new prompt test.

### 2026-09-03 — The price becomes a site setting
**platform code** · rev 2100; `Llm::CommentAssist.assist_cost`, `db/seeds.rb`, `submissions/_add_assist`
- **Problem observed:** the 10-point penalty was `ASSIST_COST = 10` in the service class — changing it meant a deploy, and there was no agreed place to keep the number. Decided with dae 2026-09-03: keep 10 for now (including for answers that name an algorithm, see the naming decision), but make it adjustable.
- **Change:** `GraderConfiguration['system.llm_assist_cost']` (integer, seeded 10, editable on the Configuration page, audit-logged like every setting); read at request time and stored on the comment; the confirm dialog and the picker quote it; 0 is a valid "free" price. Per-problem or per-contest prices were considered and left for a real need.
- **Outcome / status:** master 2100. Key created on every deployed host by data migration `20260905090000_seed_llm_assist_cost_configuration` (master 2111, 2026-09-05) — runs inside the deploy job's `db:migrate`, idempotent, so no manual `db:seed` is needed anywhere; until a host is deployed the code uses 10.

### 2026-09-03 — Naming decision: the tutor may name textbook algorithms; the problem-specific insight stays off limits
**policy (prompt), pending the prompt edit** · discussion 2026-09-03; evaluation Part 1 finding 1
- **Problem observed:** the "never name an algorithm or data structure" rule was obeyed to the letter and defeated in spirit — 9% of current answers narrate the algorithm step by step unnamed, a fuller leak than the word would be and harder for the student to look up; four property-descriptions of `set::lower_bound` failed to land where the name would have.
- **Change (agreed with dae):** allow naming standard textbook algorithms and data structures taught in the course; forbid the problem-specific step — the recurrence, the invariant, the reformulation, a worked example on the student's problem, solution code; when the fix is a redesign, tell the student to keep the current solution for the subtasks it passes and add the faster path for the rest. Price stays 10 points for now.
- **Outcome / status:** to be written into `codey-core` (course-prep) together with the other evaluation edits; not yet live.

### 2026-09-03 — Prompt tags: two full copies → `codey-core` + `codey-thai`; name-ordered assembly
**data + platform code** · prod tags #43/#44 (AI-AL #33, AI-DS #34 deleted; backup `~/codey-tag-backup-2026-09-03.txt` on 10.0.5.50); `course-prep` rev 3 (`assist/`); rev 2093
- **Problem observed:** `AI-AL` (239 problems) and `AI-DS` (45) were the same 9.4 KB text except AL's Thai appendix; every edit had to be made twice and they had drifted by one wording change. The tag lookup had no ORDER BY, so multi-tag assembly order depended on attach order.
- **Change:** dry-run then apply of a re-tag script on prod: `codey-core` (AL text minus the appendix) on all 284, `codey-thai` (one sentence) on the 239 AL problems. `CommentAssist` orders tags by name. Prompt text checked into `course-prep/assist/`.
- **Outcome / status:** live on prod (per-problem behaviour unchanged; verified by assembling the payload for an AL and a DS problem). Code in master 2093, not yet merged to chula_cp.

### 2026-09-03 — First corpus evaluation (Part 1 read scores, Part 2 whole-corpus outcomes, Part 3 DGX judge calibration)
**study** · `doc/assist-corpus-eval-2026-09-03.md` (revs 2094, 2096, 2097, 2098); raw frame + scores + `frame2.rb`/`frame3.rb` + `judge.py`/`agreement.py`/`judge-*.csv` in `course-prep/assist/eval-2026-09-03/` (local-only repo; `~/cafe-grader/assist-eval-2026-09-03` is a symlink to it)
- **Problem observed:** no one had read what the tutor actually says. The effectiveness metric showed no visible benefit but could not say why.
- **Change:** frame over all 4,787 answers (verdict class, next-submission outcome, request index, mechanical checks); 291 read against source + evaluations (all 193 current-model answers + 7 per verdict-class × outcome cell of the retired models) and scored on leak / diagnosis / focus / actionable.
- **Outcome / status:** Part 3 (evening): the self-hosted models were calibrated as judges against the 291 read answers — gemma-4-31b matches on focus (κ 0.77) and language only; qwen3.5 reaches κ ≈ 0.5 on leak and wrong-diagnosis but is systematically lenient (calls 38% leaks vs the readers' 60%), so a free census would understate the study's main finding; a few-shot retry with six gold anchors fixed hand-over detection (leak-2 κ 0.65) and focus (0.71) but flipped rather than removed the leak bias (three-way κ 0.49) and hurt diagnosis (0.23) — DGX route for leak/diagnosis stopped; paid targeted sample vs stop-at-291 pending. Part 2 (evening, database only): paired same-student-same-problem improvement 27% → 38%; compile-error and repeat requests are the worst cells; Aug 2026 same-problem head-to-head favours the current models (next↑ 50% vs 38%); two problems absorbed 277 requests with ~2% success. Part 1: hard rules hold; the soft rule fails (64% state the fix, 9% hand over the algorithm in words, mostly TLE/RE, and those students regress as often as they improve); wrong diagnoses are model-specific (gemini-3.1-pro 0/90, Claude-Sonnet 8/40); the current models are twice as long and half as focused as gemini-2.5-pro was. Eight prompt edits and two roster/Thai decisions listed in the doc — **pending dae**.

### 2026-09-03 — Picker guards: in-flight, already answered, full score, 100-point spend cap
**platform code** · rev 2090; `Submission#llm_assist_refusal`, `submissions/_add_assist`, `CommentsController#can_request_llm`
- **Problem observed:** 190 submissions had the same model asked twice, 126 requests were made on full-score submissions, 10 student–problem pairs had spent more than the problem was worth — each a wasted API call and, until rev 2085, a negative score.
- **Change:** one predicate disables Get with the reason shown, and the controller applies it to a replayed form (422). The picker refreshes with the comments so a finished request re-enables Get.
- **Outcome / status:** master 2090, not yet deployed. Side effect: the 397 historical stuck-processing comments now also block new requests on those submissions until cleared (one-off recorded in `doc/backlog.md`).

### 2026-09-03 — Payload rebuilt around what the grader knows; dollar/token accounting
**platform code** · rev 2089; `Llm::CommentAssist`, migration `AddLlmUsageToComments`, `rake comments:backfill_llm_usage`
- **Problem observed:** the model was asked to infer subtask boundaries from percentages in the PDF and to find syntax errors without the compiler message (166 assisted compile errors); repeat requests (44%) arrived with no memory of the previous answer, so students got the same hint again; no record of what a request cost in dollars or tokens.
- **Change:** compiler output block on compile errors; per-testcase table from `evaluations` (group, verdict, time, memory, score, dataset limits, ≤100 rows, never inputs or answers); previous answer + line diff (or "code unchanged") with an instruction not to repeat; `llm_cost` / `prompt_tokens` / `completion_tokens` columns filled from the response (gateway cost header; self-host 0.0; nil where no source), backfill recovers tokens for 5,098 historical rows.
- **Outcome / status:** master 2089, tests cover each block; not yet deployed. Prompt text still teaches the old "How to Map" method — see pending edits.

### 2026-09-03 — Seven defects fixed
**platform code + security** · revs 2084–2086, merged to chula_cp 2088 and pushed
- **Problem observed:** (1) any logged-in user could request assist on any submission id, charging its owner and the API budget, on a submission they could not view; (2) the model was addressed by its index in the provider map (an `llm.yml` reorder repointed every link; a stale index was a 500); (3) `final_score` could go negative; (4) the model-written answer was rendered as raw HTML (stored-XSS class); (5) a problem without a statement PDF produced a `null` content part (400); (6) a failed request got two error blocks; (7) the picker was a `link_to` with `turbo_method`, against the mutating-click convention.
- **Change:** owner-or-admin gate; model by name via a `button_to` form; `GREATEST(0, …)`; sanitize after markdown; `.compact`; job leaves a comment the service already marked; regression tests for each.
- **Outcome / status:** live in the repo (chula_cp 2088); deployment to 10.0.5.50 pending.

### 2026-08-26 → 08-30 — Chula AI Gateway provider; claude-opus-4-5 and gemini-3.7-flash join the picker
**platform code + config** · revs 2018–2019, 2050; chula_cp `llm.yml`
- **Problem observed:** the only hosted provider was ChulaGenie, whose relay could not take PDFs for Anthropic models and reported no cost.
- **Change:** generic bearer-key OpenAI-compatible transport (LiteLLM proxy / OpenRouter shape) with one subclass per role; PDF parts rewritten to `file` blocks; per-call cost from the gateway header (with a body fallback and a WARN when neither is present). chula_cp registers `AiGatewayAssist: claude-opus-4-5,gemini-3.7-flash`.
- **Outcome / status:** first prod answers 08-27 (opus) and 08-28 (3.7-flash); no errors since.

### 2026-08-23 — Comment assist defaults to gemini-3.1-pro; Claude-Sonnet un-broken
**config + platform code** · revs 2006–2007 (chula_cp)
- **Problem observed:** the Genie relay had renamed its Claude models in February; `llm.yml` followed (rev 1498, 02-14) but `GenieAssist::PERMITTED_MODEL` still listed `Claude-3.5-Sonnet`, so every "Claude-Sonnet" request since 02-14 was silently downgraded to gemini-2.5-pro. gemini-2.5-pro itself was due to retire.
- **Change:** allowlist uses the relay's current names; default model gemini-3.1-pro (smoke-tested with a statement PDF); rosters refreshed.
- **Outcome / status:** gemini-3.1-pro first answer 08-24; Claude-Sonnet genuinely served from 08-24 (40 answers to 09-02). gemini-2.5-pro's last answer 08-23.

### 2026-07-30 — Self-hosted provider (`SelfHostAssist`)
**platform code** · revs 1932–1933; chula_cp `llm.yml` `self_hosted_models`
- **Problem observed:** the near-miss grading work needed the department's DGX models; the same transport can serve the assist picker at zero dollar cost.
- **Change:** `SelfHostChat` transport + `SelfHostAssist`; served model names registered in the provider map appear in the picker.
- **Outcome / status:** built and tested; not registered in the prod picker as of 2026-09-03 (no DGX model has answered a student request).

### 2026-07-20 → 07-21 — `llm_prompt` means the helper prompt only (viva tag taxonomy, D6)
**platform code + data** · revs 1878, 1888–1889, 1892; `doc/decisions.md` 2026-07-20
- **Problem observed:** viva and the helper both read `kind: llm_prompt`, so a bulk-tagged tutor persona could concatenate into an examiner's system prompt and vice versa. The spec's first cut hid `llm_prompt` from the generic tag picker, which silently detached helper tags on every ordinary problem save.
- **Change:** viva moves to `problems.viva_prompt` + `viva_conduct` tags; `llm_prompt` is read only by `CommentAssist`; the generic picker keeps offering it. Both LLM kinds forced `public = false`.
- **Outcome / status:** live since 4.4.x/4.5.0. One leftover: `AI_viva` (#36) is still an `llm_prompt` tag on two viva problems and is read by nothing.

### 2026-05-07 — `Llm::Request` hierarchy; `CommentAssist` lifted out of `GenieAssist`; penalty regression and fix
**platform code** · revs 1634–1654 (master + chula_cp merges)
- **Problem observed:** the comment-assist logic lived inside the Chula-specific `GenieAssist`, so master had no working helper and every provider would have re-implemented message assembly.
- **Change:** abstract `Llm::Request` (orchestration, retry taxonomy, Faraday factory) → `CommentAssist` (payload + comment handling) → provider subclasses. `Request.preview` for console inspection of the payload. The lift briefly replaced the 10-point penalty with a 0.0 "API cost"; rev 1642 restored it as `ASSIST_COST = 10` with the semantics documented.
- **Outcome / status:** every later provider (self-host, gateway) plugged into this shape unchanged.

### 2026-03-04 — More error handling on Genie assist
**platform code** · rev 1509 (chula_cp)
- **Problem observed:** Feb–Mar 2026: 74 Claude-3.5-Sonnet requests failed with HTTP 400 (Anthropic rejects a PDF sent as an `image_url` part) and surfaced as bare "API Communication Error".
- **Change:** clearer error handling on the Genie call path.
- **Outcome / status:** the underlying PDF shape problem was only solved by the gateway transport (08-26); Claude-3.5-Sonnet's last answer was 03-03 and the renamed model was silently downgraded until 08-23 (see that entry). The Thai-translation appendix on `AI-AL` dates from this period at the latest (tag `updated_at` 03-04).

### 2025-11-25 — Score summation of assists fixed
**platform code** · revs 1482, 1486
- **Problem observed:** the max-score report summed the penalty incorrectly across a student's submissions.
- **Change:** `max_score_report` joins the assist penalty per submission and applies `min(max, 100 − llm − hint)`.
- **Outcome / status:** stayed until the 2026-09-03 floor fix (rev 2085).

### 2025-09-14 — Contest views show hint and assist penalties
**platform code** · revs 1429–1430
- **Change:** the contest score table shows the assist count/cost and hint cost next to the raw and final scores.
- **Outcome / status:** live; the same numbers drive the Best Score report.

### 2025-08-23 → 08-26 — Managers in the payload; missing-tag error; auto refresh
**platform code** · revs 1397, 1401, 1406
- **Problem observed:** problems with manager files (headers, main programs) gave the model no context on how the student's code is called; a problem without an `llm_prompt` tag failed opaquely; students had to reload to see the answer.
- **Change:** managers sent as JSON with a do-not-reveal instruction; explicit "no `llm_prompt` tag" toast; the comments block polls every 5 s while a request is processing.
- **Outcome / status:** live. The polling is what made the 397 stuck-processing comments visible as eternal spinners.

### 2025-07-23 — First student request
**operations** · production
- gemini-2.5-pro and Claude-3.5-Sonnet in the picker from day one. 725 requests in August 2025.

### 2025-06-29 → 07-17 — Birth
**platform code + schema** · revs 1299–1347; migrations `add_llm_support_to_comment` (06-29), `add_llm_enable_to_contest_problem` (07-11), `add_json_params_to_tags` (07-15)
- **Change:** `comments.llm_response / llm_model / status` and `kind: llm_assist`; `GenieAssist` against ChulaGenie; the "acquire" confirm dialog stating the 10-point price and what is sent; per-model provider map in `llm.yml` (`GenieAssist: gemini-2.5-pro,Claude-3.5-Sonnet`); `system.llm_assist` site switch; `contests_problems.allow_llm`; tags gain `params` and the `llm_prompt` kind, and the prompt moves from code into a tag attached per problem.
- **Outcome / status:** the shape that still stands: prompt in tags, price in score, provider by config.
