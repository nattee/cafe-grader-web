import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ["usersCommand", "userForm", "userFormUserID", "userFormCommand" ,
                    "problemsCommand", "problemForm", "problemFormProblemID", "problemFormCommand" ,
                    "contestForm","contestFormContestID","contestFormCommand",
                   ]

  connect() {
  }

  setUsersCommand(event) {
    const command = this.usersCommandTarget
    command.value = event.target.dataset.value
  }

  postUserAction(event) {
    // event.target is the dom that emits the event
    // the parameter for the action is in data-* of that dom
    // we copy the parameter and set the appropriate input
    // of the form
    const form = this.userFormTarget
    const user_id = this.userFormUserIDTarget
    const command = this.userFormCommandTarget
    command.value = event.target.dataset.command
    user_id.value = event.target.dataset.rowId
    if ('formConfirm' in event.target.dataset) {
      form.dataset.turboConfirm = event.target.dataset.formConfirm
    } else {
      form.removeAttribute('data-turbo-confirm')
    }
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

  //for contest
  postContestAction(event) {
    // event.target is the dom that emits the event
    // the parameter for the action is in data-* of  the dom
    // we copy the parameter and set the appropriate input
    // of the form
    const form = this.contestFormTarget
    const contest_id = this.contestFormContestIDTarget
    const command = this.contestFormCommandTarget
    command.value = event.target.dataset.command
    contest_id.value = event.target.dataset.rowId
    if ('formConfirm' in event.target.dataset) {
      form.dataset.turboConfirm = event.target.dataset.formConfirm
    } else {
      form.removeAttribute('data-turbo-confirm')
    }
    form.requestSubmit()
  }

  afterContestAction(event) {
    $("#contest_table").DataTable().ajax.reload()
  }

}
