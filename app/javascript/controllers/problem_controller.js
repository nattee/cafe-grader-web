import { Controller } from "@hotwired/stimulus"
import { rowFieldToggle } from "../mixins/row_field_toggle";

export default class extends rowFieldToggle(Controller) {
  static targets = ["toggleAvailableForm", "toggleViewTestcaseForm",
                   ]
  connect() {
  }

  toggle(event) {
    event.target.disabled = true
    const recId = event.target.dataset.id
    const field = event.target.dataset.field
    const form = field === 'available'     ? this.toggleAvailableFormTarget :
                 field === 'view_testcase' ? this.toggleViewTestcaseFormTarget :
                 null
    this.submitToggleForm(form,recId)
  }

}
