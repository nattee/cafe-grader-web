import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ["userForm", "userFormUserID", "command" ]

  connect() {
    console.log('stimulus group',this.element)
  }

  toggle_user_enable(event) {
    const form = this.userFormTarget
    const input = this.userFormUserIDTarget
    input.value = event.target.dataset.userId
    form.requestSubmit()
  }

  post_user_action(event) {
    const form = this.userFormTarget
    const user_id = this.userFormUserIDTarget
    const command = this.userCommandTarget
    command.value = event.target.dataset.command
    user_id.value = event.target.dataset.userId
    form.requestSubmit()

  }

  set_command(event) {
    console.log('asdf')
    const command = this.commandTarget
    command.value = event.target.dataset.value
  }

}
