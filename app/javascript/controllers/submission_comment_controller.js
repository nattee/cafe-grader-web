// for editing submissions' comment
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "form", "title", "body", "modal" ]

  // this is values that is read from data-editor-delay-value
  static values = {
    createUrl: String,
    delay: { type: Number, default: 5000 }, // Default delay is 5000ms (5 secs)
  }

  connect() {
    this.modal = new bootstrap.Modal(this.modalTarget)
  }

  // populate the form with the data from the clicking element
  populateFormForUpdate(event) {
    const commentData = event.params.comment
    const formUrl = event.params.url

    this.titleTarget.value = commentData.title
    this.bodyTarget.value = commentData.body
    this.formTarget.action = formUrl
    this.formTarget.method = 'patch'
  }

  // when clicking on the "add comment", we set the form action to the 
  // create path set by the value of the controller
  prepareFormForCreate(event) {
    console.log('for create')
    const formUrl = this.createUrlValue
    this.formTarget.action = formUrl
    this.formTarget.method = 'post'
  }

  handleSuccess(event) {
    if (event.detail.success) {
      console.log("Turbo form submission was successful!");
      // Close the Bootstrap modal
      this.modal.hide();
    } else {
      console.log("Turbo form submission failed.");
      // You could potentially handle form redisplays with errors here,
      // though Turbo Frames often handles that automatically.
    }

  }

  disconnect() {
    this.modal.dispose()
  }
}
