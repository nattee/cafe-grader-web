import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ["usersCommand", "userForm", "userFormUserID", "userFormCommand" ,
                    "problemsCommand", "problemForm", "problemFormProblemID", "problemFormCommand" ,
                   ]

  connect() {
    //console.log('stimulus group',this.element)

    //fetch("/groups/10/show_users_query", {
    //  method: "POST",
    //}).then(r => r.text())
    //  .then(html => console.log(html))
  }

  setUsersCommand(event) {
    const command = this.usersCommandTarget
    command.value = event.target.dataset.value
  }

  postUserAction(event) {
    const form = this.userFormTarget
    const user_id = this.userFormUserIDTarget
    const command = this.userFormCommandTarget
    command.value = event.target.dataset.command
    user_id.value = event.target.dataset.rowId
    form.requestSubmit()
  }

  afterUserAction(event) {
    $("#user_table").DataTable().ajax.reload()
  }

  afterUsersAdd(event) {
    $('#user_ids').val(null).trigger("change");
    $('#user_group_ids').val(null).trigger("change");
    const dt = $("#user_table").DataTable()
    dt.ajax.reload()
  }

  setProblemsCommand(event) {
    const command = this.problemsCommandTarget
    command.value = event.target.dataset.value
  }

  postProblemAction(event) {
    const form = this.problemFormTarget
    const problem_id = this.problemFormProblemIDTarget
    const command = this.problemFormCommandTarget
    command.value = event.target.dataset.command
    problem_id.value = event.target.dataset.rowId
    form.requestSubmit()
  }

  afterProblemAction(event) {
    $("#problem_table").DataTable().ajax.reload()
  }

  afterProblemsAdd(event) {
    $('#problem_ids').val(null).trigger("change");
    $('#problem_group_ids').val(null).trigger("change");
    $("#problem_table").DataTable().ajax.reload()
  }

}
