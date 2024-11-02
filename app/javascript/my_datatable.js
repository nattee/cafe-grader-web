import "datatables"
import "vfs-fonts"
import "pdfmake"

function data_tag_unless_null(value,label) {
  return value == null ? "" : `data-${label}="${value}"`

}

// render a button or a switch
function dt_button_renderer(label,{className = 'btn-primary', action = null, command = null, element_type = 'button', checked_data_field = 'enabled'} = {}) {
  return function(data,type,row,meta) {
    const dataAction = action == null ? "" : `data-action="${action}"`;
    const dataCommand = command == null ? "" : `data-command="${command}"`;
    const checked_text = row[checked_data_field] ? "checked" : "";
    // type 'button'
    if (element_type == 'button') {
      return `
        <button class="btn ${className}" data-row-id="${data}" ${dataAction} ${dataCommand}>
        ${label}</button>
      `
    // type 'switch'
    } else if (element_type == 'switch') {
      return `
        <div class="form-check form-switch">
        <input type="checkbox" class="form-check-input" data-row-id="${data}" ${checked_text} ${dataAction} ${dataCommand}>
        </div>
      `
    }
  }
}

// render a link
function dt_link_renderer(label,{className = '', action = null, command = null, href = '#', confirm=null} = {}) {
  return function(data,type,row,meta) {
    const dataAction = data_tag_unless_null(action,'action')
    const dataCommand = data_tag_unless_null(command,'command')
    const dataConfirm = data_tag_unless_null(confirm,'form-confirm')
    return `
      <a href="${href}" class="${className}" data-row-id="${data}" ${dataAction} ${dataCommand} ${dataConfirm}>
      ${label}</a>
    `
  }
}

function dt_yes_no_pill_renderer() {
  return function(data,type,row,meta) {
    console.log('xxx')
    console.log(data)
    if (data == '1' || data == 'true' || data == 1 || data == true)
      return '<span class="badge text-bg-success">Yes</span>'
    else if (data == '0' || data == 'false' || data == 0 || data == false)
      return '<span class="badge text-bg-success">No</span>'
    return ''
  }
}

window.dt_button_renderer = dt_button_renderer
window.dt_link_renderer = dt_link_renderer
window.dt_yes_no_pill_renderer = dt_yes_no_pill_renderer
