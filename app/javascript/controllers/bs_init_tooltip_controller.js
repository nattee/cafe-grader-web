// this controllers ensures that the tooltip is intialized
// we should attach this controller to the turbo-frame that is replaced by
// turbo action, so that the tooltip created by the new turbo-frame is initialized
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  connect() {
    this.initializeTooltips()
  }

  handleFrameHasLoaded = () => {
    this.initializeTooltips();
  }


  initializeTooltips() {
    const tooltipTriggerList = this.element.querySelectorAll('[data-bs-toggle="tooltip"]');

    // Create new tooltip instances for the current content
    this.tooltipInstances = Array.from(tooltipTriggerList).map(tooltipTriggerEl => {
      return new bootstrap.Tooltip(tooltipTriggerEl);
    });
  }


  disconnect() {
  }
}

