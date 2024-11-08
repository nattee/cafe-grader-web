import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleAvailableForm", "toggleViewTestcaseForm",
                   ]
  connect() {
  }

  updateSwitch(event) {
  }

  // these functions are not tied to action, it is called by
  // other action
  submitToggleAvailable(problemId) {
    const form = this.toggleAvailableFormTarget
    form.action = form.action.replace(-123,problemId)
    form.requestSubmit()
  }

  submitToggleViewTestcase(problemId) {
    const form = this.toggleViewTestcaseFormTarget
    form.action = form.action.replace(-123,problemId)
    form.requestSubmit()
  }


  toggle(event) {
    event.target.disabled = true
    const problemId = event.target.dataset.id
    const field = event.target.dataset.field
    if (field == "available") this.submitToggleAvailable(problemId)
      else if (field == "view_testcase") this.submitToggleViewTestcase(problemId)
  }

}
