import { Controller } from "@hotwired/stimulus"
import { rowFieldToggle } from "mixins/row_field_toggle";

export default class extends rowFieldToggle(Controller) {
  static targets = ["toggleAvailableForm", "toggleViewTestcaseForm",
                    "problemDate","datasetSelect","datasetSelectForm", "activeTab",
                    "datasetSettings","datasetTestcases","datasetFiles","dataset"
                   ]
  connect() {
    if (typeof page_init === "function")
      page_init()
  }

  toggle(event) {
    event.target.disabled = true
    const recId = event.target.dataset.id
    const field = event.target.dataset.field
    const form = field === 'available'     ? this.toggleAvailableFormTarget :
                 field === 'view_testcase' ? this.toggleViewTestcaseFormTarget :
                 null
    this.submitToggleForm(form,recId)
  }

  refreshDataset(event) {
    const dsid = this.datasetSelectTarget.value
    const frame = this.datasetTarget
    frame.src = frame.src.replace(frame.dataset.currentId,dsid)
    frame.dataset.currentId = dsid
  }

  viewDataset(event) {
    const form = this.datasetSelectFormTarget
    const active = this.activeTabTarget
    active.value = $('#dataset .tab-pane.active')[0].id
    form.requestSubmit()
  }

}
