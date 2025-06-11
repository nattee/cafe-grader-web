# Pin npm packages by running ./bin/importmap

#entry point
pin "application"
pin "prepend_jquery"
#pin "my_sprocket"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/mixins", under: "mixins"

# datatable
# I have to fix vfs_font.js for this to work
pin "datatables", to: "datatables/datatables.min.js"
pin "vfs-fonts", to: "datatables/vfs_fonts.js"
pin "pdfmake", to: 'datatables/pdfmake.min.js'

#select2
pin "select2", to: "select2.min.js" # @4.1.0


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
pin "jquery", preload: true # @3.7.1



# this bootstrap is wgetted from "https://ga.jspm.io/npm:bootstrap@5.3.6/dist/js/bootstrap.esm.js"
# we need the esm version
# similarly, tis @popperjs/core is wget from ""
# pin "bootstrap", to: "bootstrap.js" # @5.3.6
pin "bootstrap", to: "bootstrap.esm.js"
pin "@popperjs/core", to: "@popperjs-core-esm.js" # @2.11.8

#my local js
pin "cafe_bundle", to: "cafe_bundle.js"
pin "cafe", to: "cafe.js"
pin "cafe_event", to: "cafe_event.js"
pin "cafe_datatable", to: 'cafe_datatable.js'
pin "cafe_turbo", to: "cafe_turbo.js"
pin "setup_jquery"
pin "setup_bootstrap"
pin "setup_datatables"
pin "moment" # @2.30.1
pin "ace-builds" # @1.42.0
