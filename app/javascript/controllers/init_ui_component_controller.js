// this controllers ensures that the tooltip is intialized
// we should attach this controller to the turbo-frame that is replaced by
// turbo action, so that the tooltip created by the new turbo-frame is initialized
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  connect() {
    this.handleFrameHasLoaded()
  }

  handleFrameHasLoaded = () => {
    this.initializeTooltips();
    this.initializeSelect2();
    this.initializeTempusDominus();
  }


  initializeTooltips() {
    const tooltipTriggerList = this.element.querySelectorAll('[data-bs-toggle="tooltip"]');

    // Create new tooltip instances for the current content
    this.tooltipInstances = Array.from(tooltipTriggerList).map(tooltipTriggerEl => {
      return new bootstrap.Tooltip(tooltipTriggerEl);
    });
  }

  initializeSelect2() {
    $(".select2").select2({
      theme: "bootstrap-5",
    });
  }

  initializeTempusDominus() {
    const tdTriggerList = this.element.querySelectorAll('.tempus-dominus')

    // Create new tempus dominus instances for the current content
    this.tdInstances = Array.from(tdTriggerList).map(tdTriggerEl => {
      // set the option to the template given by data-td-template
      let options = {}
      const templateName = tdTriggerEl.dataset.tdTemplate
      if (templateName) {
        options = structuredClone(cafe.config.td[templateName])
      } else {
        // default to date
        options = structuredClone(cafe.config.td.date)
      }
      return new TempusDominus(tdTriggerEl, options)
    });
  }

  disconnect() {
  }
}

