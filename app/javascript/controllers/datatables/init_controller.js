import { Controller } from "@hotwired/stimulus";
import { configs } from "controllers/datatables/configs"

export default class extends Controller {
  static values = { 
    configName: String,
    ajaxUrl: String,

  }

  connect() {
    // tables is an array of DataTable object

    this.tables = [];
    //get the config using stimulus value
    const config = configs[this.configNameValue] || configs.default


    let table_elements
    // Case 1: Controller attached to the table itself.
    if (this.element.tagName.toLowerCase() === 'table') {
      table_elements = [this.element];
    } else {
      // Case 2: Controller attached to enclosing elements
      table_elements = this.element.querySelectorAll('table');
    }

    // include ajax url, if any
    let finalConfig = { ...config }
    if (this.hasAjaxUrlValue && typeof config.ajax === 'object') {
      // merge the url to ajax option using Stimulus controller value
      let ajaxOptions = { ...config.ajax };
      ajaxOptions.url = this.ajaxUrlValue;

      // Merge the fully constructed ajax object and other server-side flags
      finalConfig = {
        ...finalConfig,
        ajax: ajaxOptions
      };
    }

    // Initialize DataTable for each table found.
    table_elements.forEach(element => {
      this.tables.push($(element).DataTable(finalConfig));
    });
  }

  // this functions 
  reload(event) {
    //console.log("Received datatable:reload event. Payload:", event.detail)

    this.tables.forEach(table => {
      // 'null, false' reloads data from the server but keeps the user on the current page
      table.ajax.reload(null, false)
    })

  }

}
