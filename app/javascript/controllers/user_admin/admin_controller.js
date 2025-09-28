//import BaseController from './base_controller'
import { Controller } from "@hotwired/stimulus";
import BaseController from "controllers/user_admin/base_controller"

export default class extends BaseController {

  connect(event) {
    //table initializer
    $('#main-table').DataTable({
      processing: true,
      rowId: 'id',
      destroy: true,
      pageLength: 50,
      ajax: {
        url: "/user_admin/admin_query",
        type: 'POST',
        headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'), },
        dataSrc: function(json) {
          return json.data
        }
      },
      layout: {
        topStart: 'info',
        topEnd: 'search',
      },
      columns: [ 
        //login with stat link
        {data: 'login'},
        {data: 'full_name'},
        // clear ip action
        {data: 'id', render: cafe.dt.render.button(`[${cafe.msi('remove_moderator','md-18')} Revoke]`, {element_type: 'link', action: 'user-admin--admin#postUserAction', command: 'revoke', className: 'link-danger'} )},
      ],
      columnDefs: [{orderable: false, targets: [2]} ],
    })
  }

  setGrantCommand(event) {
    const { form, userId, command } = this.userForm

    //set the command and user_id in the form
    command.value = 'grant'
  }

  afterUserAction(event) {
    super.afterUserAction(event)
    $("#user_id").val(null).trigger('change')
  }
}
