import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
  }

  test(event) {
    console.log('xxxx',this.element)
    console.log(event)
  }
}
