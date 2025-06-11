# Pin npm packages by running ./bin/importmap

#entry point
pin "application"
pin "prepend_jquery"
#pin "my_sprocket"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/mixins", under: "mixins"

#we don't really need jquery in importmap because we use sprocket version
#but... bootbox tries to import jquery, so... we have to pin it here
# pin "jquery", to: 'my_jquery.js', preload: true
# this is pinned but not import by other


#pin "bootstrap", to: "bootstrap.bundle.min.js", preload: true
#no need popper, because bundled already in bootstrap
#pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.6/lib/index.js"

# datatable
# I have to fix vfs_font.js for this to work
pin "datatables", to: "datatables/datatables.min.js"
pin "vfs-fonts", to: "datatables/vfs_fonts.js"
pin "pdfmake", to: 'datatables/pdfmake.min.js'

#select2
pin "select2" # @4.1.0

#my local js
pin "cafe_bundle", to: "cafe_bundle.js"
pin "cafe", to: "cafe.js"
pin "cafe_event", to: "cafe_event.js"
pin "cafe_datatable", to: 'cafe_datatable.js'
pin "cafe_turbo", to: "cafe_turbo.js"

#pin "ace-rails-ap"
pin "chart", to: 'chart.umd.js' # @4.4.0 from https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.0/chart.umd.js
pin "tempus-dominus-esm", to: "tempus-dominus/tempus-dominus.esm.js"
pin "tempus-dominus-js", to: "tempus-dominus/tempus-dominus.js"

#hotwire
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true

# rails usj (should be removed soon)
pin "rails-ujs", to: 'rails-ujs.esm.js'
pin "bootbox", to: 'bootbox.js' # @6.0.0
pin "bootstrap" # @5.3.6
pin "jquery" # @3.7.1
pin "@popperjs/core", to: "@popperjs--core.js" # @2.11.8
