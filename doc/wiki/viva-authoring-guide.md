# Authoring Guide: Writing a Viva

This guide is for the person who *writes* a viva — the scenario the student
reads, the private briefing the AI examiner follows, and the rubric the AI
grader applies. It is about craft: what makes an interview that actually
measures understanding, and the mistakes we have watched examiners and
graders make on real student sessions.

Companion pages: the [Instructor Guide](instructor-viva-guide) covers
*operating* a viva (fields, limits, alerts, regrading, contests); the
platform reference `doc/Viva-Exam.md` in the repository covers *how the
prompt is assembled* and the session lifecycle. This page assumes neither.

A live document. Each section that came from a lesson says so; the change
log of the viva feature itself is `doc/Viva-History.md`.

---

## 1. What a viva is good for

A viva is a chat interview about a small artifact — a code fragment, a data
structure choice, a design sketch — graded from the transcript. It measures
*whether the student can explain, trace, predict and critique*. It does not
measure whether they can produce working code; you have ordinary problems
for that.

Three shapes work well, in increasing length:

| Shape | Typical rungs | Student turns | Example |
|---|---|---|---|
| **Debug / concept** | trace → witness → bug → precondition → cost | 6–9 | "This four-line fragment is sometimes wrong. Why?" |
| **Container choice** | requirement → choice → justify → cross-question | 8–12 | "Which container for X? Now the requirement changes." |
| **Design** | operations → structure → invariant → worked example → cost | 10–15 | "Design the bookkeeping for a prepaid card." |

Roughly three quarters of paper-exam questions do **not** convert: anything
that needs a compiler, a long derivation, a drawing, or a single numeric
answer. A good viva candidate has one small artifact, is answerable in
words and short fragments, has at least one *trap* (a plausible wrong
diagnosis), and has small examples a student can trace by hand.

---

## 2. The pieces you write, and who sees them

| Piece | Where it lives | Who sees it |
|---|---|---|
| **Scenario** | the problem's Description field | the **student**, delivered by the examiner's opening message (the viva page shows no statement) |
| **Examiner briefing** | the problem's *Examiner briefing* field (`viva_prompt`) | examiner and grader LLMs only — model answer, interview plan, `# Rubric` |
| **Conduct profile** | a shared tag, attached to many problems | examiner and grader — the course's house rules, split into a base and a mode overlay (§5) |
| **Grounding material** | a shared library, attached per problem | examiner and grader — reference text they must treat as authoritative |

Everything you write in the briefing or a conduct tag is read by **both**
the interviewer and the grader. Write content — model answers, plan,
rubric, tone. Never write operational rules ("if the student says X, print
Y", output formats, alert banners): the platform injects those itself and
keeps them in lockstep with the code that parses them; yours will compete
with them and can break grading. (This is not hypothetical — see the
Instructor Guide.)

---

## 3. Step 1 — Choose and shape the scenario

**Start from something real.** Old paper exams are the best source: the
question has already been vetted, and the marking scheme tells you what the
rubric should reward. Reskin the domain if the paper is still in
circulation.

**Pass the checklist:**

- One artifact, small enough to quote in a chat bubble (≤ ~10 lines of code
  or ≤ ~6 rules).
- Answerable in words and short fragments; no compiler needed.
- Has a **trap**: a wrong diagnosis a reasonable student will offer, that
  the examiner can probe with one question.
- Has **witnesses**: tiny inputs (5 elements, 3 operations) the student can
  trace by hand and the examiner can verify by hand.
- Gradable from the transcript alone: you can name 4–6 rubric criteria now.

**Write the "Come prepared to" list.** The scenario ends with a numbered
list of what the student will be asked. It is the *public face of your
rubric*: each item should map to a criterion. Students who prepare against
it are doing exactly what you want; the interview's job is to check the
preparation is theirs (§7).

Keep it compact. The student cannot see the scenario anywhere else — the
examiner reproduces it verbatim in the opening message, and a long scenario
makes a long first bubble.

### Worked example — "The Distinct Counter" (illustrative, not deployed)

> A classmate wrote this to count how many *distinct* values a
> `std::vector<int> V` contains:
>
> ```cpp
> auto it = unique(V.begin(), V.end());
> cout << it - V.begin() << endl;
> ```
>
> It compiles, and for many inputs it prints the right number — but for
> some inputs it does not.
>
> Come prepared to: (1) explain what `unique` does and what `it - V.begin()`
> counts; (2) give a 5-element `V` for which it prints the correct count and
> another for which it prints a wrong one, with the printed and true values;
> (3) state the bug precisely and give the minimal fix; (4) say what `V`
> looks like *after* the call; (5) compare the cost of the fixed version
> with using a `set`.

Every item maps to a rung and a criterion. There is a trap (students say
"`unique` needs a sorted range", which is true of the *intent* but not of
the function's contract — it removes *adjacent* duplicates on any range).
Witnesses are 5 elements. Nothing needs a compiler.

---

## 4. Step 2 — Write the examiner briefing

The briefing has three parts, in this order. Keep the headings; the
platform validates that a heading starting with `Rubric` exists.

### 4a. Model answer — "for your judgment only, never reveal"

Write the answer *you* would give, then verify every claim by hand. The
examiner will trust this text over the student, so a wrong model answer
grades every student wrong.

- State the precise rule, not just the bug: *"the fragment is correct
  exactly when every group of equal values is already contiguous; otherwise
  it over-counts."* A rule lets the examiner judge witnesses it has never
  seen.
- Give **verified** witnesses for both sides, traced: *`{1,1,2,2,3}` → prints
  3, true 3 ✔; `{1,2,1,2,3}` → no adjacent equals, prints 5, true 3 ✔.*
- Name the trap and the correct reply to it: *"unique needs a sorted range"
  → ask "what does unique promise on an unsorted range? try `{1,2,1}`."*
- List acceptable alternatives (`sort` then `unique`; `set<int>(V.begin(),
  V.end()).size()`; a loop with a `set`), and the bonus points (the tail of
  `V` after `unique` holds unspecified values; `V.size()` is unchanged, so a
  student who thinks `V` shrank has misunderstood the erase–remove idiom).
- Say which student claims are *fine* and which reveal a misconception, so
  the examiner knows when to probe and when to move on.

### 4b. Interview plan — numbered rungs, gates, traps, scaffolding

```
1. What does line 1 do and what does line 2 print? Gate: the student must
   say "adjacent" (or an equivalent) before moving on.
2. Correct 5-element witness, then a wrong one. For each: what is the
   printed value, what is the true count, walk me through the elements.
   Verify the trace yourself.
3. State the bug in one sentence and the minimal fix. Trap: "the range is
   not sorted" → "what does unique promise on an unsorted range?"
4. What does V look like after the call? Probe for "size unchanged, tail
   unspecified", not "V is now the distinct values".
5. Cost: sort+unique vs set vs unordered_set. When is each preferable?

Scaffolding: if the student cannot find a wrong witness, ask "put two equal
values apart from each other" — one hint only. If they cannot explain
line 2, ask what `unique` returns on {1,1,2} and where that iterator points.
```

Rules that came from real sessions:

- **Number the rungs and mark gates.** The examiner follows them in order
  and a gate stops it skipping ahead when a student volunteers a later
  answer.
- **Pre-write the probe for each trap** in the examiner's language. Left to
  itself, an LLM examiner tends to *state the correction* ("not quite — the
  range is sorted, the problem is…") instead of asking the question that
  makes the student find it.
- **Pre-write the one hint per rung**, and make it a *question*, not a fact.
- **Say what to do when a rung is out of reach**: spend remaining turns
  hardening earlier rungs, so the grade rests on evidence rather than on
  criteria the interview never reached.
- **Demand the working, not the claim.** "Walk me through it" for every
  witness. Untraced witnesses are the single most over-credited thing in
  our audit (§8).
- **Aim for a turn count** and write it into the plan ("aim for 6–9 student
  turns"). The platform's soft cap is advisory; the plan is what the
  examiner actually paces by.

### 4c. Rubric

```
# Rubric

Weights sum to 100. Apply the course grading conventions.

- fragment_semantics (20): explains that unique removes adjacent
  duplicates and what the iterator difference counts.
- witnesses (25): a correct 5-element correct case AND a correct 5-element
  failing case, each with the printed value and the true count, traced.
  A witness with the wrong printed or true value caps this criterion at
  12; only one of the two witnesses caps it at 12.
- bug_and_fix (20): pinpoints that equal values must be adjacent (a
  contract mismatch, not a "sort is missing" error) and gives a correct
  fix. Diagnosing it as "unique requires a sorted range" caps this at 8.
- post_state (15): V.size() unchanged; elements past `it` are unspecified;
  the erase–remove idiom if they want the vector trimmed.
- cost_critique (20): sort+unique O(n log n) in place vs set O(n log n)
  with allocations vs unordered_set O(n) expected; a correct statement of
  when each is preferable earns the last few points.
```

- **Keys** are `snake_case` identifiers; the grader returns them verbatim in
  its JSON, and the admin page shows them. Four to six criteria is the
  sweet spot.
- **Weights sum to 100** and each criterion scores at most its weight. Say
  so; an LLM grader that is told "0–100" will happily score every criterion
  out of 100.
- **Caps for critical failures** are the most reliable lever you have
  ("caps this criterion at 8"). Graders apply them consistently; they apply
  vague instructions ("penalize heavily") inconsistently.
- **Say what earns the last few points** — otherwise the grader gives full
  marks for a partial answer.
- Every criterion should be reachable by the interview plan; a criterion
  the plan never reaches scores 0 (and must — see §5).

### 4d. Per-problem carve-outs

The conduct profile (§5) sets course-wide rules; the briefing may *narrow*
them for this problem. Example: in practice mode our conduct lets the
examiner state a key point in one sentence after a rung is settled — but a
briefing whose witnesses are exactly what a retaker would paste verbatim
adds: *"never supply a concrete witness at any point; say at most which
values would need to be apart."* The briefing sits after the conduct in the
prompt, so it wins on specifics.

---

## 5. Step 3 — The conduct profile: base + mode overlay

Conduct is what every viva in a course shares. We keep it as **two tags**
on each problem: a **base** that never changes with mode, and one **mode
overlay** (practice *or* exam). The platform concatenates attached tags in
name order, so name overlays as suffixes of the base
(`DS-viva-conduct-2569`, `DS-viva-conduct-2569-practice`).

What belongs where:

| Base (mode-invariant) | Practice overlay | Exam overlay |
|---|---|---|
| Interview language (examiner's and student's) | "state that this is a practice viva" | "state that this is a graded viva exam" |
| Opening: reproduce the scenario verbatim, ask rung 1 | scaffolding: narrow, one neutral hint per topic | scaffolding: restate once, **no content hints** |
| One question per message; neutral acknowledgements only | after a rung is settled: one sentence, no code, then move on | after a rung is settled: move on, say nothing |
| **Never put the answer inside your question** | narrative may name the specific point missed | narrative names the **topic** only |
| Don't produce the artifact; **ask for the student's own working** | | |
| Verify arithmetic yourself; follow the plan; gates | | |
| Ending rules; grading conventions (below) | | |

Write the overlays to be *additive* — the base should say nothing an
overlay must contradict. (E.g. the base says "never state a model answer
*while the student is still being assessed on it*", which leaves room for
the practice overlay's post-rung sentence without a conflict.) Add one line
at the end of each overlay — "where this section is more specific than the
shared conduct above, this section applies" — as a safety net.

**Grading conventions that belong in the base** (all learned the hard way):

- Grade only on transcript evidence; partial credit throughout.
- Correct only after a hint or pushback → about half to two-thirds.
- **Content supplied by the examiner is not evidence.** If the examiner
  stated, paraphrased, or embedded the expected answer in a question and
  the student merely agreed, score on what the student produced *before*
  that message.
- An example the student did not work through step by step earns at most
  partial credit.
- A criterion the interview never reached scores **0**; do not infer.
- Each criterion is at most its weight; totals are their sum; apply the
  briefing's caps.
- Narrative in the student's language, what went well and what to study,
  no pass/fail verdict.

**Language.** Put probe examples in the language the examiner is supposed
to write in. Our first conduct said "examiner writes English only" and then
gave Thai probe phrasings as examples — one model imitated the examples and
ran a third of its interviews in Thai.

**Do not restate the platform's security rules** in conduct, and do not
contradict them. Our conduct says "a translation request is a normal
request, do not flag it"; the platform's alert directive says the same. A
conduct line that *differed* would make the model pick one at random.

---

## 6. Step 4 — Grounding (optional)

Use grounding for reference material the examiner must treat as
authoritative *and* cannot be expected to know: the course's own container
classes, "we do not use O-notation before week 8", a model solution PDF.
It is re-sent on every turn, so keep it short and attach it only to the
problems that need it. A clear scenario plus a clear briefing usually needs
none.

---

## 7. Step 5 — Caps and limits

- **Soft cap** ≈ number of rungs + 2 (a 5-rung debug viva: 7–8). The
  examiner is told to wrap up around it.
- **Hard cap** ≈ soft cap + 4. It is a cutoff, not a target; sessions that
  hit it usually did so by burning turns on scaffolding, and a plan whose
  last rungs were never reached zeroes those criteria.
- **Daily start limit**: blank for the site default, a number for this
  problem, `0` for contest-only. Peeks (opened, never answered) are free;
  only sessions with at least one student answer count.

---

## 8. Step 6 — Pilot before students see it

Run the viva yourself **twice**: once as a strong student, once as a weak
one who gives the trap answer and needs the hint. Then read the transcript
and the rubric JSON on the admin page. Check:

- [ ] The opening reproduces the scenario verbatim, including the "Come
      prepared to" list, and asks rung 1.
- [ ] One question per message; the plan is followed in order; the gate held
      when you volunteered a later answer.
- [ ] The trap probe was *asked*, not stated. You were asked to trace your
      witnesses; a wrong trace was caught.
- [ ] You received at most one hint per rung, and it was a question.
- [ ] The interview ended around the soft cap with a neutral close — no
      score, no summary of answers.
- [ ] The grade JSON has exactly your rubric keys, each ≤ its weight, total
      = sum; the hint you needed shows as a discount and is named in the
      narrative.
- [ ] The narrative is in your language and does not spell out the answer
      (exam) / names the specific point (practice), as your mode intends.

If the grader returned prose instead of JSON, or the keys don't match, the
briefing's `# Rubric` block is the first thing to inspect.

---

## 9. Step 7 — After launch: the audit loop

Transcripts are the feedback channel for your briefing. Once a week, or
after every ~50 sessions, read:

- **Alerted sessions** (admin list): are the flags real attacks, or
  translation requests and "can we skip this?" (both non-triggers)? A false
  positive under exam policy terminates an honest student.
- **Sessions at the hard cap**: what burned the turns — scaffolding, a
  student stalling, the examiner tracing for the student?
- **Very short high scores** (≤ 3 student turns, ≥ 90): almost always a
  pasted omnibus answer that the examiner accepted without re-verifying.
- **Narratives**: do they leak the answer? Retakers read them.
- **Grader calibration**: pick five transcripts and re-grade them yourself
  against the rubric; disagreements of more than ~10 points point at a
  rubric line, a missing cap, or a grader model to change.

Split every statistic by **examiner model**: in our first audit the
proportion of sessions hitting the hard cap went from 42% to 3% across a
model change with the *same* prompt. Compliance is largely a model
property; fix the model before you fix the prompt.

Then decide which layer the fix belongs to: briefing (this problem's trap,
hint, witnesses), conduct (every problem in the course), or platform (a
code change — file it in the repo's backlog).

---

## 10. Pitfalls catalogue

Every row is something we observed on real student sessions
(2110211 Data Structures, practice vivas, Aug–Sep 2026, 182 sessions).

| Symptom in the transcript | Cause | Fix (layer) |
|---|---|---|
| Examiner writes in the student's language although told not to | Weaker model imitating Thai probe *examples* in the conduct | Examples in the examiner's language (conduct); stronger model |
| "Excellent! Exactly right!" after every answer | Model's default register; running assessment revealed | "Neutral acknowledgements only — no praise, no 'correct', no 'not quite' while a rung is open" (conduct) |
| Examiner states the fix after the student fails, then asks the next question | No rule about what happens *after* a rung is settled | Base: never state a model answer while it's being assessed; overlay decides post-rung behaviour (conduct) |
| "So the fix is X, right?" → "yes" → full marks | Leading yes/no question | "Never put the answer inside your question" (conduct) + "examiner-supplied content is not evidence" (grading) |
| Witnesses accepted untraced; omnibus first message scores 100 in 2 turns | Examiner skips the trace demand; grader credits claims | "Ask for the student's own working" (conduct); "untraced example = partial at most" (grading); pilot with a pasted answer |
| Sessions hit the hard cap with rungs 4–5 never asked | Scaffolding burn; examiner tracing for the student | Pre-written single hints; "if out of reach, harden earlier rungs" (briefing); model change |
| Interview ends at turn 4 with thin evidence | Stronger model over-corrects on pacing | "Do not end while a criterion rests on an unverified claim" (conduct) |
| Grade narrative spells out the fix; retakers score 30 → 92 in 20 minutes | Narrative written as feedback, read as an answer key | Exam overlay: topic only. Practice: your call — we keep it, with per-problem carve-outs for witnesses |
| Criterion scored 8/20 for a topic never discussed | Grader infers | "Unreached criterion = 0" (grading) |
| Rubric JSON has every criterion out of 100, total 94 | Grader followed a "0–100" schema hint | "Each criterion at most its weight" (grading); the platform validates weights |
| Translation request / "what does viva mean?" / "skip this?" flagged as jailbreak | Weaker model over-triggering | Do not duplicate or contradict the security directive in conduct; stronger model; review flags before enabling exam policy |
| Perfect LaTeX-formatted essay 81 seconds after "I have no idea what upper_bound is" | External LLM paste | Not a prompt problem: environmental control for exams; for practice, treat scores as formative |
| Student abandons the moment the examiner corrects them, restarts, scores 94 | Every adaptive interview is an oracle | Exam: single attempt. Practice: accept, or rotate scenario parameters between attempts |
| Examiner announces "the interview is over" but the session never ends | Model omitted the end-of-interview token | Platform issue; report it — a stronger model fixed it |

---

## 11. Bulk authoring with a kit

For a course, keep scenarios, briefings, conduct and grounding as markdown
files in a kit directory with a `manifest.yml`, and import with
`bin/rails viva:import DIR=<kit>` (report only) then `APPLY=1`. The import
is idempotent by problem name, conduct-tag name and grounding title;
`available` is applied on create only; links are add-only. Conduct is a
list — one base plus one overlay:

```yaml
conduct_tags:
  - {name: DS-viva-conduct-2569,          file: _conduct.md}
  - {name: DS-viva-conduct-2569-practice, file: _conduct.practice.md}
```

Two operational notes: the kit is *data* — the deployment pipeline ships
code, and a kit reaches a server's database only when you copy it there
and run the import on that host. And the dry run should list every conduct
tag you expect before you `APPLY`; an importer older than the list form
skips the block silently.

---

## 12. Checklist

- [ ] Scenario: one artifact, a trap, hand-traceable witnesses, a "Come
      prepared to" list that maps to the rubric.
- [ ] Briefing: verified model answer with the precise rule; numbered rungs
      with gates, pre-written trap probes and single hints; `# Rubric` with
      snake_case keys, weights summing to 100, caps, "last few points".
- [ ] Per-problem carve-outs where the conduct's mode overlay is too
      generous for this problem.
- [ ] Conduct: base + one mode overlay attached; overlays additive; probe
      examples in the examiner's language; grading conventions in the base.
- [ ] Caps sized to the plan; daily limit chosen; grounding only if needed.
- [ ] Piloted twice (strong, weak); transcript and rubric JSON read.
- [ ] First audit scheduled after ~50 sessions; statistics split by model.
