import "datatables"
import "vfs-fonts"
import "pdfmake"

// render a button
function dt_button_renderer(label,{className = 'btn-primary', action = null, command = null, element_type = 'button', checked_data_field = 'enabled'} = {}) {
  return function(data,type,row,meta) {
    const dataAction = action == null ? "" : `data-action="${action}"`;
    const dataCommand = command == null ? "" : `data-command="${command}"`;
    window.xxx = row
    const checked_text = row[checked_data_field] ? "checked" : "";
    if (element_type == 'button') {
      return `
        <button class="btn ${className}" data-row-id="${data}" ${dataAction} ${dataCommand}>
        ${label}</button>
      `
    } else if (element_type == 'switch') {
      return `
        <div class="form-check form-switch">
        <input type="checkbox" class="form-check-input" data-row-id="${data}" ${checked_text} ${dataAction} ${dataCommand}>
        </div>
      `
    }
  }
}

window.dt_button_renderer = dt_button_renderer
