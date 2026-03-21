# Verilog + cocotb problems (`evaluation_type: cocotb`)

## Idea

- Problem ZIP **does not** use `*.in` / `*.sol` pairs.
- Put harness files under a **`cocotb/`** directory (or set `cocotb_dir` in `config.yml`).
- The grader runs **`grade.sh`** inside the sandbox with **`STUDENT_V=/mybin/submitted.v`** and a copy at **`/data/student.v`**.
- On the worker, **`/data`** is a **writable copy** of the problem’s dataset `data/` (per submission + testcase) so **`student.v`** never mutates the shared problem files on disk.
- **`grade.sh`** must exit **0** if all tests pass, **non-zero** otherwise. Send pytest/cocotb logs to **stderr** so **stdout** stays clean.
- The wrapper **`run.sh`** prints **`OK`** or **`WRONG`**, then always exits **0** so isolate still runs the **checker** (diff against answer **`OK`**).

## Judge worker (machine)

- Install **cocotb** (and your simulator: **iverilog + vvp**, **verilator**, etc.) on the worker that runs the grader.
- Set **`compiler.cocotb_python`** in **`config/worker.yml`** (or `COCOTB_PYTHON` in the environment) to the **`python3`** that has **`cocotb`** in its environment. The evaluator prepends that binary’s directory to **`PATH`** inside isolate so **`grade.sh`**’s **`python3`** is the right interpreter.
- If you see **`ModuleNotFoundError: No module named 'cocotb'`** in **`judge.log`**, install cocotb for that interpreter (`pip install cocotb`) or point **`cocotb_python`** at a venv that has it.

## `config.yml` (minimal)

```yaml
name: my_prob
full_name: My cocotb problem
cocotb: true
# optional: directory name if not "cocotb"
# cocotb_dir: cocotb
permitted_lang: verilog
```

## ZIP layout

Keep everything **flat under `cocotb/`** (no `tests/` subfolders) so **`grade.sh`** and your **`.py`** sit next to each other; the grader copies the student’s Verilog to **`/data/student.v`** beside those files. Subdirectories still work, but Rails **ActiveStorage** may rewrite filenames that contain **`/`** (slashes become **`-`**), so flat names are simplest.

```text
config.yml
cocotb/
  grade.sh
  xnor_xor_test.py
  # optional: extra .v helpers, Makefile, etc.
```

## Cocotb tests: compare outputs as integers (optional)

On some cocotb/simulator combos, `dut.out.value` may not compare equal to `0`/`1` with `==`. If that happens, use **`int(dut.out.value)`** before comparing.

## `grade.sh` example

```sh
#!/bin/sh
set -e
cd /data
export PYTHONPATH="${PYTHONPATH:-.}"
python3 -u xnor_xor_test.py 1>&2
```

Make it executable before zipping: `chmod +x cocotb/grade.sh`

## Exit codes (failures must be non-zero)

**`grade.sh`** must exit **non-zero** when tests fail so **`run.sh`** prints **`WRONG`** and the checker sees **`WRONG`** on stdout.

- **`cocotb_tools.runner.Runner.test()`** only calls **`sys.exit(1)`** on failures when run **under pytest** (`PYTEST_CURRENT_TEST` is set). If you run **`python3 your_test.py`** with a `__main__` that calls **`runner.test()`** only, the **simulator** often exits **0** even when cocotb tests fail.
- **Fix:** after **`runner.test(...)`**, use **`cocotb_tools.check_results.get_results(results_xml_path)`** and **`sys.exit(1)`** if **`num_failed > 0`**, or run **`python3 -m pytest ...`** so the harness exits non-zero on failure. See `verilog-cocotb/cafe-grader/test_problem/cocotb/xnor_xor_test.py`

## Worker requirements

- `python3`, `pytest`, **cocotb**, **Icarus Verilog** (or your simulator), and paths reachable from the isolate box.
- You may need extra **isolate** mounts for tools/venv (see `judge_base.rb` `isolate_options_by_lang` for `verilog`).

## Isolate logs on the grader host (`judge.log`)

Every **`isolate --run`** writes **stderr** (and **stdout** at DEBUG) to **`cafe_grader/web/log/judge.log`** on the machine running **`Grader.start`** (not in the browser). Cocotb / `grade.sh` output on stderr appears there as lines **`ISOLATE stderr:`**.

- Turn off: **`GRADER_ISOLATE_LOG_IO=0`**
- Truncation limits (optional): **`GRADER_ISOLATE_LOG_STDERR_MAX`**, **`GRADER_ISOLATE_LOG_STDOUT_MAX`** (bytes, default 32768 / 8192)

## Import behaviour

- `ProblemImporter` attaches every file under `cocotb/` as **`data_files`** (paths preserved).
- A **placeholder testcase** is created; **answer** is the single line **`OK`**.
- **`evaluation_type`** is forced to **`cocotb`**.

## Non–cocotb Verilog

Use the normal iverilog/vvp pipeline (default dataset evaluation types and `*.in` / `*.sol` uploads).

## Troubleshooting: harness file missing under `/data` or WRONG with no real run

1. **Worker cache** — the judge skips re-download when **`worker_datasets`** says **ready**. After changing cocotb files, run `bin/rails runner "WorkerDataset.delete_all"` (or delete one dataset’s rows). New imports invalidate this cache when **`read_cocotb_assets`** runs.

2. **ActiveStorage** — filenames with **`/`** may be rewritten (e.g. **`tests/foo.py`** → **`tests-foo.py`**). Prefer **flat** paths under **`cocotb/`**.

## Troubleshooting: `execve("/source/submission.v"): Permission denied` / exit 127

The compile step was running **`iverilog /source/submission.v`** but **`compiler.iverilog`** was unset in `config/worker.yml`, so isolate tried to **execute** the `.v` file as a program. **Fix:** pull current `worker.yml` (includes `iverilog` / `vvp`), or for **cocotb-only** problems the compiler now skips that check (`/bin/true`). Restart the grader after changing config.

## Troubleshooting: `Error download data_file "404 Not Found"`

The worker downloads dataset attachments via **POST** to **`GRADER_WEB_URL`** (see `config/worker.yml` → `hosts.web`) + `/worker/get_attachment/:id`.

1. **Wrong port** — e.g. `http://localhost` (port 80) while Rails is on **3000**. Use `http://127.0.0.1:3000` or set **`GRADER_WEB_URL`**, then restart **Rails and the grader**.
2. **Host Authorization** — if the app only allows `*.utah.cloudlab.us`, requests to **`127.0.0.1`** used to be rejected before the controller (often **403**). This repo allows loopback and excludes `/worker/*` in `config/environments/*.rb`; restart Rails after pulling.
3. **Real 404** — `ActiveStorage::Attachment` id missing (same DB / RAILS_ENV for web and grader). Check `log/development.log` for `[worker#get_attachment]`.
