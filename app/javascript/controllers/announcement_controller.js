import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["togglePublishedForm", "toggleFrontForm",
                   ]
  connect() {
  }

  toggle(event) {
    event.target.disabled = true
    const annId = event.target.dataset.id
    const field = event.target.dataset.field
    console.log(annId)
    if (field == "published") this.submitTogglePublished(annId)
      else if (field == "front") this.submitToggleFront(annId)
  }

  // these functions are not tied to action, it is called by
  // other action
  submitTogglePublished(annId) {
    const form = this.togglePublishedFormTarget
    form.action = form.action.replace(-123,annId)
    form.requestSubmit()
  }

  submitToggleFront(annId) {
    const form = this.toggleFrontFormTarget
    form.action = form.action.replace(-123,annId)
    form.requestSubmit()
  }

}
