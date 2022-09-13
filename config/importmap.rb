# Pin npm packages by running ./bin/importmap

pin "application", preload: true
#pin_all_from "app/javascript/controllers", under: "controllers"

#pin "jquery" # @3.6.1
#pin "pdfmake", to: "https://ga.jspm.io/npm:pdfmake@0.2.5/build/pdfmake.js"
pin "jquery", to: 'jquery-local.js'
