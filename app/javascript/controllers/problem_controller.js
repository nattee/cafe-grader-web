import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleForm", "toggleFormId", "toggleFormCommand",
                   ]
  connect() {
  }

  updateSwitch(event) {
  }

  toggle(event) {
    event.target.disabled = true
    const form = this.toggleFormTarget
    const command = this.toggleFormCommandTarget
    const problemId = event.target.dataset.id

    //change the form action to specific problemId and post
    command.value = event.target.dataset.field
    form.action = form.action.replace(-123,problemId)
    form.requestSubmit()
  }
}
