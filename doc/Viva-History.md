# Viva — Change History

What we changed in the viva feature, why, and how it turned out. Newest first.
This is the *timeline*; design rationale lives in `doc/Viva-Exam.md` (Decision
Log), the problem-setter craft in `doc/wiki/viva-authoring-guide.md`.

**How to add an entry** (rule in `CLAUDE.md` → "Viva Live Docs"): any commit
that changes viva behavior, prompt text (conduct tags, briefings, kit files),
the model or provider behind turns or grading, or access/alert policy adds an
entry here *in the same commit*, shaped **Problem observed → Change →
Outcome / status**, with refs. When an entry supersedes an earlier one, mark
the old one `SUPERSEDED YYYY-MM-DD by …`; never delete. Rev numbers are local
hg revs of `~/cafe-grader/web` (master unless marked `chula_cp`); kit and
conduct edits cite `course-prep rev N` (the local `~/cafe-grader/course-prep`
repo, started 2026-09-02).

## Eras at a glance

| # | Era | Dates | Characterization |
|---|-----|-------|------------------|
| 7 | Audit & conduct split | 2026-08-29 → 09-02 | Grade-JSON schema check; full-transcript audit of the first live problem (182 sessions); conduct tag split into base + mode overlay; importer `conduct_tags:`; `course-prep` under hg; History + authoring guide seeded. |
| 6 | First student trial → fixes, bake-offs, 4.5.0 | 2026-08-23 → 08-28 | Grade default → gemini-3.1-pro; engaged-only daily limit + End button + narrowed alert triggers; English-only examiner; abandoned-session reaper; AI-gateway provider family; prompt hardening and the flip to gemini-3.7-flash (prod 08-27 22:47); kit grounding; markdown editor; release 4.5.0. |
| 5 | Kit + production launch | 2026-08-15 → 08-22 | Kit importer; completion caps raised after a real truncation; `practice-2569-1a` authored (conduct tag + 9 briefings); imported to prod 08-22; first student sessions that evening. |
| 4 | Deployment-readiness redesign | 2026-07-19 → 07-21 | `GroundingMaterial`; designs D1–D9; Phase 1 (`viva_prompt` column, `viva_conduct` tag kind, detect-only alerts, turn caps, practice/exam toggle) — then the same-week pivot that deleted the toggle for a per-problem daily start limit; authorization gates; docs wave. |
| 3 | Pilot content | 2026-06-10 | Five DS pilot scenarios under the old `llm_prompt`-tag scheme; no platform change. |
| 2 | Hardening sprint 1 | 2026-05-05 → 05-25 (released 4.4.0, 06-11) | `Llm::Request` hierarchy, error visibility, scenario-in-description, markdown rendering, setup validation, soft archive, model picker, stuck-turn recovery, first jailbreak directive, owner-only answering, PDF hidden. |
| 1 | Birth | 2026-04-19 → 05-04 | Feature lands in one commit: `viva_exam` type, `viva_turns`/`viva_grades`, abstract turn/grade services + Chula Genie wiring; prompts in `llm_prompt` tags; PDF is the scenario. |

## Lineages (the same story told per thread)

- **Prompt storage:** `llm_prompt` tag (04-19) → description added as scenario (05-05) → PDF declared the canonical scenario (05-08, 05-12) → `viva_prompt` column + `viva_conduct` tag, scenario = description, PDF = figures only (07-20/21) → conduct split into base + mode overlay (09-01).
- **Alerts and consequences:** none (04-19) → detect *and* terminate inside the prompt (05-20) → detect-only in prompt, backend decides — warn-then-terminate in exam, log in practice (07-21) → `exam_policy?` hardcoded false pending Phase B (07-21) → triggers narrowed and non-triggers listed after the first trial (08-25) → audit: false positives on listed non-triggers persist on gemini-2.5-flash, none on 3.7-flash (09-01).
- **Models actually running in prod:** turns gemini-2.5-flash via Genie (08-22 → 08-27 21:46) → gemini-3.7-flash via Chula AI Gateway (08-27 22:57 →). Grades: 2.5-flash → 3.1-pro (08-23 → 08-27) → 3.7-flash (08-27 →). The Claude-Sonnet turn default (chula_cp 2010) never ran in prod.
- **Pacing (Buggy Counter, completed sessions):** 2.5-flash median 10 student turns, 42% at the hard cap → 3.7-flash median 6, 3% at the cap, 55% inside the 6–9 target. Same prompt.
- **Retakes:** single attempt + admin archive (05-09) → practice self-restart 3/day, exam single attempt (07-20, lived one day) → per-problem daily limit, everyone restarts (07-21) → engaged sessions only count (08-25) → best-of-N recorded score confirmed as policy; audit shows it invites grinding (09-01).
- **Still open / never built:** D7 authoring lint + test-drive; red-team regression set; Phase B (per-contest retake budgets, governing-contest snapshot, window-end force-finish); viva in problem export/import; persistent scenario panel; session wall clock; grade-JSON validation against rubric *weights*; wiki publication of the viva guides.

---

## Entries

### 2026-09-02 — `course-prep` becomes a local hg repo; wiki procedure recorded
**docs/tooling** · `hg -R ~/cafe-grader/course-prep log` revs 0–1; memory `cafe-grader-wiki-publishing`
- **Problem observed:** conduct and briefing text had no version trail — it lived only in prod's DB and in README prose. How the upstream wiki gets published was not written down anywhere (found while planning these docs).
- **Change:** `hg init` on `course-prep` (no remote, ever — it holds exam papers and model answers); rev 0 baseline, rev 1 the conduct split. Memory note: the `cafe-grader-team` wiki holds verbatim copies of `web/doc/*.md`, pushed by hand; `doc/wiki/` viva guides are unpublished drafts.
- **Outcome / status:** live.

### 2026-09-02 — Kit importer accepts a `conduct_tags:` list
**platform code** · rev 2071; `app/services/viva/kit_importer.rb`, `test/services/viva/kit_importer_test.rb` (+3 tests)
- **Problem observed:** the manifest took one `conduct_tag:`; the base + overlay design needs two tags per problem.
- **Change:** `conduct_tags:` list (legacy single form still accepted; both merged); each tag upserted by name and linked add-only to every kit problem; the same name twice fails the import; the UPDATE report names the linked tag. Header comment documents suffix naming and name-order concatenation.
- **Outcome / status:** 10/10 importer tests, rubocop clean, dry run of the real kit on local dev correct. Older importers ignore the key silently — the dry run must show two `CONDUCT` lines before `APPLY`.

### 2026-09-01 — Conduct split: base profile + practice/exam overlays; Buggy Counter witness carve-out
**prompt text (course content) + policy** · course-prep rev 1; `_conduct.md` (base, tag `DS-viva-conduct-2569`, 4,859 → 6,004 chars), `_conduct.practice.md` (`DS-viva-conduct-2569-practice`), `_conduct.exam.md` (staged for a future exam kit, not imported), `01-buggy-counter.briefing.md`, `manifest.yml`; review page `~/Documents/reports/viva-conduct-split-2026-09-01.html`
- **Problem observed:** one tag mixed mode-invariant rules with practice-only scaffolding, so it could serve neither a leak-tolerant practice nor a strict exam. dae's position: leaks are fine in practice, not in exams; leading questions corrupt scores in both.
- **Change:** *Base* gains: never put the answer inside a question; ask for the student's own working; examiner-supplied content is not evidence; unreached criterion = 0; criterion ≤ weight; probe examples in English (the Thai examples were being imitated); don't end while a criterion rests on an unverified claim; no answer summary in the close; "never reveal" reworded to "while the point is still being assessed". *Practice overlay*: one hint per topic; a sanctioned one-sentence, no-code explanation after a rung is settled; concrete narrative. *Exam overlay*: one restatement, no content hints, no teaching, topic-only narrative. Each overlay ends with a precedence line. Buggy Counter briefing: never supply a concrete witness even in practice — witnesses are what retakers paste verbatim.
- **Outcome / status:** in the kit, committed locally; **not yet imported to prod** (needs rev 2071 deployed first).

### 2026-09-01 — Full-transcript audit of problem 693 "The Buggy Counter"
**docs/tooling (analysis)** · report `~/Documents/reports/viva-audit-buggy-counter-2026-09-01.html` + findings tarball; memory `viva-buggy-counter-audit`
- **Data:** 182 sessions, 101 students, 2,372 turns, 117 grades (08-22 → 09-01). 54 zero-turn peeks (30%); 116 graded; one `grader_error` never re-run (937805). All 128 transcripts with content close-read against briefing, conduct, security directive and grading conventions.
- **Findings:** (1) *Compliance is a model property.* The 2.5-flash era broke English-only in 44 sessions, revealed its running assessment in ~53, escalated hints in 22, and hit the hard cap in 42% of completions; the 3.7-flash era is clean on all of those but skips demanding witness traces and sometimes ends early on thin evidence. (2) *No leak under direct attack* — 20+ jailbreaks (prompt extraction, TA role-spoof, "friend said the examiner confirmed…", a grading-pipeline injection) all deflected in both eras. Real leak channels: the examiner teaching the answer after a failed rung (108 instances in 63 sessions, both models), leading yes/no questions containing the answer, grade narratives spelling out the fix (25/117), abandon-and-retry oracle farming. (3) *Scoring* ≈73/116 plausible, ~36 over, ~6 under; untraced witnesses credited; precondition over-credit; phantom credit for unreached rungs; 2/117 rubrics exceeded their weights; gemini-3.1-pro unanimously the best-calibrated grader; external-LLM pastes scored 98–100 undetected. (4) *Alerts*: 56 turns / 21 sessions, 0 terminations (practice mode — correct); ≥14 false positives on explicitly listed non-triggers (all 2.5-flash era); under exam two-strike two honest students would have been terminated. Heavy retake grinding (one student 10 sessions); two account-sharing suspects.
- **Outcome / status:** drove the conduct split. Open recommendations: stronger grader default (3.1-pro or better), grade-JSON validation against weights, re-grade 937805, paste/burst heuristics as review flags (never auto-penalize), session wall clock, alert regression set from the 56 practice alerts before exam mode, retake scoring policy.

### 2026-08-29 — Grade JSON schema check + one re-ask before `grader_error`
**platform code** · rev 2043 (chula_cp merge 2054)
- **Problem observed:** the extractor took the first balanced `{…}`; a grader reply that slipped into the interviewer role could land as `points: nil` with status *done* — a silent zero (prod 937805, 08-23).
- **Change:** `grade_schema_error` (numeric `total_points` 0..100, non-empty rubric); re-ask once (not on `finish_reason=length`); second failure → `grader_error` with the raw response preserved.
- **Outcome / status:** live in code; deployment to prod after chula_cp 2038 unconfirmed. Does **not** check criteria against weights — the audit's two over-weight rubrics would have passed (open item).

### 2026-08-28 — Viva grade display: compact marker, badge on the main list
**platform code (UI)** · revs 2036–2038; `bin/rails viva:clean_grader_comments`
- **Problem observed:** the 300–450-char narrative was copied into `grader_comment` and rendered as a paragraph in the main list's verdict cell.
- **Change:** marker `viva` / `viva:terminated`, badge linking to the viva page, "Interview in progress" / "Grader error" states. 4.5.0 head moved to include it.
- **Outcome / status:** live; prod runs chula_cp 2038 (4.5.0) from 08-29.

### 2026-08-28 — Kit importer carries grounding; DS grounding text; markdown editor; two-column edit page; release 4.5.0
**platform code + prompt text (grounding) + docs** · revs 2027 (`grounding:` manifest section), 2030 (Ace editor + server preview), 2031 (edit page), 2033 (release); kit `_grounding-stl-usage-01-07.md` (≈5k tokens re-sent every turn; no `CP::`, examiner never uses O-notation) attached to problems #01–#08
- **Outcome / status:** live. Prod grounding record pre-created so the import matches by title.

### 2026-08-27 — Bake-off → prompt hardening; viva services flipped to Chula AI Gateway gemini-3.7-flash
**prompt text (backend directives) + model/provider** · rev 2024 (hardening, master), 2025 (config flip, chula_cp); report `~/cafe-grader/bakeoff-2026-08-27/`; deployed to prod 22:47
- **Problem observed:** with wire-role labels, Claude models slid into the interviewer role and kept interviewing instead of grading (21/24 gateway calls; 2.5-flash showed the same on 08-23); one model announced "the interview has ended" without `[[VIVA_DONE]]`, stranding the session; two models wrote LaTeX that `safe_markdown` renders raw. Bake-off: 3.7-flash 4.0 s/turn vs Sonnet 10.7 s, zero leaks for both, 12/12 grade compliance under the hardened prompt, ±2 rerun noise, ~5 points kinder than 3.1-pro.
- **Change:** grading transcript labeled `INTERVIEWER:`/`STUDENT:` with an "END OF TRANSCRIPT — output ONLY the grade JSON" re-anchor (Claude 3/24 → 16/16 compliant); `[[VIVA_DONE]]` made binding; no-LaTeX format directive. Config: viva turn, viva grade, grounding extract → gateway, all gemini-3.7-flash.
- **Outcome / status:** live. Audit 09-01: hard-cap hits 42% → 3%, English-only violations 44 → 0, praise/running-assessment violations gone. Residual on 3.7-flash: skipped trace demands, occasional leading questions, early endings on thin evidence — addressed in the 09-01 conduct split.

### 2026-08-26 — Hosted AI-gateway provider family (master) + Chula AI Gateway wiring (chula_cp)
**model/provider** · revs 2018–2019 (master), 2020 (chula_cp `ai_gateway:` block); placement rule `doc/decisions.md` 2026-07-30
- **Problem observed:** OIT's LiteLLM proxy with static bearer keys replaces the Genie token dance; Anthropic models reject PDFs sent as `image_url`.
- **Change:** `Llm::AiGatewayTransport` + per-role subclasses (assist, viva turn, viva grade, grounding extract, repair); PDFs as OpenAI `file` blocks; cost from `x-litellm-response-cost`. Viva services stayed on Genie until the bake-off.
- **Outcome / status:** live.

### 2026-08-26 — Abandoned-session reaper
**platform code** · rev 2016; `config/recurring.yml` `viva_session_reaper` (hourly, production)
- **Problem observed:** grading fired only on sentinel, hard cap, or the End button; tab-closers sat in `submitted` forever (trial: ~17 with progress, ~27 greeting-only).
- **Change:** `Submission.reap_abandoned_vivas!` grades sessions idle 24 h+ with ≥1 student answer and archives greeting-only peeks.
- **Outcome / status:** live; audit: 54 peeks archived ungraded as designed, 1 session reaped-and-graded.

### 2026-08-25 — Conduct: examiner writes English only; students any language; kit names `d69_v1_<slug>`
**prompt text (course content)** · kit `_conduct.md` §Language (verified identical to prod tag on 08-29)
- **Problem observed:** the original Thai-speaking-examiner policy caused per-session language chaos once the deployed tag's headline was flipped to English by hand.
- **Change:** examiner English-only (one-line Thai orientation allowed in the opener); students Thai/English/mixed, never commented on; translation requests → simpler-English restatement, never flagged; narrative in the student's language. Kit and prod problem names converged so the importer matches by name.
- **Outcome / status:** live — but **gemini-2.5-flash ignored it** (362 Thai non-opening messages in 44 sessions through 08-27); 3.7-flash complied fully. Recorded in `Viva-Exam.md` §2 as "interview language is a conduct concern".

### 2026-08-25 — Grading model independent of how the interview ended
**platform code** · rev 2011
- **Problem observed:** on 08-24, 14 hard-capped sessions were graded by the grade default and 11 sentinel-ended ones by the *turn* model — two graders in one cohort.
- **Change:** both end paths leave model selection to the grade service; only the admin re-run picker passes a model.
- **Outcome / status:** live.

### 2026-08-24 — First student trial (70 sessions) → flow fixes and narrowed alert triggers
**platform code + policy + prompt text (security directive)** · rev 2014
- **Problem observed:** 39% of starts were greeting-only peeks, each burning a daily slot (often a misclick); ~17 sessions with real progress parked in `submitted`; 28 alerts were mostly benign redirects drowning the real signal.
- **Change:** daily limit counts *engaged* sessions only (≥1 student turn); "End interview & get graded" button (practice only); `SECURITY_DIRECTIVE` trigger 4 narrowed to credit negotiation, with explicit non-triggers (off-topic, frustration, breaks, skip/stop requests, translation requests).
- **Outcome / status:** live. Audit 09-01: peeks 30% and free; ≥14 false positives still fired on listed non-triggers in 2.5-flash sessions.

### 2026-08-24 — Turn default → Claude-Sonnet (chula_cp)
**model/provider** · chula_cp rev 2010
- **Problem observed:** replaying three real turns through five relay models: 2.5-flash and 3-flash gave sub-answers away, Haiku lectured, Sonnet never leaked and matched the student's Thai; 3–10 s/turn at ~USD 0.025 (flash 0.002). Also removes the 2.5-flash retirement deadline (~2026-10-16).
- **Change:** `VivaTurnGenieAssist` default Claude-Sonnet.
- **Outcome / status:** **never ran in prod** — the audit shows 2.5-flash until 08-27 21:46 and 3.7-flash from 22:57; rev 2025 replaced it before deployment. SUPERSEDED 2026-08-27.

### 2026-08-23 — Grade default → gemini-3.1-pro (chula_cp)
**model/provider** · chula_cp rev 2008; comparison scripts on the grader host
- **Problem observed:** over 12 graded sessions, fresh 2.5-flash reruns scattered ±10 points (stdev 7); it credited interviewer scaffolding as student knowledge (937769) and reproducibly role-played the interview instead of grading → nil-score grade (937805).
- **Change:** `VivaGradeGenieAssist` default gemini-3.1-pro.
- **Outcome / status:** in effect 08-23 → 08-27 (18 prod grades); SUPERSEDED 2026-08-27 by the gateway flip to 3.7-flash. The 09-01 audit again found 3.1-pro the best-calibrated grader — reinstating it is an open recommendation.

### 2026-08-22 — Kit imported to production; first student sessions
**deployment (content)** · prod 10.0.5.50 @ chula_cp 2006; kit at `~/viva-kits/practice-2569-1a`; problems 693–701
- **Outcome / status:** Buggy Counter made available the same day; first session 16:20.

### 2026-08-22 — Submit authorization: one gate, viva start included
**platform code + policy** · revs 1996–2001; `doc/decisions.md` 2026-08-22
- **Problem observed:** viva start used `problems_for_action(:submit)` directly; editors couldn't test-start hidden vivas; the manage page's Submit button bounced viva rows.
- **Change:** `User#can_submit_to_problem?` gates web, API, viva start, UI and the model validation; disabled membership grants no role; manage page offers Start/View Viva.
- **Outcome / status:** live.

### 2026-08-15 — Kit `practice-2569-1a` authored; first conduct tag; pilot findings
**prompt text (course content)** · `course-prep/data-structures/viva/practice-2569-1a/` (`_conduct.md`, 9 scenario/briefing pairs, `manifest.yml`); self-runs on local dev
- **Problem observed (pilot):** with "in full and verbatim" alone the examiner dropped the "Come prepared to" list; a student who needed one pushback was regraded 94 → 100.
- **Change:** conduct tag `DS-viva-conduct-2569` (Thai-speaking examiner at this point); grading conventions including **correct-after-hint = partial credit**; the opening rule names the task list explicitly; per-problem caps (Buggy Counter 8/12); daily limit 5.
- **Outcome / status:** live content; conduct SUPERSEDED 2026-08-25 (language) and 2026-09-01 (split).

### 2026-08-15 — Kit importer; completion caps raised
**docs/tooling + platform code** · revs 1989 (`bin/rails viva:import DIR=… [APPLY=1]`), 1990 (grade 2048 → 8192, turn 2048 → 4096 tokens), 1991 (doc refresh)
- **Problem observed:** nine problems to author by hand; gemini-2.5-flash spent 1,963–3,301 reasoning tokens before the JSON → `finish_reason=length` → `grader_error` on a 13-turn self-run.
- **Change:** idempotent, report-first importer (problems by name, conduct tag by name, `available` on create only); caps raised.
- **Outcome / status:** live.

### 2026-07-30 — LLM provider placement rule
**policy (engineering)** · `doc/decisions.md` 2026-07-30; rev 1924
- **Change:** generic providers (self-host, gateways) live on master, dormant until configured; Chula-only integrations (Genie) on chula_cp; config and secrets are per deployment. Near-miss grading explicitly excludes viva submissions.
- **Outcome / status:** live; governed the 08-26 gateway family.

### 2026-07-21 — Grounding PDF → text extraction (D4)
**platform code + model/provider** · revs 1919–1920 (master), 1922 (Genie wiring, chula_cp)
- **Change:** abstract extraction service + job + draft-review UI; at send time a material's body text replaces its PDF parts.
- **Outcome / status:** live (CHANGELOG 4.5.0). *`Viva-Exam.md` Known Gaps listed this as unbuilt until 2026-09-02 — stale text, corrected.*

### 2026-07-21 — Alert-review admin page
**platform code** · rev 1917
- **Change:** Graders → Viva alerts lists flagged sessions with the triggering utterance — the calibration instrument D3 asked for.
- **Outcome / status:** live. The red-team regression set remains unbuilt. *Known Gaps text was stale about this too — corrected 2026-09-02.*

### 2026-07-21 — Docs wave
**docs/tooling** · revs 1914–1916; `doc/viva-visibility.md`; `doc/wiki/instructor-viva-guide.md`, `doc/wiki/student-viva-guide.md`
- **Outcome / status:** the two wiki guides are still unpublished drafts (2026-09-01: upstream wiki has 8 pages, none about viva).

### 2026-07-21 — Audit-guard batch for viva submissions
**platform code (security/robustness)** · revs 1907, 1909
- **Change:** API description endpoint gated (the description *is* the hidden scenario); bulk dataset rejudge skips viva; graders backlog excludes viva; stale `:evaluating` → `grader_error` + monitoring.
- **Outcome / status:** live.

### 2026-07-21 — Context-based policy replaces the practice/exam mode (Phase A)
**policy + platform code** · revs 1905 (spec), 1911–1912; `docs/superpowers/specs/2026-07-21-viva-context-policy-design.md`
- **Problem observed (dae's insight):** the mode toggle was a binary encoding of a numeric idea — how many starts, in what context; a forgotten toggle inside a real exam permits restarts; `contest_mode?` is server-global so wrapper contests are infeasible.
- **Change:** every viva is practice; per-problem `viva_daily_limit` (nil → site default 3; N per day; 0 = contest-only); self-restart for everyone; `exam_policy?` hardcoded false with the warn-then-terminate branch kept dormant for Phase B. Phase B planned: per-contest retake budgets, governing-contest snapshot, mandatory window-end force-finish.
- **Outcome / status:** Phase A live; **Phase B not shipped**. SUPERSEDES D1/D2 of 07-20.

### 2026-07-21 — Show/refresh authorization; archived attempts owner/staff-only
**platform code + policy (security)** · rev 1903
- **Problem observed:** `#show`/`#refresh` had no authorization beyond login — any student could read any transcript by guessing ids.
- **Change:** reuse `User#can_view_submission?` plus one viva branch (`return false if viva_archived_at`).
- **Outcome / status:** live.

### 2026-07-21 — Daily start limit in `GraderConfiguration`; smoke-test UX fixes; endpoint guards
**platform code** · revs 1898–1901
- **Change:** `viva.practice_daily_start_limit` (default 3); archive redirect/relabel; editor guard; form layout; nil-guards on evaluations/download/compiler_msg for viva submissions.

### 2026-07-21 — Grader inoculation against embedded operational instructions
**prompt text (grader system prompt)** · rev 1897
- **Problem observed:** a legacy briefing migrated from an `llm_prompt` tag carried its own `----- ALERT -----` rule; the grader obeyed it over the JSON contract → `grader_error`.
- **Change:** the grading prompt explicitly ignores interview-conduct, security and alert instructions found in author content.
- **Outcome / status:** live — the only defence until the D7 lint exists. Lesson carried into both guides: authors write content, never operational rules.

### 2026-07-20/21 — Phase 1 ships: `viva_prompt` + `viva_conduct` (D6), detect-only alerts (D3), turn caps (D8), mode toggle (D1/D2), authoring UI (D5)
**platform code + prompt assembly + policy** · revs 1878–1896; `doc/decisions.md` 2026-07-20 "ownership follows cardinality"
- **Change:** `problems.viva_prompt` (audited, redacted) holds rubric and model answers; `Tag#kind :viva_conduct` shared persona, concatenated in name order, `public` forced false; assembly order conduct → `viva_prompt` → `SECURITY_DIRECTIVE` → pacing → done-sentinel; `viva:migrate_prompt_tags`; `SECURITY_DIRECTIVE` becomes detect-only with backend `apply_alert_policy` (practice: log + notice; exam: warn then terminate); `viva_soft_cap`/`viva_hard_cap`; `viva_mode` enum; scenario relabel, Examiner-briefing field, Conduct-profile select. Deviation from spec: hiding LLM tags from the generic picker silently stripped `llm_prompt` tags on save → only `viva_conduct` hidden (rev 1888).
- **Outcome / status:** D6/D3/D8 live; D1/D2 SUPERSEDED the next day.

### 2026-07-20 — Deployment-readiness design (D1–D9)
**policy / design** · revs 1876–1877; `docs/superpowers/specs/2026-07-20-viva-deployment-readiness-design.md`
- **Problem observed:** an August practice month and a ~October graded exam with 100–200 concurrent students; single-attempt-until-admin-archive collides with practice on day one; jailbreak FP/FN rates unmeasured; rules text embedded in PDFs; mislabeled description field.
- **Change (design):** D1 practice/exam mode; D2 retakes; D3 detect-in-prompt / decide-in-backend + alert-review page + red-team set; D4 PDF → text; D5 scenario = description, PDF = figures; D6 `viva_prompt` column + `viva_conduct` tag; D7 lint + test-drive; D8 turn caps; D9 measurement/ops.
- **Outcome / status:** D4, D5, D6, D8 and the D3 alert page shipped; D1, D2 and D3's *selector* SUPERSEDED 07-21 by context policy; D7, the red-team set and D9's load test remain unbuilt.

### 2026-07-19 — `GroundingMaterial` model replaces `viva_grounding` tags
**platform code** · revs 1860–1875; `docs/superpowers/specs/2026-07-19-viva-grounding-materials-design.md`
- **Problem observed:** grounding tags had no working authoring UI and overloaded `Tag`; discovered in planning: uploaded files were *never* text-extracted — file grounding had always contributed empty text.
- **Change:** dedicated `GroundingMaterial` (title, body, files, estimated tokens) with an admin library and a viva-only attach select; files delivered as base64 PDF parts; tag kind retired after backfill.
- **Outcome / status:** live.

### 2026-06-11 — Release 4.4.0 backfills the hardening sprint
**docs/tooling** · rev 1754; CHANGELOG 4.4.0 Security "Viva exam hardening (revs 1722–1736)".

### 2026-06-10 — Pilot content kit (`course-prep`, `llm_prompt` scheme)
**prompt text (course content)** · `course-prep/data-structures/viva/pilot-midterm/` (kept for provenance)
- **Change:** five DS pilot scenarios for the old tag scheme; `course-prep/` deliberately outside the code repo so exam material never reaches the GitHub mirror.
- **Outcome / status:** SUPERSEDED 2026-08-15 by kit `practice-2569-1a`.

### 2026-05-25 — Viva-irrelevant form fields hidden
**platform code (UI)** · rev 1736 — Stimulus toggle hides permitted_lang / submission_filename / view_testcase for viva; `view_submission` kept (peer transcript visibility). Edit page redesigned again 08-28.

### 2026-05-21 — Problem PDF hidden from students on viva problems
**platform code + policy** · revs 1733, 1735
- **Problem observed:** the PDF was the interviewer's brief; revealing it defeats the interview.
- **Change:** `Problem#pdf_visible_to_student? = !viva_exam?`, `User#can_view_problem_pdf?`; web and API gates; no PDF link on the main list.
- **Outcome / status:** live; API description endpoint got the same gate 07-21.

### 2026-05-21 — Stuck assistant turns recover; `fail_stale!` sweeper; Retry button
**platform code** · revs 1732, 1739
- **Problem observed:** sessions parked forever on "Interviewer is thinking…"; recurring-task additions never took effect because solid_queue was not restarted on deploy.
- **Change:** non-retryable errors → `on_retries_exhausted`; `VivaTurn.fail_stale!` (10-min threshold, 5-min recurring task); owner-or-admin Retry; graders page "Background Workers" card + stuck-turns list; deploy pipeline restarts solid_queue.
- **Outcome / status:** live.

### 2026-05-20/21 — Answering restricted to the owner
**platform code + policy** · revs 1727–1730
- **Problem observed:** admins could post into a student's viva, corrupting transcript ownership.
- **Change:** owner-only `#answer`; non-owners see "Viewing as observer".
- **Outcome / status:** live.

### 2026-05-20 — First jailbreak directive: detect *and* terminate (v1)
**prompt text (backend-injected) + platform code + policy** · revs 1722–1728; migration `add_viva_terminated_at_to_submissions`
- **Problem observed:** no defence against role spoofing, answer extraction or question laundering.
- **Change:** `SECURITY_DIRECTIVE` injected into the system prompt; on detection the model prints a banner + `[[VIVA_ALERT]]`; backend sets `viva_terminated_at` and grades the partial transcript with a termination note.
- **Outcome / status:** SUPERSEDED 2026-07-21 by detect-only + backend strike policy (the model no longer decides consequences).

### 2026-05-17 — `viva` Language seeded by migration; name locked
**platform code** · revs 1697–1698 — existing installs get the sentinel language without a manual seed; unique index + immutability.

### 2026-05-12 — `Viva-Exam.md` rewritten to match the implementation; Decision Log born
**docs/tooling** · revs 1695–1696 — PDF as canonical scenario (later reversed), `llm_prompt` with `# Rubric`, grounding in the user message, Failure Modes. Rewritten again 07-21 and 08-15.

### 2026-05-11 — Retry-exhaustion marking; response-shape validation; Genie token failure
**platform code** · revs 1692–1694
- **Problem observed:** eternal spinner when all retries failed; an empty assistant turn accepted as `:ok`; Genie "no token" returned nil → confusing `NoMethodError`.
- **Change:** `on_retries_exhausted` per job; raise on blank content; Genie raises on token failure.

### 2026-05-09 — Soft archive (`viva_archived_at`) instead of delete
**platform code + policy** · revs 1686–1688; Decision Log "Soft archive instead of delete"
- **Problem observed:** letting a student retake required destroying a submission (cascades to turns, grade, comments — irreversible).
- **Change:** nullable `viva_archived_at`; main list ignores archived; start refuses while an active viva exists; admin `archive_viva` on terminal states.
- **Outcome / status:** live; extended to self-service restart 07-21.

### 2026-05-08 — Re-run grading with a model override; Genie roster
**platform code + model/provider** · revs 1682 (master), 1683 (chula_cp `KNOWN_MODELS`)
- **Problem observed:** a grade stuck on gemini-2.5-flash refusing JSON-only output.
- **Change:** admin picker passes `model:` to the grade job; gemini-2.5-pro recommended for strict JSON.
- **Outcome / status:** live; the picker is the only explicit-model caller after rev 2011.

### 2026-05-08 — `:evaluating` treated as terminal; state-driven view; admin and debug cards
**platform code (UI)** · revs 1672–1681
- **Problem observed:** after `[[VIVA_DONE]]` the answer form stayed open (turn job vs grader race, double cost); `grader_error` rendered as an empty card.
- **Change:** `#answer` rejects late answers; view dispatches on `submission.status`; Admin card (Re-run grading), Debug card (raw responses, next-payload previews).

### 2026-05-08 — Problem setup validation before start (`viva_setup_errors`)
**platform code** · revs 1668–1671
- **Problem observed:** half-broken sessions when the prompt lacked a Rubric section.
- **Change:** `Problem#viva_setup_errors`; `#start` refuses with a flash. (Same day, description-field checks were dropped on the belief that the PDF carries the scenario — reversed by D5 on 07-20.)
- **Outcome / status:** live; the `# Rubric` check now runs against `viva_prompt`.

### 2026-05-08 — Grader raw response persisted; tolerant JSON extraction
**platform code** · revs 1666–1667
- **Problem observed:** "no JSON object found" raised and the raw body was discarded — nothing to inspect.
- **Change:** raw saved before parsing; balanced-brace extractor tolerating fences and prose.
- **Outcome / status:** live; the "first balanced object" behaviour later allowed silent zeros → rev 2043.

### 2026-05-07/08 — Session UI: markdown rendering, info card, scroll preservation
**platform code (UI)** · revs 1658–1665, 1687–1689
- **Problem observed:** students saw literal `**stars**`; polling replaced the chat container and jumped to the top every 3 s.
- **Change:** `safe_markdown` (Redcarpet, HTML filtered) for LLM output; innerHTML swap with scroll restore.
- **Outcome / status:** live. `safe_markdown`'s lack of LaTeX later motivated the no-LaTeX directive (08-27).

### 2026-05-07 — Grounding moves to the user message; backend stops injecting scenario prose
**prompt assembly** · rev 1656
- **Problem observed:** the system message mixed persona with "the case"; an auto-appended scenario paragraph pushed English prompt engineering into Ruby.
- **Change:** grounding text → first user message with scenario and PDF; scenario paragraph removed; the done-sentinel directive becomes the single backend-owned English text. The grader keeps grounding in system (its rubric source).
- **Outcome / status:** live.

### 2026-05-07 — Same-role message consolidation; prompt required; PDF sent to the LLM
**platform code / prompt assembly** · revs 1650–1653
- **Problem observed:** consecutive `user` messages degrade Gemini/OpenAI and Anthropic refuses them; a viva with no prompt tag silently ran with only the done-sentinel instruction; the LLM never saw the PDF.
- **Change:** `consolidate_role_runs`; assembly raises without a prompt; PDF as an `image_url` part in the first user message (for gateway providers SUPERSEDED 08-26 by OpenAI `file` blocks).

### 2026-05-07 — `Llm::Request` hierarchy; viva error handling tightened
**platform code** · revs 1634–1648; `doc/llm-refactor-handoff-2026-05-07.md`
- **Problem observed:** retry/error contract ad hoc; grade JSON failures swallowed (job "succeeded"); one regression crashed every LLM job → eternal spinner; `viva_turn_service`/`viva_grade_service` sat outside the YAML anchor so `config_for(:llm)` never loaded them and the abstract base raised.
- **Change:** retryable vs deterministic errors (`ResponseError`); viva services raise on no-JSON so Solid Queue records the failure; config keys moved inside the anchor; console `Llm::Request.preview` for prompt-assembly debugging.

### 2026-05-05 — Scenario sent as the first user message; wire-role fix; first `Viva-Exam.md`
**docs/tooling + platform code** · revs 1623–1630
- **Problem observed:** authors could say *how* to interview (tag) but not *what* to interview about; `role: "student"` was sent literally on the wire.
- **Change:** `problem.description` sent as the first user message on every turn and grader call; student → user remap; grader becomes system + user(scenario) + user(transcript).
- **Outcome / status:** live; description made the primary scenario channel by D5 (07-20).

### 2026-05-04 — Viva start route bug; Re-grade moved to Turbo Stream
**platform code** · revs 1605–1606, 1611
- **Problem observed:** `set_problem` read `params[:problem_id]` on a member route passing `:id` — every start 404'd; Re-grade used `remote: true` + `.js.haml`.
- **Change:** read `params[:id]`; integration tests; `button_to` + Turbo + shared toast, GET → POST.

### 2026-04-19 — Chula Genie wiring (chula_cp)
**model/provider** · chula_cp revs 1590–1591
- **Change:** `VivaTurnGenieAssist` / `VivaGradeGenieAssist` POST through Genie's OpenAI-compatible endpoint; default model gemini-2.5-flash.
- **Outcome / status:** SUPERSEDED 2026-08-27 by the Chula AI Gateway flip.

### 2026-04-19 — Viva exam feature lands
**platform code** · revs 1587–1588
- **Problem observed:** no oral-exam alternative to code submission.
- **Change:** `compilation_type: viva_exam`; `viva_turns` (one row per turn, sequence assigned under a row lock) and `viva_grades`; provider-agnostic `Llm::VivaTurnAssist` / `Llm::VivaGradeAssist` (OpenAI-compatible shape, concrete provider via `config/llm.yml`); sentinel `Language("viva")`; `VivaSessionsController` start/show/answer/refresh with a polling Stimulus controller; the interview ends when the model emits `[[VIVA_DONE]]`.
- **Outcome / status:** core architecture unchanged since. Prompt storage in `llm_prompt` tags SUPERSEDED 07-21 (D6); `viva_grounding` tag kind SUPERSEDED 07-19 (`GroundingMaterial`).
