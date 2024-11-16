import { Controller } from "@hotwired/stimulus"
import { rowFieldToggle } from "../mixins/row_field_toggle";

export default class extends rowFieldToggle(Controller) {
  static targets = ["toggleAvailableForm", "toggleViewTestcaseForm",
                    "problemDate","datasetSelect",
                    "datasetSettings","datasetTestcases","datasetFiles",
                   ]
  connect() {
    this.initProblemForm()
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

  //init the problem form
  initProblemForm() {
    let td_options = structuredClone(cafe.config.td.date)
    td_options['localization']['format'] = 'dd/MM/yyyy'
    //td_options['defaultDate'] = $('#problem_date_added').val()
    new TempusDominus(document.getElementById('problem_date_added'), td_options );
    cafe.initSelect2()
  }

  refreshDataset(event) {
    console.log('change...')
    this.datasetSettingsTarget.src = '#{settings_dataset_path(-123)}'.replace(-123,this.datasetSelectTarget.value)
    //this.datasetTestcasesTarget.src = '#{testcases_dataset_path(-123)}'.replace(-123,this.datasetSelectTarget.value)
    //this.datasetFilesTarget.src = '#{files_dataset_path(-123)}'.replace(-123,this.datasetSelectTarget.value)

    //this.datasetSettingsTarget.reload()
    //this.datasetTesstcasesTarget.reload()
    //this.datasetFilesTarget.reload()
  }

}
