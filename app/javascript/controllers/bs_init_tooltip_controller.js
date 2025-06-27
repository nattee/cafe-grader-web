// this controllers ensures that the tooltip is intialized
// we should attach this controller to the turbo-frame that is replaced by
// turbo action, so that the tooltip created by the new turbo-frame is initialized
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  connect() {
    this.initializeTooltips()
    this.element.addEventListener("turbo:frame-load", this.handleFrameHasLoaded);
    this.element.addEventListener("turbo:frame-render", this.handleFrameHasLoaded);
    this.element.addEventListener("turbo:load", this.handleFrameHasLoaded);
    this.element.addEventListener("turbo:render", this.handleFrameHasLoaded);
    this.element.addEventListener("turbo:visit", this.handleFrameHasLoaded);
  }

  handleFrameHasLoaded = () => {
    console.log("EVENT: turbo:frame-load on:", this.element, this.element.id);
    this.initializeTooltips();
  }


  initializeTooltips() {
    const tooltipTriggerList = this.element.querySelectorAll('[data-bs-toggle="tooltip"]');

    // Create new tooltip instances for the current content
    this.tooltipInstances = Array.from(tooltipTriggerList).map(tooltipTriggerEl => {
      console.log('got',tooltipTriggerEl)
      return new bootstrap.Tooltip(tooltipTriggerEl);
    });
  }


  disconnect() {
  }
}

