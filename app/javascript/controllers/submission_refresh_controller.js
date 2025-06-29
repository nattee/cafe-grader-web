// after a timeout, click the button
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "refreshLink", "waitingText" ]

  // this is values that is read from data-editor-delay-value
  static values = {
    delay: { type: Number, default: 5000 }, // Default delay is 5000ms (5 secs)
  }

  connect() {
    this.startRefreshTimer();
  }

  // for starting auto refresh latest submission status
  startRefreshTimer() {
    // click the refresh button after 5 secs
    this.remainingSeconds = this.delayValue / 1000
    console.log('start refresh with ' + this.remainingSeconds)
    this.updateWaitingText()
    this.refreshTimer = setInterval(() => {
      this.remainingSeconds--;
      this.updateWaitingText()
      if (this.remainingSeconds <= 0) {
        clearInterval(this.refreshTimer)

        // click the refersh button
        if (this.hasRefreshLinkTarget) {
          console.log('click')
          this.refreshLinkTarget.click();
        }
      }
    }, 1000) // update every second
  }

  // render the waiting text
  updateWaitingText() {
    const text = `Checking score in ${this.remainingSeconds} seconds...`
    console.log(text)
    if (this.hasWaitingTextTarget) {
      this.waitingTextTarget.textContent = text
    }
  }

  disconnect() {
    // Clear the timeout if the controller is ever disconnected from the DOM
    // This prevents memory leaks or unexpected clicks.
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }
}
