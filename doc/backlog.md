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
- **Shared offcanvas helper.** When a second view gets a help drawer,
  extract `app/views/shared/_help_drawer.html.haml` taking `id:`, `title:`,
  `body_partial:` locals so we don't copy-paste the offcanvas chrome. One
  drawer doesn't justify the partial yet; two do.
- **Edit-drawer content density.** `problems/_edit_help.html.haml` content
  is still text-heavy. The point of the drawer was to relieve a dense
  page; the help inside shouldn't reproduce that density. Consider tabs
  inside the drawer (Basics / Datasets / Viva / Tags) or a numbered
  walkthrough rather than field-by-field reference. Defer until we have
  a second drawer to compare against.

**Out of scope.** `app/views/main/help.html.haml` is a full-page
student-facing help with i18n — different concern, not covered by the
admin help-pattern split.

---

## AuditLog destroy test

**Why.** The "Auditable must exist" bug (fixed 2026-05-17 by making
`belongs_to :auditable` optional) wasn't caught because there's no test
for the destroy path on any audited model. There's only an integration
test for the controller (`test/integration/audit_logs_controller_test.rb`),
not a model-level test that confirms an audit row is created on destroy.

**Proposed direction.** Add a model test like:
```ruby
test "destroying an audited record writes a destroy audit row" do
  c = contests(:something)
  assert_difference -> { AuditLog.for(c).where(action: 'destroy').count }, 1 do
    c.destroy!
  end
end
```
Cover at least one audited model per shape (own-row destroy + cascade via
`dependent: :destroy`).

**Size.** Small. ~30 min.

---

## System-test suite — RESOLVED 2026-06-15

**RESOLVED.** `bin/rails test:system` is now green — **46 tests, 0 failures, 0 errors, 1 skip** (was 20 failing on 2026-05-21). All six clusters fixed, plus a flaky `tags_test#test_update_tag` (a plain `fill_in` intermittently appended to the pre-filled name → fixed with `fill_options: {clear: :backspace}`). The **1 remaining skip** is `ProblemsManageTest#test_set_permitted_languages` — the `lang_ids` multi-select select2 doesn't register the picked option at submit under Selenium (the *identical* helper works for tags/groups; root cause unknown); the logic is covered by the `do_manage set_languages` controller test. (`UsersTest#test_login_then_change_password` was briefly skipped too, but that was premature — it's a normal in-form submit; the flakiness was the `Updated successfully` assert timing out under load → hardened with `wait: 10`, 2026-06-16.) The per-cluster history below is kept as a record. Most are tests that fell behind UI / model changes, NOT broken production behavior — but they need triaging case by case because some may have caught real regressions. None are caused by the 4.3.3 release work itself; they existed before and were noticed only after we wrote a new system test that ran cleanly through `bin/rails test:system`.

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

`test_set_permitted_languages`: chased 2026-06-14, **not a production bug.** A new
controller-level test
(`ProblemsControllerTest#"do_manage set_languages persists permitted_lang"`) POSTs
the bulk action directly (no select2) and passes — the `set_languages` logic is
correct. The system test's select2 interaction on `lang_ids` just fails to
register the chosen option at submit (tags/groups drive the identical helper
fine; root cause unknown), so it is **skipped with a reason** and covered by the
integration test instead.

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

**`bin/rails test` (non-system) is clean** — only one pre-existing failure remains there (`ReportControllerTest#test_admin_can_access_cheat_report`, MySQL collation issue, separate concern).

---

## CSRF meta null-safety in DataTable inits

**Why.** Several DataTable AJAX configs read the CSRF token with the *unguarded*
`document.querySelector('meta[name="csrf-token"]').getAttribute('content')`, which
throws when the meta tag is absent — aborting the whole `DataTable()` init (empty
table). The meta is always present in production (no user impact), but it's absent
when forgery protection is off (test env), which is how Cluster 6 surfaced it.
`user_admin/index.html.haml` was fixed with `?.`; the same unguarded lookup remains in:
- `app/views/groups/show.html.haml` (×2)
- `app/views/languages/index.html.haml`
- `app/views/tags/index.html.haml`
- `app/views/layouts/_header.html.haml`

**Proposed direction.** Add `?.` to each (or switch to the null-safe jQuery
`$('meta[name="csrf-token"]').attr('content')` pattern the problems page already uses).

**Size.** Trivial — one character each. Low priority (no production impact), but
prevents the same latent DataTable-init breakage in those pages' tests.
