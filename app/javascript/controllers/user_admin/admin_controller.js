import BaseController from './base_controller'

export default class extends BaseController {

  connect(event) {
    //table initializer
    $('#main-table').DataTable({
      'pageLength': 50,
      columnDefs: [{orderable: false, targets: [3]} ],
    })
  }
}
