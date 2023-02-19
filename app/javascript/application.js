// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
//import "@hotwired/turbo-rails"
//import "controllers"
//


//bootstrap
//import "bootstrap"
//window.bootstrap = bootstrap

//datatable
//import 'datatables-bundle'
import "pdfmake"
import "pdfmake-vfs"
import "jszip"
import "datatables"
import "datatables-bs5"
import "datatables-editor"
import "datatables-editor-bs5"
import "datatables-autofill"
import "datatables-autofill-bs5"
import "datatables-button"
import "datatables-button-bs5"
import "datatables-button-colvis"
import "datatables-button-html5"
import "datatables-button-print"
import "datatables-colrecorder"
import "datatables-datetime"
import "datatables-fixedcolumns"
import "datatables-fixedheader"
import "datatables-keytable"
import "datatables-responsive"
import "datatables-responsive-bs5"
import "datatables-rowgroup"
import "datatables-rowreorder"
import "datatables-scroller"
import "datatables-searchbuilder"
import "datatables-searchbuilder-bs5"
import "datatables-searchpanes"
import "datatables-searchpanes-bs5"
import "datatables-select"
import "datatables-staterestore"
import "datatables-staterestore-bs5"
/* */

import "select2"
import "chart"

//tempus dominus
import { TempusDominus } from "@eonasdan/tempus-dominus"
import * as TD from "@eonasdan/tempus-dominus-esm"
import * as customDateFormat from '@eonasdan/tempus-dominus/customDateFormat'
window.TD = TD
window.TempusDominus = TempusDominus
window.customDateFormat = customDateFormat

//my own customization
import 'custom'

//import turbo but disable it by default
import { Turbo } from "@hotwired/turbo-rails"
Turbo.session.drive = false

//trigger import map ready
console.log('application.js ready')
window.importmapScriptsLoaded = true
const import_map_loaded = new CustomEvent('import-map-loaded', { });
document.dispatchEvent(import_map_loaded);
