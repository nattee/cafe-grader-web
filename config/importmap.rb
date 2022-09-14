# Pin npm packages by running ./bin/importmap

#entry point
pin "application", preload: true
pin "prepend_jquery", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"

pin "pdfmake", to: "https://ga.jspm.io/npm:pdfmake@0.2.5/build/pdfmake.js"
pin "jquery", to: 'jquery.js'
pin "bootstrap", to: "bootstrap.bundle.min.js"
#no need popper, because bundled already in bootstrap
#pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.6/lib/index.js"
