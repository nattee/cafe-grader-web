# Judge Worker Pool — Design

**Date:** 2026-10-04
**Status:** Approved in discussion (dae, 2026-10-03/04), pending spec review
**Scope:** replaces the per-server judge worker (`Grader.start`, one Rails
process per isolate box, polling the server's own MySQL) with a pool of
database-less workers that serve any server over a versioned HTTP protocol.
**Related:** `doc/backlog.md` "Language-specific options in the database
(issue #42)" (its *Reopen when* condition is this design); migration
`20260908120000_add_status_priority_id_index_to_jobs.rb` (the 2024–25
"more boxes = slower polling" root cause); `app/engine/replay/*` and
`app/engine/engine_smoke.rb` (the equivalence harness this design reuses).

## 1. Problem

Every cafe-grader deployment ("server") needs its own judge host, and that
judge host can serve only that server. The worker is not a client of the
server; it *is* the server's code: `Grader.start` is `rails runner` from the
same checkout on the same `database.yml`, it polls the `jobs` table directly,
calls `Submission.find` / `Dataset.find` / `Testcase.find`, writes `Evaluation`
rows and heartbeats into `grader_processes`. Only files cross HTTP
(`WorkerController`, one shared passcode). Consequences:

- Eleven servers need eleven sets of boxes; idle capacity on one cannot help
  a burst on another.
- The worker assumes the server's schema. The fleet runs two branches
  (`master` on compas / cg / toi / template, `chula_cp` elsewhere), so one
  pooled checkout of today's worker cannot serve all of them.
- Every id the worker holds is bare (`jobs.arg` = submission id, cache dir
  `problem_id/dsid_N/testcase_id`, `worker_datasets(worker_id, dataset_id)`),
  so nothing says which server an id belongs to.
- Each box costs a full Rails process (365–631 MB resident on cp-worker), one
  MySQL connection, ~20 queries per testcase, five polls per second when idle,
  and one HTTP download of the compiled binary **per testcase** (3 MB average,
  23 MB max; ~14 testcases per compile), which is ~40 % of all Apache requests
  on cp-grader.

**Goal:** one worker program that serves any number of servers, with no
database access, no schema coupling, no per-testcase binary transfer, fewer
server round trips, and better failure diagnostics than today's error card.

**Non-goals (this spec):** a central broker (approach C, §14), a cross-server
fleet dashboard, moving language settings into the `languages` table
(groundwork only, §9.4), changing how students or problem setters use the
site.

## 2. Terms

One name per thing; these names are used throughout the code, the API and
the admin pages.

| Term | Meaning |
|---|---|
| **server** | one cafe-grader deployment: Rails app + its own MySQL. Owns submissions, datasets, the queue and the grade. |
| **worker** | one judge host. Runs one **agent**. Serves one or more servers. Has a name (e.g. `cp-worker-1`). |
| **agent** | the worker's supervisor process. Talks to servers, owns the runners, the cache and the logs. |
| **runner** | one child process of the agent bound to one isolate **box** for its whole life. Executes one job phase at a time. |
| **box** | one isolate sandbox (`isolate -b N`). Box ids are per host. |
| **lane** | a group of runners reserved for one phase: the **compile lane** and the **run lane**. |
| **job** | one unit of work on the wire. Day one has one **kind**: `grade` = compile + run every testcase of one submission against one dataset. Each job has a server-side id and a **lease**. |
| **envelope** | the self-contained JSON description of a job: everything the engine reads today, plus file URLs with content hashes. |
| **claim** | the request by which an agent takes jobs from a server and receives envelopes with leases. |
| **lease** | the time-bounded ownership of a job by one worker, identified by a lease token. Renewed by progress and heartbeat; expired leases are swept back to the queue. |
| **capability** | something a worker can do, detected at start and reported in every heartbeat (`lang:cpp`, `postgres`, `cg`, `net`, `mem:8192`). An envelope lists what it **requires**. |
| **cost** | the server's estimate of a job's sandbox time: testcases × time limit. Drives the compile lane's prefetch and the small-job reserve. |
| **dial** | `GraderConfiguration['judge.pool_share']`, the percentage of new submissions enqueued as `grade` jobs instead of the legacy compile/evaluate/score chain. |
| **shadow** | a `grade` job flagged `shadow: true`: graded by the pool, result stored in a shadow table and diffed, never shown to students. |
| **verdict** | a grading outcome caused by the submission: compile error, wrong answer, crash, timeout, partial. Never an error. |
| **infrastructure error** | a failure caused by the worker or the server: missing compiler, full disk, isolate failure, agent exception, bad envelope. Pauses the worker for that server and re-enqueues the job. |
| **legacy path** | today's in-process boxes and their compile / evaluate / score jobs. Kept until phase 4. |

## 3. Measured facts the design rests on

Collected 2026-10-03 by read-only ssh and from the local prod copy of
cp-grader's DB.

| Fact | Value |
|---|---|
| cp-worker 10.0.5.81 | 32 cores, 32 GB, no swap; 8 boxes; every sandbox run in 24 h had CPU/wall ≥ 0.95 (no core contention) |
| cp-grader 10.0.5.50 | 8 cores, 16 GB; Passenger max pool 6; MySQL defaults |
| Worker share of cp-grader's Apache requests | ~40 % (6,095 of 15,611 one day; 9,955 of 23,397 the next), ~93 % of it `get_compiled_submission` |
| Compiled binary | 3 MB average, 23 MB max; ~14 testcases per compile → ~40 MB per submission through Passenger |
| Testcase corpus on cp-grader | 14,266 files, 663 KB average, 9.0 GB total |
| Peak load, last 12 months | 77 submissions/min; 528 per 10 min (2026-04-09 08:20 Bangkok); 5,239/day |
| 16-box experiment | boxes 9–16 on cp-worker 2024-11-03 → 2025-06-13; symptom: poll interval stretched with box count; cause: no index on `jobs.status` until 2026-09-08 (full scan per poll; every `FOR UPDATE SKIP LOCKED` claim locked every row it scanned; 353 of 1,200 concurrent claims came back empty) |
| Worker logs | `log/judge.log` on cp-worker is 121 GB, unrotated |

## 4. Decision

**Approach B, the protocol worker.** The worker is a thin client that never
touches a database. Each server exposes a versioned judge API. The unit of
exchange is the envelope.

Rejected, **approach A** (pooled Rails worker with per-origin
`connected_to`): needs every worker to hold every server's DB credentials and
network reach, loads one set of models against drifting schemas, and wraps
ActiveRecord calls scattered across compiler / evaluator / checker / scorer,
so it pays a rewrite without buying decoupling.

Deferred, **approach C** (central broker): B plus one always-on service. Buys
worker discovery and cross-server priority; costs one more thing to run. B is
designed so C is a drop-in: the envelope, lease and report protocol are
identical, only the claim step changes from polling servers to reading a
broker. Reconsider when the server × worker matrix becomes painful (§14).

Settled sub-decisions (dae, 2026-10-03/04), each with its reason in the
section that implements it: wire unit = one submission (§6.3); scoring moves
server-side (§7.4); lanes replace the per-box job-type filter (§9.3); one
bearer token per worker × server pair (§10); failure reports and the event
timeline are first-class protocol objects (§6.6, §7.5); everything lands on
`master` in releasable slices, no feature bookmark (§12).

## 5. Architecture

```
 server A (Rails + MySQL)            server B                 server C (no judge API yet)
   jobs table = queue                  jobs table                  jobs table
   judge API v1  ◄──────┐              judge API v1 ◄──┐           legacy boxes only
   Graders page         │                              │
                        │ HTTPS, bearer token          │
                 ┌──────┴──────────────────────────────┴──────┐
                 │ agent  (cp-worker-1)                        │
                 │  claim loop per server · heartbeat · policy │
                 │  local scheduler · cache (by sha256)        │
                 │  runners: compile lane [1 2] run lane [3..8]│
                 └─────────────────────────────────────────────┘
```

- The server keeps the `jobs` table as its queue and adds the claim endpoint
  on top of today's `take_oldest_waiting_job` logic. No new component.
- The agent polls each server it is configured for, in its own thread, only
  while it has an idle runner, and asks for up to *k* jobs at once.
- Files travel server → worker once per content hash. Results travel
  worker → server as small JSON. The compiled binary never leaves the worker.
- The server owns every DB write: evaluation rows, submission status, the
  score, the timeline.

## 6. Protocol: judge API v1

All endpoints live under `/judge/v1/` on each server, JSON in and out,
`Authorization: Bearer <token>`. Documented as an rswag spec so
`swagger/judge/v1.yaml` is the contract both sides test against (§11.1).

### 6.1 Versioning

Every request carries `X-Judge-Protocol: 1` and `X-Judge-Agent: <version>`.
A server answers `426 Upgrade Required` with its supported range when the
protocol is outside it; the agent logs once and stops polling that server
until the next config reload. Within a major version, fields are only added,
never removed or re-typed. A worker serves any server whose range includes
its version, so the fleet never needs lock-step deploys.

### 6.2 Endpoints

| Method, path | Purpose | Notes |
|---|---|---|
| `POST /judge/v1/heartbeat` | register / keep alive; report capabilities, runner counts, disk, version, current job ids; receive **policy** (§7.6) | every 5 s; the reply is the server's per-worker policy, so a pause on the page reaches the agent within one beat |
| `POST /judge/v1/claim` | take up to `max` jobs this worker can run | body: `{max, capabilities, lanes:{compile_idle, run_idle}}`; reply: `{jobs:[envelope…], retry_after_ms}`; one short indexed transaction per job, `FOR UPDATE SKIP LOCKED` |
| `GET /judge/v1/files/:sha256` | fetch a file by content hash | `Content-Length` and the hash are verified by the agent; a mismatch is an infrastructure error |
| `POST /judge/v1/jobs/:id/progress` | one or more events for a leased job; extends the lease | body: `{lease, events:[…]}`; idempotent per event (`seq`) |
| `POST /judge/v1/jobs/:id/complete` | final result or failure; releases the lease | idempotent: a repeat with the same lease is a 200 no-op; a stale lease is 409 |
| `POST /judge/v1/jobs/:id/release` | give the job back unprocessed (drain, policy change) | job returns to `wait`, attempt counter untouched |

The legacy `WorkerController` endpoints and the shared passcode stay for the
legacy path until phase 4.

### 6.3 Envelope

One job = one submission against one dataset. Inside the worker the compile
and run phases are separate, and testcases of one submission may spread
across idle run-lane runners, so today's per-testcase parallelism is kept
without the protocol knowing. The compiled binary stays on the worker's disk.

```json
{
  "protocol": 1,
  "job": {
    "id": 123456, "kind": "grade", "shadow": false, "priority": 0,
    "attempt": 1,
    "lease": {"token": "…", "expires_at": "2026-10-04T09:00:00Z"},
    "cost": {"testcases": 14, "time_limit": 1.0, "estimate_s": 14.0},
    "requires": ["lang:cpp"]
  },
  "server": {"name": "cp-grader", "base_url": "https://grader.nattee.net/grader"},
  "submission": {
    "id": 987654, "language": "cpp",
    "source": {"inline": "…", "filename": "main.cpp"}
  },
  "language": {
    "name": "cpp", "exec_filename": "a.out", "need_cg": false,
    "isolate_options": "", "compile_timeout_s": 10
  },
  "dataset": {
    "id": 5566, "problem_id": 712, "problem_name": "d05_queue",
    "time_limit": 1.0, "memory_limit": 256,
    "evaluation_type": "default", "score_type": "sum",
    "main_filename": null, "initializer_filename": null,
    "files": {
      "checker": {"name": "checker", "sha256": "…", "bytes": 48213, "mode": "0755"},
      "managers": [], "initializers": [], "data_files": []
    },
    "testcases": [
      {"id": 9001, "num": 1, "code_name": "1", "group": 1, "weight": 10,
       "input":  {"sha256": "…", "bytes": 1024},
       "answer": {"sha256": "…", "bytes": 12}}
    ]
  }
}
```

- `requires` is derived by the server: the language, plus `postgres`,
  `net`, `cg` when the dataset or language needs them. The claim only returns
  jobs whose `requires` ⊆ the worker's capabilities.
- `source.inline` is used up to 256 KB, otherwise `source.sha256` and the
  file endpoint. Submission sources are text in the DB today, so inline is
  the normal case.
- `language` carries what the engine reads per language today
  (`Problem#exec_filename`, `JudgeBase#isolate_options_by_lang`,
  `#isolate_need_cg_by_lang`, the compiler's timeout). The agent's engine
  has the per-language compile classes keyed by `language.name`; values in
  the envelope override the engine's constants. This is the hook for
  languages-as-data (§9.4).
- Every file is referenced by `sha256`; the agent fetches only hashes it does
  not already hold.
- Settings (limits, evaluation type, score type) are never cached on the
  worker; they arrive with every job. This removes today's
  `WorkerDataset.delete_all` invalidation entirely.

### 6.4 Lease

- `claim` sets `jobs.status = process`, `judge_worker_id`, `lease_token`,
  `lease_expires_at = now + 120 s`, increments `attempts`.
- Every `progress` and every `heartbeat` that lists the job id extends the
  lease by 120 s.
- A server-side sweep (today's `Job.reclaim_orphaned!`, already a Solid
  Queue recurring task) handles expired leases: attempts < 3 → back to
  `wait`; otherwise `error` with reason, and the submission is set to
  `grader_error` as today. The sweep re-enqueues **through
  `Submission#add_judge_job`**, so the job comes back in whatever shape the
  dial currently selects; this is what makes rollback a config change.
- The `ps`-based watchdog has no equivalent for remote workers; the lease
  replaces it.

### 6.5 Progress events

| `type` | Payload | Server effect |
|---|---|---|
| `claimed` | lane, runner | timeline only |
| `compiled` | `ok`, `compiler_message` (≤ 15,000 chars), `elapsed_ms` | `submissions.status` → `compilation_success` / `compilation_error` + `compiler_message`, exactly today's fields; on failure the job also completes |
| `testcase` | `testcase_id`, `result`, `time_ms`, `memory_kb`, `score`, `result_text` (≤ 250), `isolate_message`, `cpu_ms`, `wall_ms` | `Evaluation` upsert (`find_or_create_by(submission, testcase)` as today) |
| `note` | free text ≤ 1 KB | timeline only (e.g. "cache miss, fetched 14 files, 9.2 MB") |

Events carry a per-job `seq`; the server ignores a `seq` it has seen. Events
may be batched; the agent flushes at most every 500 ms or 20 events.

### 6.6 Complete and failure report

```json
{"lease": "…", "outcome": "done",
 "max_runtime_ms": 812, "peak_memory_kb": 10240}
```

`outcome` ∈ `done` (all testcases reported), `compilation_error`,
`infrastructure_error`. Giving a job back unprocessed is the separate
`release` endpoint (§6.2), never a `complete`. On `done` the server scores
(§7.4). On
`infrastructure_error` the body carries the **failure report**:

```json
{"lease": "…", "outcome": "infrastructure_error",
 "failure": {
   "class": "missing_compiler | disk_full | isolate_failed | fetch_failed |
             hash_mismatch | bad_envelope | agent_exception | timeout",
   "phase": "fetch | compile | run | check",
   "testcase_id": 9003,
   "message": "…", "exception": "Errno::ENOSPC: …",
   "isolate_meta": {"status": "XX", "message": "…"},
   "agent_log_tail": "… last 8 KB of this job's log …",
   "job_dir": "/var/lib/cafe-judge/jobs/cp-grader/123456"
 }}
```

Server effect: job → `error` with the class in `result`; the submission is
re-enqueued (attempt + 1) **excluding this worker** for the next claim; the
worker is **paused for this server** with the failure as reason, visible on
the Judge Workers card, until an admin resumes it or the agent's next
heartbeat reports the condition cleared (disk, compiler). Three attempts →
`grader_error` on the submission, as today.

## 7. Server side

### 7.1 Data model

- `jobs`: new columns `judge_worker_id` (nullable), `lease_token`,
  `lease_expires_at`, `attempts` (default 0), `shadow` (boolean), and the
  new `job_type` value `grade: 4` (`preprocess` stays unused). Index
  `(status, priority DESC, id)` already exists; add `(status, lease_expires_at)`
  for the sweep.
- `judge_workers`: `name` (unique), `token_digest`, `protocol_version`,
  `agent_version`, `capabilities` (json), `runners_total`, `runners_busy`,
  `disk_free_mb`, `last_heartbeat`, `paused` (boolean), `pause_reason`,
  `max_concurrency` (nullable), `allowed_kinds` (string, default all),
  `last_failure` (json), `created_by_id`, `revoked_at`. **Audited** via
  `Auditable` (`audited only: %i[name paused max_concurrency allowed_kinds revoked_at]`).
- `judge_job_events`: `job_id`, `judge_worker_id`, `seq`, `type`, `at`,
  `payload` (json). Trimmed with the job by `Job.clean_old_job`.
- `shadow_gradings`: `submission_id`, `job_id`, `judge_worker_id`, `points`,
  `grader_comment`, `evaluations` (json per testcase), `diff_verdict`
  (`same | benign | mismatch | structural`, from `Replay::ReplayDiff`),
  `created_at`. Kept 90 days.

### 7.2 Routing: the dial

`Submission#add_judge_job(dataset, priority)` consults:

| Key | Type | Meaning |
|---|---|---|
| `judge.pool_share` | integer 0–100 | percentage of submissions enqueued as `grade`; selection is `submission.id % 100 < share`, so it is deterministic and reproducible |
| `judge.pool_languages` | string, optional | comma list; when set, only these languages are eligible for the pool |
| `judge.pool_problems` | string, optional | comma list of problem ids; same |
| `judge.shadow_share` | integer 0–100 | percentage of submissions that **also** get a `shadow` grade job; applies to submissions routed to the legacy path |

A rejudge or dataset re-grade goes through the same method and the same
dial. Setting the share to 0 is the rollback; §6.4's sweep converts any
leased `grade` jobs left behind.

### 7.3 Legacy path exclusion

`Job.take_oldest_waiting_job(grader_process, …)` restricts the legacy caller
to `%w[compile evaluate score]` regardless of the box's `job_type` filter.
Today a blank filter means *every* kind; without this change the old boxes
would claim `grade` jobs and fail them with "no handler".

### 7.4 Scoring on complete

`complete(outcome: done)` runs `Scorer` server-side over the `Evaluation`
rows and calls `Submission#set_grading_complete`, exactly what the legacy
score job does on a box. No queue wait for the score. The legacy path keeps
its score job until phase 4.

### 7.5 Diagnostics on the Graders page

The page keeps its queue card and the errored-job list with Retry All /
Clear All, and gains:

- **Judge Workers card**: one row per `judge_workers` row — name, versions,
  capabilities, runners busy / total on this server, disk, last heartbeat,
  current jobs, last failure, and the controls: pause / resume, max
  concurrency, allowed kinds, token rotate / revoke.
- **Job timeline**: each job links to its events, in order, with worker,
  lane, per-testcase CPU vs wall time, and the failure report when present.
  Infrastructure errors show the class, phase, exception and the agent log
  tail inline, and offer the envelope as a download for `cafe-judge replay`.
- **Shadow card**: counts per `diff_verdict` for the last 7 days and the
  mismatches, each linking to the submission and the shadow result.
- **Legacy boxes card**: today's per-box list, unchanged, until phase 4.

Verdicts (compile error, wrong answer, crash, timeout) never appear on the
error card; only infrastructure errors do.

### 7.6 Policy in the heartbeat reply

```json
{"paused": false, "pause_reason": null, "max_concurrency": 4,
 "allowed_kinds": ["grade"], "lease_seconds": 120, "poll_ms": 200}
```

The agent applies it immediately: a pause stops claims from that server
(running jobs finish); a lower `max_concurrency` stops claims until busy
drops below it; `poll_ms` lets a server slow idle polling fleet-wide.

### 7.7 Token page

Under the Judge Workers card: *New worker* asks for a name, shows the token
**once**, stores a `BCrypt` digest. Rows are created only here; a heartbeat
with an unknown or revoked token is 401 and creates nothing. *Rotate* issues a new token and keeps the
old valid for 10 minutes. *Revoke* sets `revoked_at`; the next request gets
401. All three are audit rows.

## 8. Legacy path during the transition

The legacy boxes and the pool share one `jobs` table and never see each
other's jobs. The agent may run on the same host as legacy boxes using box
ids the legacy watchdog does not manage (cp-worker: 9–16 are free). A server
without the judge API is simply absent from every agent's config and is
served by its own boxes as today. Phase 4 retires: `Grader` main loop and
watchdog, the cron entry, `worker_datasets`, `WorkerController`, the shared
passcode, and `GraderProcess` (kept read-only for one release for history).

## 9. Agent

Plain Ruby, no Rails. Lives in this repo under `judge_agent/` with its own
`Gemfile` (net/http, json, logger; no ActiveRecord) and shares the engine
library (§9.1). Same release tag as the web app; the protocol version is a
constant checked in the handshake.

### 9.1 Engine library (phase 0)

`lib/cafe_judge/` becomes a plain-Ruby library over the envelope: `Envelope`
(typed reader), `Compiler::*` (today's per-language classes, minus
ActiveRecord), `Evaluator`, `Checker`, `IsolateRunner`, `LanguageProfile`
(today's constants from `Problem#exec_filename`,
`JudgeBase#isolate_options_by_lang`, `#isolate_need_cg_by_lang`, overridable
by envelope values), and a `ResultSink` interface (`compiled`, `testcase`,
`done`, `failed`). `app/engine/*` becomes adapters: `EnvelopeBuilder` (AR →
envelope), `ActiveRecordSink` (today's writes), and the legacy `Grader` loop
calls the library. `Scorer` stays in the Rails app (it is DB arithmetic).
`engine:smoke` and `Replay::*` prove equivalence at every slice.

### 9.2 Process model

- **agent** (one per host, systemd `cafe-judge-agent.service`,
  `Restart=always`): threads for one claim loop per server, the heartbeat
  loop, the policy applier, the local scheduler, and the cache janitor.
- **runners**: forked children, one per box, bound to that box id for life,
  JSON-lines over a pipe pair. A runner executes one phase (compile or run of
  one or more testcases) and reports events back; the agent posts them. A
  runner crash is an infrastructure error for its job; the agent restarts
  the runner and cleans the box (`isolate --cleanup`).
- **SIGTERM** = drain: no new claims, finish running jobs (bounded by
  `drain_timeout_s`), release the rest, exit. **SIGHUP** = reload config
  (servers, tokens, weights) without dropping jobs.

### 9.3 Lanes, prefetch, local scheduling

```yaml
worker:
  runners: 8
  compile_lane: {share: 10%, min: 2}   # 8 runners → 2 compile, 6 run
  reserve_cores: 1
```

- The agent claims when it has an idle run-lane runner **or** when the
  compile lane is idle and the local backlog is below the **prefetch bound**
  (2 × compile-lane size). The bound keeps a host from holding leased jobs
  another host could run.
- A compile-lane runner compiles immediately and posts `compiled`. A compile
  error completes the job there, so students get it after one claim plus
  one compile regardless of the run backlog — today's compile-only boxes,
  without a job type.
- A successful compile queues the job locally for the run lane. The run lane
  takes one submission at a time per runner; when several run runners are
  idle, one submission's testcases spread across them (same binary on local
  disk).
- Local order: server weight (worker config), then job priority, then claim
  time. A `max_concurrency` from a server's policy caps how many of its jobs
  are in any lane at once.
- **Small-job reserve** is the compile lane itself: jobs with
  `cost.estimate_s` below `small_job_s` (default 3 s) may run in the compile
  lane when the run lane is full, at lower priority than any pending
  compile, so trivial submissions never queue behind long ones and compiles
  never queue behind small runs.

### 9.4 Language handling

Phase 0 keeps the per-language compile classes in the library, keyed by
`language.name`, with `LanguageProfile` holding the constants the envelope
can override. Moving the constants into `languages` table columns and
building the envelope from them is the backlog item (issue #42), listed as
an optional slice in phase 1 (§12); the protocol does not change when it
lands.

### 9.5 Cache and job directories

```
/var/lib/cafe-judge/
  cache/sha256/ab/abcd…        # content-addressed files, immutable
  jobs/<server>/<job_id>/      # envelope.json, source/, bin/, tc/<n>/{meta,stdout,stderr}, agent.log
  init/<sha256-of-inputs>/     # PostgreSQL initializer workspaces (JudgeBase#run_initializer today)
```

- A job directory is built from the cache with hard links, so a dataset's
  files exist once per host regardless of how many jobs use them.
- The initializer workspace is keyed on the hash of all its inputs
  (initializer files + testcase files), so it is rebuilt exactly when any
  input changes.
- Janitor: job dirs older than 24 h removed; cache trimmed LRU above
  `cache_max_gb` (default 20); disk below `low_disk_mb` (2,048, as
  `GraderProcess::LOW_DISK_MB`) pauses claims and is reported in the heartbeat.

### 9.6 Capabilities and admission

At start the agent detects: `lang:<name>` for every compiler path in config
that exists, `cg` if `isolate --cg --init` succeeds, `postgres` if
`postgres:` is configured, `net` if `allow_share_net: true`, `mem:<MB>` from
the host. It refuses to start with `runners > cores − reserve_cores`, and
pauses claims while the 1-minute load average exceeds `cores × 1.5` or disk
is low. `wall_slack_s` (default 0.5, today's constant in `IsolateRunner`) is
a config value so a VM with steal time can be given more slack without a
code change.

### 9.7 Config file

`/etc/cafe-judge/agent.yml` (root-readable; `agent.yml.SAMPLE` tracked, per
the uppercase-SAMPLE convention):

```yaml
worker:
  name: cp-worker-1
  runners: 8
  compile_lane: {share: 10%, min: 2}
  reserve_cores: 1
  judge_dir: /var/lib/cafe-judge
  isolate: /usr/local/bin/isolate
  wall_slack_s: 0.5
  small_job_s: 3
  cache_max_gb: 20
  compilers: {cpp: /usr/bin/g++, c: /usr/bin/gcc, python: /usr/bin/python3, java: /usr/bin/javac, …}
  # postgres: {host: 127.0.0.1, port: 5432, …}
  # allow_share_net: false
servers:
  - {name: cp-grader, url: https://grader.nattee.net/grader, token: "…", weight: 3}
  - {name: cedt,      url: http://10.0.5.80,                 token: "…", weight: 1}
```

Adding a server is one line; rotating a token is one value; both take
effect on SIGHUP.

### 9.8 Logs and CLI

- `log/agent.log`, rotated by size (10 × 50 MB); one `agent.log` per job
  directory, kept with it for 24 h. No single ever-growing judge log.
- `bin/cafe-judge`: `check` (config + capabilities, exit non-zero if the
  host cannot start), `status` (servers, runners, current jobs, last error
  per server), `job <server> <id>` (that job's log and artifacts), `replay
  <envelope.json>` (run a downloaded envelope locally with a null sink, the
  reproduction tool for failure reports), `drain`.

### 9.9 Failure classification

| Condition | Class | Who is at fault |
|---|---|---|
| compiler binary missing, `isolate` missing, `--cg` unsupported | `missing_compiler` / `isolate_failed` | worker; pause for all servers |
| `ENOSPC`, disk below threshold | `disk_full` | worker; pause for all servers |
| fetch 4xx/5xx after 3 tries, hash mismatch | `fetch_failed` / `hash_mismatch` | server or network; pause for that server only |
| envelope fails schema validation | `bad_envelope` | server; pause for that server only |
| isolate returns `XX` | `isolate_failed` | worker; re-enqueue elsewhere |
| uncaught exception in a runner or the agent's job handling | `agent_exception` | worker; re-enqueue elsewhere |
| compile error, RE, SG, TO, wrong answer, partial | **verdict** | submission; never an error |

### 9.10 Deployment

The automation repo gains a host role `worker`: checkout, `bundle install`
in `judge_agent/`, `cafe-judge check`, `systemctl restart
cafe-judge-agent`, then `cafe-judge replay` of a bundled sample envelope as
the smoke step (replaces `engine:smoke` on worker-only hosts). The per-host
`agent.yml` is created from `.SAMPLE` once and never overwritten.

## 10. Security

- One bearer token per worker × server pair, issued on the server, stored as
  a digest, shown once, revocable, audited. Scope: the judge API only. It is
  a grade-altering secret and is handled like the DB password.
- HTTPS wherever a server has it (grader.nattee.net via the proxy); plain
  HTTP only inside 10.0.5/24. The toi box on 10.24.0.0 must use HTTPS.
- The agent fetches files only from the issuing server's `base_url`, verifies
  `sha256` and size, and caps output files at 50 MB (today's `-f 50000`).
- The server validates every progress / complete against the job's lease
  token and worker id; a stale lease is 409 and logged.
- Per-worker claim rate limit (default 20/s) protects Passenger from a
  misconfigured agent.
- Student code runs in isolate exactly as today; per-server separation on
  the worker is by directory, and runners of different servers share the
  host, as today's boxes share it.

## 11. Testing

| Layer | Proves | Tool | Where |
|---|---|---|---|
| Contract | state machine of claim / progress / complete / release, lease expiry and sweep, idempotency, 426 on version, 401/409 paths | rswag spec → `swagger/judge/v1.yaml`, part of `bin/rails check`; the agent's suite runs against a stub server (small Rack app in `judge_agent/test/`) built from the same YAML | CI |
| Engine equivalence | library grades exactly as the in-process engine | `engine:smoke` and `Replay::ReplaySampler` + `ReplayDiff` run through both adapters; only T→P and x→P are benign | local, prod copy |
| Agent unit | lanes, prefetch bound, scheduler order, cache, failure classification, config reload, drain | minitest in `judge_agent/test/`, isolate stubbed | CI |
| Stress | the ceiling and what breaks first | `judge:stress` rake task enqueues sampled past submissions as `grade` jobs at low priority; collect claim latency and throughput from `judge_job_events`, Passenger queue depth, MySQL load, and the CPU/wall ratio of every run | staging: grader-cp-backup 10.0.5.55 with a prod DB copy + a fresh worker VM |
| Shadow | real traffic, zero student impact | `judge.shadow_share` on cp-grader through at least one quiz; mismatches reviewed on the shadow card | production |
| Canary | real students, limited blast radius | `judge.pool_share` 10 → 50 → 100 on one server, a week each, legacy boxes still enabled | production |
| Soak | nothing missed | legacy boxes disabled, not deleted, for a term | production |

Stress targets from §3: sustain 60 submissions/min and burst 80/min for 10
minutes with claim latency flat; then raise until something gives, and
record what.

## 12. Phases and slices

Everything lands on `master` in releasable slices (dae, 2026-10-04): each
slice keeps `bin/rails check` and `engine:smoke` green and is either inert
behind the dial or verified by the replay diff. No feature bookmark; an
unfinished slice stays in a local bookmark or the clone workspace, never
pushed. Sizes are sessions of a few hours. Each phase gets its own
implementation plan under `docs/superpowers/plans/` and its own ledger; the
next phase's plan is written when the previous phase ships.

**Freeze windows:** no phase-0 slice deploys within 7 days before a quiz or
final; `judge.pool_share` and `judge.shadow_share` change only while no
contest is active on that server and never on an exam day.

| Phase / slice | Content | Size |
|---|---|---|
| **0 — engine extraction** (standalone value: cleaner engine, groundwork for issue #42) | | 2–3 weeks |
| 0.1 | `lib/cafe_judge/envelope.rb` + `EnvelopeBuilder` (AR → envelope) + JSON schema + builder tests | 1 |
| 0.2 | `Compiler::*` on the envelope; `ActiveRecordSink`; legacy `process_job_compile` through the library | 1–2 |
| 0.3 | `Evaluator` + `Checker` + `IsolateRunner` on the envelope; legacy evaluate through the library | 2 |
| 0.4 | `LanguageProfile` registry replacing the scattered constants | 1 |
| 0.5 | `engine:smoke` and `Replay::*` through the library; replay diff on 100 sampled submissions per language on the prod copy, recorded in the ledger | 1 |
| **1 — server side** (standalone value: timeline + error card for legacy boxes too; tokens replace the passcode) | | 3–4 weeks |
| 1.1 | `judge_workers` table, model, token page, audit | 1 |
| 1.2 | `jobs` columns, `grade` kind, legacy exclusion (§7.3), dial keys, routing in `add_judge_job`, sweep via `add_judge_job` | 1–2 |
| 1.3 | judge API: heartbeat + policy, claim with capabilities and `max`, files by hash | 2 |
| 1.4 | progress + complete + failure report; server-side scoring; `judge_job_events`, also written by the legacy `take_oldest_waiting_job` / `Job#report` (`claimed`, `completed`), so the timeline covers legacy boxes from this slice on | 2 |
| 1.5 | Graders page: Judge Workers card, job timeline, failure detail, envelope download | 2 |
| 1.6 | shadow mode: `shadow_gradings`, diff, shadow card | 1 |
| 1.7 | rswag spec + `swagger/judge/v1.yaml` + `/api-docs` entry + `doc/Judge-Worker-Pool.md` | 1 |
| 1.8 (optional, issue #42) | `languages` columns for the profile values; builder reads them | 1–2 |
| **2 — agent** | | 4–6 weeks |
| 2.1 | skeleton, config, capabilities detection, `cafe-judge check` | 1 |
| 2.2 | HTTP client, claim loops, heartbeat + policy applier, version handshake | 1–2 |
| 2.3 | runners (fork), box lifecycle, pipe protocol, crash recovery | 2 |
| 2.4 | cache by hash, job directories, initializer workspace, janitor | 1–2 |
| 2.5 | lanes, prefetch bound, local scheduler, small-job reserve | 1–2 |
| 2.6 | failure classification, per-job logs, `status` / `job` / `replay` CLI | 1–2 |
| 2.7 | systemd unit, drain/reload, deploy role in the automation repo | 1 |
| 2.8 | stub server + contract tests; agent unit tests | 2 |
| 2.9 | `judge:stress` task; staging run on .55 + worker VM; results in the ledger | 2 |
| **3 — shadow** on cp-grader through one quiz | calendar-bound | — |
| **4 — canary, cutover, soak, retire** | dial 10 → 50 → 100 per server; legacy disabled a term; then remove `Grader` loop/watchdog/cron, `worker_datasets`, `WorkerController`, passcode; `GraderProcess` read-only one release, then dropped | 1–2 for the retire slices |

**Rollback at any point:** dial to 0 (sweep converts leased `grade` jobs),
pause the worker on the server's page, or stop the agent service (leases
expire within 2 minutes and the sweep converts).

## 13. Documentation to keep current

- `doc/Judge-Worker-Pool.md` (new, phase 1.7): operator reference — protocol
  summary, config file, page controls, failure classes, runbook.
- `CHANGELOG.md`: user- and operator-facing slices (token page, dial keys,
  page cards, the agent) in the commit that lands them.
- `doc/backlog.md`: issue #42 entry points here; the deferred items in §14
  get entries when they are deferred.
- `CLAUDE.md` Background Processing section: one paragraph once phase 2
  ships.

## 14. Deferred, with the condition to reopen

| Item | Reopen when |
|---|---|
| Central broker (approach C) with a fleet dashboard | the server × worker config matrix or cross-server priority becomes a recurring operator chore |
| Server → worker wake-up nudge | measured idle polling load on Passenger matters; `poll_ms` in the policy is the first lever |
| isolate box reuse across testcases of one submission (init once, run many) | profiling shows isolate init/cleanup dominates short testcases |
| Proportional wall slack (e.g. `max(2×, +1 s)`) | false timeouts appear on a worker that cannot be given dedicated cores |
| Storing testcase outputs for the timeline | a diagnosis needs them; `evaluations.output` exists unused |

## 15. Decision log

- **2026-10-03** — Approach B over A and C (dae). B's envelope and lease are
  designed so C is a drop-in.
- **2026-10-03** — Wire unit is one submission; per-testcase parallelism is
  internal to the host. Reason: no binary round trip, no fan-in on the
  wire, lanes recover the compile-first behaviour.
- **2026-10-03** — Scoring moves server-side. Reason: DB arithmetic, no
  sandbox; removes the score job's queue wait.
- **2026-10-03** — Root cause of the 2024–25 "more boxes = slower" memory is
  the missing `jobs.status` index, fixed 2026-09-08; B makes it structurally
  impossible to regress (pollers = hosts, batch claim, one indexed statement).
- **2026-10-04** — Lanes (compile share + minimum) replace the per-box
  job-type filter; capabilities replace manual routing; pause / concurrency /
  kinds live on the server's page, trust and host facts in the worker file.
- **2026-10-04** — Failure report and event timeline are protocol objects;
  infrastructure errors pause the worker and re-enqueue elsewhere; verdicts
  never reach the error card.
- **2026-10-04** — All work on `master` in releasable slices, no feature
  bookmark; freeze windows around exams; phases ordered so each has
  standalone value if the project pauses.
