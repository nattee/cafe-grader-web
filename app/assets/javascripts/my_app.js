//main entry point for sprocket
//= require jquery3
//= require jquery_ujs
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

// this javascrip is loaded first, before any import map
// because it is loaded via javascript_include_tag (which is sprocket)

//TODO: should move this one into another .js that is loaded via sprocket

function sleep(ms) {
  return (new Promise(resolve => setTimeout(resolve, ms))).then( () => {} );
}
