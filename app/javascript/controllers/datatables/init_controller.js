import { Controller } from "@hotwired/stimulus";
import { configs } from "controllers/datatables/configs"

/**
 * usage: connect this controller to an enclosing tag that contains a table element
 *   that will be made into a datatable, like the following HAML
 *
 *       .tab-content{ data: {
 *           controller: 'datatables--init',
 *           'datatables--init-config-name-value': 'contestManageUser',
 *           'datatables--init-ajax-url-value': show_users_query_contest_path(@contest),
 *           action: 'datatable:reload@window->datatables--init#reload'
 *
 *  Write a config in /app/javascript/controllers/datatables/configs.js
 *  which may include columns from /app/javascript/controllers/datatables/columns.js
 *
 *  If ajax is needed, we can put the url helper as data-datatables--init-ajax-url-value
 *  since we cannot use url helper inside the javascript
 */
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

  // this functions reload a datatable in this.table that has it's node() id in event.detail.table
  // Canonically, we can trigger this function by connecting it to an action but mostly we connect it
  // with  action: 'datatable:reload@window->datatables--init#reload'
  // and let the `event_dispatcher` turbo_stream fire the datatable:reload event with event_detail parameters
  reload(event) {
    // Get the string of space-separated table names.
    const targetNamesStr = event.detail?.table;

    // If a string of names is provided, split it into an array.
    // Otherwise, targetTables will be null.
    const targetTables = targetNamesStr ? targetNamesStr.split(' ') : null;
    console.log(`targetTables = ${targetTables}`)

    this.tables.forEach(table => {
      // 1. No specific tables were targeted (targetTables is null).
      // 2. This table's id is included in the list of targeted tables.
      if (!targetTables || targetTables.includes(table.table().node().id)) {
        // 'null, false' reloads data from the server but keeps the user on the current page
        table.ajax.reload(null, false)
        console.log(`reloading = ${table.table().node().id}`)
      }
    });
  }

}
