//main entry point for sprocket
// following lines are very important, it loads several javascript files BEFORE import map
//= require jquery3
//= require popper
//= require bootstrap-sprockets
//= require moment
//= require moment/th
//= require ace-rails-ap
//= require ace/mode-c_cpp
//= require ace/mode-python
//= require ace/mode-ruby
//= require ace/mode-pascal
//= require ace/mode-javascript
//= require ace/mode-java
//= require ace/theme-merbivore

// -- AGAIN -- this javascript is loaded first, before any import_map
// because it is loaded via javascript_include_tag (which is sprocket)

//TODO: should move this one into another .js that is loaded via sprocket

window.jquery = jQuery
function sleep(ms) {
  return (new Promise(resolve => setTimeout(resolve, ms))).then( () => {} );
}
