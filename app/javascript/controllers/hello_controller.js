import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log('stimulus hello',this.element)
  }

  test(event) {
    console.log('xxxx',this.element)
    console.log(event)
  }
}
