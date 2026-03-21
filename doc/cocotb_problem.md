# Verilog + cocotb problems (`evaluation_type: cocotb`)

## Idea

- Problem ZIP **does not** use `*.in` / `*.sol` pairs.
- Put harness files under a **`cocotb/`** directory (or set `cocotb_dir` in `config.yml`).
- The grader runs **`grade.sh`** inside the sandbox with **`STUDENT_V=/mybin/submitted.v`** and a copy at **`/data/student.v`**.
- **`grade.sh`** must exit **0** if all tests pass, **non-zero** otherwise. Send pytest/cocotb logs to **stderr** so **stdout** stays clean.
- The wrapper **`run.sh`** prints **`OK`** or **`WRONG`**, then always exits **0** so isolate still runs the **checker** (diff against answer **`OK`**).

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

```text
config.yml
cocotb/
  grade.sh          # required — see below
  tests/
    xnor_xor_test.py
  # ... reference RTL, Makefiles, etc.
```

## Cocotb tests: compare outputs as integers (optional)

On some cocotb/simulator combos, `dut.out.value` may not compare equal to `0`/`1` with `==`. If that happens, use **`int(dut.out.value)`** before comparing.

## `grade.sh` example

```sh
#!/bin/sh
set -e
export PYTHONPATH="${PYTHONPATH:-.}"
# Student file: $STUDENT_V (also /data/student.v)
python3 -m pytest tests/xnor_xor_test.py -q --tb=no 1>&2
```

Make it executable before zipping: `chmod +x cocotb/grade.sh`

## Worker requirements

- `python3`, `pytest`, **cocotb**, **Icarus Verilog** (or your simulator), and paths reachable from the isolate box.
- You may need extra **isolate** mounts for tools/venv (see `judge_base.rb` `isolate_options_by_lang` for `verilog`).

## Import behaviour

- `ProblemImporter` attaches every file under `cocotb/` as **`data_files`** (paths preserved).
- A **placeholder testcase** is created; **answer** is the single line **`OK`**.
- **`evaluation_type`** is forced to **`cocotb`**.

## Non–cocotb Verilog

Use the normal iverilog/vvp pipeline (default dataset evaluation types and `*.in` / `*.sol` uploads).

## Troubleshooting: `execve("/source/submission.v"): Permission denied` / exit 127

The compile step was running **`iverilog /source/submission.v`** but **`compiler.iverilog`** was unset in `config/worker.yml`, so isolate tried to **execute** the `.v` file as a program. **Fix:** pull current `worker.yml` (includes `iverilog` / `vvp`), or for **cocotb-only** problems the compiler now skips that check (`/bin/true`). Restart the grader after changing config.

## Troubleshooting: `Error download data_file "404 Not Found"`

The worker downloads dataset attachments via **POST** to **`GRADER_WEB_URL`** (see `config/worker.yml` → `hosts.web`) + `/worker/get_attachment/:id`.

1. **Wrong port** — e.g. `http://localhost` (port 80) while Rails is on **3000**. Use `http://127.0.0.1:3000` or set **`GRADER_WEB_URL`**, then restart **Rails and the grader**.
2. **Host Authorization** — if the app only allows `*.utah.cloudlab.us`, requests to **`127.0.0.1`** used to be rejected before the controller (often **403**). This repo allows loopback and excludes `/worker/*` in `config/environments/*.rb`; restart Rails after pulling.
3. **Real 404** — `ActiveStorage::Attachment` id missing (same DB / RAILS_ENV for web and grader). Check `log/development.log` for `[worker#get_attachment]`.
