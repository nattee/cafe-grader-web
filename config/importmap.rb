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
pin "jszip", to: "jszip.min.js"
pin "pdfmake"
pin "pdfmake-vfs", to: 'datatables/pdfmake-0.1.36/vfs_fonts.js'

pin "datatables-bundle", to: 'datatables/datatables.js'
pin "datatables", to: "datatables/DataTables-1.12.1/js/jquery.dataTables.js"
pin "datatables-bs5", to: "datatables/DataTables-1.12.1/js/dataTables.bootstrap5.js"
pin "datatables-editor", to: "datatables/Editor-2.0.9/js/dataTables.editor.js"
pin "datatables-editor-bs5", to: "datatables/Editor-2.0.9/js/editor.bootstrap5.min.js"
pin "datatables-autofill", to: "datatables/AutoFill-2.4.0/js/dataTables.autoFill.js"
pin "datatables-autofill-bs5", to: "datatables/AutoFill-2.4.0/js/autoFill.bootstrap5.js"
pin "datatables-button", to: "datatables/Buttons-2.2.3/js/dataTables.buttons.js"
pin "datatables-button-bs5", to: "datatables/Buttons-2.2.3/js/buttons.bootstrap5.js"
pin "datatables-button-colvis", to: "datatables/Buttons-2.2.3/js/buttons.colVis.js"
pin "datatables-button-html5", to: "datatables/Buttons-2.2.3/js/buttons.html5.js"
pin "datatables-button-print", to: "datatables/Buttons-2.2.3/js/buttons.print.js"
pin "datatables-colrecorder", to: "datatables/ColReorder-1.5.6/js/dataTables.colReorder.js"
pin "datatables-datetime", to: "datatables/DateTime-1.1.2/js/dataTables.dateTime.js"
pin "datatables-fixedcolumns", to: "datatables/FixedColumns-4.1.0/js/dataTables.fixedColumns.js"
pin "datatables-fixedheader", to: "datatables/FixedHeader-3.2.4/js/dataTables.fixedHeader.js"
pin "datatables-keytable", to: "datatables/KeyTable-2.7.0/js/dataTables.keyTable.js"
pin "datatables-responsive", to: "datatables/Responsive-2.3.0/js/dataTables.responsive.js"
pin "datatables-responsive-bs5", to: "datatables/Responsive-2.3.0/js/responsive.bootstrap5.js"
pin "datatables-rowgroup", to: "datatables/RowGroup-1.2.0/js/dataTables.rowGroup.js"
pin "datatables-rowreorder", to: "datatables/RowReorder-1.2.8/js/dataTables.rowReorder.js"
pin "datatables-scroller", to: "datatables/Scroller-2.0.7/js/dataTables.scroller.js"
pin "datatables-searchbuilder", to: "datatables/SearchBuilder-1.3.4/js/dataTables.searchBuilder.js"
pin "datatables-searchbuilder-bs5", to: "datatables/SearchBuilder-1.3.4/js/searchBuilder.bootstrap5.js"
pin "datatables-searchpanes", to: "datatables/SearchPanes-2.0.2/js/dataTables.searchPanes.js"
pin "datatables-searchpanes-bs5", to: "datatables/SearchPanes-2.0.2/js/searchPanes.bootstrap5.js"
pin "datatables-select", to: "datatables/Select-1.4.0/js/dataTables.select.js"
pin "datatables-staterestore", to: "datatables/StateRestore-1.1.1/js/dataTables.stateRestore.js"
pin "datatables-staterestore-bs5", to: "datatables/StateRestore-1.1.1/js/stateRestore.bootstrap5.js"

#select2
pin "select2", to: "select2.min.js"

#my local js
pin "custom", to: "custom.js"

#pin "ace-rails-ap"
