import { Controller } from "@hotwired/stimulus";
import { configs } from "controllers/datatables/configs"

export default class extends Controller {
  static values = { 
    configName: String,
    ajaxUrl: String,

  }

  // Use a static property to hold the array of table instances
  static tables = [];

  connect() {
    //get the config using stimulus value
    const config = configs[this.configNameValue] || configs.default

    // array of tables to be initialized
    let tables;

    // Case 1: Controller attached to the table itself.
    if (this.element.tagName.toLowerCase() === 'table') {
      tables = [this.element];
    } else {
      // Case 2: Controller attached to enclosing elements
      tables = this.element.querySelectorAll('table');
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
    } else {
      console.log("No AJAX URL found, initializing as client-side table.");
    }

    // Initialize DataTable for each table found.
    tables.forEach(table => {
      this.table = $(table).DataTable(finalConfig);
    });
  }

}
