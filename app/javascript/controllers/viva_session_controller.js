import { Controller } from "@hotwired/stimulus"

// Polls the refresh endpoint while a viva turn is processing.
// Data attributes:
//   data-viva-session-pending-value      (Boolean) whether a turn is currently processing
//   data-viva-session-refresh-url-value  (String)  URL that returns the replacement partial
//   data-viva-session-interval-ms-value  (Number)  poll interval in ms
export default class extends Controller {
  static values = {
    pending:    Boolean,
    refreshUrl: String,
    intervalMs: { type: Number, default: 3000 }
  }

  connect() {
    if (this.pendingValue && this.refreshUrlValue) {
      this.scheduleRefresh()
    }
  }

  scheduleRefresh() {
    this.refreshTimer = setTimeout(() => this.fetchRefresh(), this.intervalMsValue)
  }

  async fetchRefresh() {
    try {
      const res = await fetch(this.refreshUrlValue, { headers: { Accept: "text/html" } })
      if (!res.ok) return this.scheduleRefresh()
      const html = await res.text()
      // The refresh partial renders the same #viva-session element, so we replace outerHTML.
      this.element.outerHTML = html
    } catch (e) {
      console.warn("viva refresh failed", e)
      this.scheduleRefresh()
    }
  }

  disconnect() {
    if (this.refreshTimer) clearTimeout(this.refreshTimer)
  }
}
