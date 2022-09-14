//we need jquery to load first, this is enforced by 
// doing
//   <%= javascript_import_module_tag('prepen_jquery') %>
// before
//   <%= javascript_importmap_tags %>
//   (which loads application.js

import jQuery from "jquery"
window.$ = window.jQuery = jQuery;

console.log('i am prepend_jquery');
