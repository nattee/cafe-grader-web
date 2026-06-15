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

## System-test suite has 9 stale failures

**Why.** `bin/rails test:system` reports **8 failures + 1 error (+2 skips)** out of 46 tests (2026-06-15, after Clusters 2, 5 & 6 fixed; was 14 failing on 2026-06-14, 20 on 2026-05-21). Remaining failures are Clusters 1, 3, 4. Most are tests that fell behind UI / model changes, NOT broken production behavior — but they need triaging case by case because some may have caught real regressions. None are caused by the 4.3.3 release work itself; they existed before and were noticed only after we wrote a new system test that ran cleanly through `bin/rails test:system`.

**Six root-cause clusters (not 20 independent bugs).** Tackle one cluster per session.

### Cluster 1 — Name-validation tightened, tests use spaces (~15 min)
Tests use names like `"Updated Group"`, `"GroupA"`, `"easybeginner"` that contain characters the new validation rejects:
> "Name contains invalid characters. Only letters, numbers, `( ) [ ] - _` are allowed."

Failing (`tags_test#test_update_tag` was here on 2026-05-21 but now passes):
- `test/system/groups_test.rb#test_create_new_group`, `#test_update_group`
- `test/system/contests_test.rb#test_create_new_contest`, `#test_update_contest`

**Decision needed:** is the regex (no spaces) the desired behavior, or did it get tightened by accident? Either relax the validation OR update the test names. Probably the former — spaces in user-facing names are normal.

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

### Cluster 3 — Problem available-toggle UI flow drift (~30-60 min)
The available/view_testcase toggle clicks succeed but the test's read-back doesn't show the new value.

Failing:
- `ProblemsManageTest#test_set_available_to_yes` / `#test_set_available_to_no`
- `ProblemsManageTest#test_select_all_then_apply_action`
- `ProblemsManageTest#test_apply_action_to_multiple_individually_selected_problems`

**Verify manually first:** does the toggle actually work in the browser? If yes, the test's wait/assertion needs an update (probably needs to wait for the turbo_stream update). If no, real regression — likely from our recent Pass B `link_to → button_to` migration or related polish.

### Cluster 4 — date_added handling regression (~30 min)
`ProblemsManageTest#test_change_date_added` raises `NoMethodError: undefined method 'to_date' for nil` at line 53. The test reads back the date_added; somewhere it's nil where it shouldn't be.

**Verify manually first**, same as cluster 3 — could be feature-broken or test-out-of-date.

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
- **Edit / profile form submits are flaky under Selenium** (the redesigned simple_form
  submit doesn't reliably fire; the user-edit page's prominent "Save Changes" button
  also sits *outside* the form via an HTML5 `form=` association). The logic —
  `user_admin#update` (alias/remark) and `update_self` (password) — is now covered by
  reliable controller tests in `UsersControllerTest`; the system tests verify
  create+list and skip/trim the flaky submit. Whether the dual-submit-button edit
  page is worth simplifying is an open UI question.

### Recommended sequence

1. ~~Clusters 2 & 5~~ done (2026-06-14/15). Cluster 1 next — clearly test-needs-update, low risk (but settle the spaces-in-names decision first).
2. ~~Cluster 5~~ done 2026-06-15.
3. ~~Cluster 6~~ done 2026-06-15.
4. Clusters 3 + 4 — bigger; verify the feature in a browser before touching tests, as these might be real regressions.

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
