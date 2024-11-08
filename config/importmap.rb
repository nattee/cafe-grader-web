# Pin npm packages by running ./bin/importmap

#entry point
pin "application"
pin "prepend_jquery"
#pin "my_sprocket"
pin_all_from "app/javascript/controllers", under: "controllers"

#we don't need jquery in importmap because we use sprocket version
#pin "jquery", to: 'my_jquery.js', preload: true
#pin "bootstrap", to: "bootstrap.bundle.min.js", preload: true
#no need popper, because bundled already in bootstrap
#pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.6/lib/index.js"

# datatable
# I have to fix vfs_font.js for this to work
pin "my_datatable", to: 'my_datatable.js'
pin "datatables", to: "datatables/datatables.min.js"
pin "vfs-fonts", to: "datatables/vfs_fonts.js"
pin "pdfmake", to: 'datatables/pdfmake.min.js'

#select2
pin "select2", to: "select2.min.js"

#my local js
pin "custom", to: "custom.js"

#pin "ace-rails-ap"
pin "chart", to: 'chart.umd.js' # @4.4.0 from https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.0/chart.umd.js
pin "tempus-dominus-esm", to: "tempus-dominus/tempus-dominus.esm.js"
pin "tempus-dominus-js", to: "tempus-dominus/tempus-dominus.js"

#hotwire
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@rails/ujs", to: "https://ga.jspm.io/npm:@rails/ujs@7.1.3-4/app/assets/javascripts/rails-ujs.esm.js"
