import "datatables"
import "vfs-fonts"
import "pdfmake"

function data_tag_unless_null(value,label) {
  return value == null ? "" : `data-${label}="${value}"`

}

// return a render function that render a button, a switch or a link
// with a property of data-row-id  set to *data*
function dt_button_renderer(label,{element_type = 'button',
                                   className = 'btn-primary', 
                                   action = null,
                                   command = null,
                                   confirm = null,
                                   checked_data_field = 'enabled', // for 'switch' type only
                                   href='#',                       // for 'link' type only
                                   method = null,                  // for 'link' type only
                                  } = {}) {
  return function(data,type,row,meta) {
    const dataAction = data_tag_unless_null(action,'action')
    const dataCommand = data_tag_unless_null(command,'command')
    const dataConfirm = data_tag_unless_null(confirm,'form-confirm')
    const dataMethod = data_tag_unless_null(method,'turbo-method') // for link only
    const dataField = data_tag_unless_null(checked_data_field,'field') // for switch only


    if (element_type == 'switch') {
      // as <input type="switch">
      const checked_text = row[checked_data_field] ? "checked" : "";
      return `
        <div class="form-check form-switch">
          <input type="checkbox" class="form-check-input" data-row-id="${data}"
          ${dataAction} ${dataCommand} ${dataConfirm} ${checked_text} ${dataField}>
        </div>
      `
    } else if (element_type == 'button') {
      // as '<button>'
      return `
        <button class="btn ${className}" data-row-id="${data}" 
        ${dataAction} ${dataCommand} ${dataConfirm}>
        ${label}</button>
      `
    } else if (element_type == 'link') {
      // as '<a>'
      return `
        <a href="${href}" class="${className}" data-row-id="${data}" 
        ${dataAction} ${dataCommand} ${dataConfirm} ${dataMethod}>
        ${label}</a>
      `
    }
  }
}

// render a normal link
function dt_link_renderer(label,{className = '', path = '#', replace_pattern = '-123', replace_field = 'id', confirm=null, turbo=false, method=null} = {}) {
  return function(data,type,row,meta) {
    const dataMethod = data_tag_unless_null(method,'turbo-method')
    let href = path
    if (method) turbo = true
    if (replace_field && replace_pattern) {
      href = path.replace(replace_pattern,row[replace_field])
    }
    const dataConfirm = data_tag_unless_null(confirm,'turbo-confirm')
    let link_text = (label === null) ? data : label
    return `<a href="${href}" class="${className}" ${dataConfirm} ${dataMethod} data-turbo="${turbo}"> ${link_text}</a>`
  }
}

function dt_yes_no_pill_renderer() {
  return function(data,type,row,meta) {
    if (data == '1' || data == 'true' || data == 1 || data == true)
      return '<span class="badge text-bg-success">Yes</span>'
    else if (data == '0' || data == 'false' || data == 0 || data == false)
      return '<span class="badge text-bg-danger">No</span>'
    return ''
  }
}

function dt_datetime_renderer(format = "Y-MM-DD HH:mm") {
  return function(data,type,row,meta) {
    return moment(data).format(`${format}`)
  }
}

const dt = {
  render: {
    button: dt_button_renderer,
    link: dt_link_renderer,
    yes_no_pill: dt_yes_no_pill_renderer,
    datetime: dt_datetime_renderer,
  }
}

export { dt }
