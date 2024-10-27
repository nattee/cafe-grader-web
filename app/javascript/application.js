// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
//import "@hotwired/turbo-rails"
import "controllers"
//


//bootstrap
//import "bootstrap"
//window.bootstrap = bootstrap

// my datatables
import "my_datatable"

import "select2"
import "chart"


// TempusDominus
// -- normal --
import "tempus-dominus-js" //this import as tempusDominus
// -- esm --
//import * as tempusDominus from  "tempus-dominus-esm"
// since any of the above import does not set the window directly, I have to do it
window.tempusDominus = tempusDominus

//too lazy to use the tempusDominus namespace, just use TempusDominus directly
window.TempusDominus = tempusDominus.TempusDominus



//my own customization
//import 'custom'

//import turbo but disable it by default
import { Turbo } from "@hotwired/turbo-rails"
Turbo.session.drive = false

//trigger import map ready (no longer used)
//window.importmapScriptsLoaded = true
//const import_map_loaded = new CustomEvent('import-map-loaded', { });
//document.dispatchEvent(import_map_loaded);
