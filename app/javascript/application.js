// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails



//import jQuery from "jquery"
//window.$ = window.jQuery = jQuery;
import jquery from "jquery"
window.jQuery = jquery
window.$ = jquery

// when pin to "bootstrap.js"
//import * as bootstrap from "bootstrap"
//window.bootstrap = bootstrap

// when pin to "bootstrap.bundle.min.js"
import * as bootstrap from "bootstrap"
window.bootstrap = bootstrap

// import Turbo and Stimulus Controller
// Disable Turbo by default
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"
Turbo.session.drive = false

//import jQuery from "jquery"
//window.$ = window.jQuery = jQuery;

/* 
//bootstrap
//import "bootstrap"
//window.bootstrap = bootstrap

import jQuery from "jquery"
window.$ = window.jQuery = jQuery;

console.log($)
console.log('i am prepend_jquery');

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


// running rails ujs
// this should be phased out??? and replace by turbo / stimulus
import Rails from 'rails-ujs';
Rails.start()


//my own customization
//import 'custom'


//trigger import map ready (no longer used)
//window.importmapScriptsLoaded = true
//const import_map_loaded = new CustomEvent('import-map-loaded', { });
//document.dispatchEvent(import_map_loaded);

//Import cafe-grader global functions into *cafe* object
import * as cafe from 'cafe_bundle'
window.cafe = cafe



// this bootbox is non-minified version and is edited by dae
// since that version does not support importmap, I have to add 'root = root || window'
import 'bootbox'
import "@popperjs/core"
import * as bootstrap from "bootstrap"

*/
