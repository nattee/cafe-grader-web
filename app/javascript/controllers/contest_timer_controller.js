import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["counter"]

  connect() {
    if (this.hasCounterTarget) {
      this.update()
      this.timer = setInterval(() => {
        this.update()
      }, 500)
    }
  }

  disconnect() {
    clearInterval(this.timer)
  }


  // This is for update all counters of each contest
  update() {
    const now = new Date()

    this.counterTargets.forEach((element) => {
      const startTime = Date.parse(element.dataset.start)
      const stopTime = Date.parse(element.dataset.stop)

      if (now < startTime) {
        // You need to ensure humanize_time is available in this controller's scope.
        element.textContent = humanize_time(element.dataset.start, 'starts in ', 'started ')
      } else {
        element.textContent = humanize_time(element.dataset.stop, 'ends in ', 'ended ')
      }
    })
  }
}
