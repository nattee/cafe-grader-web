/*! Bootstrap integration for DataTables' StateRestore
 * ©2016 SpryMedia Ltd - datatables.net/license
 */
(function (factory) {
    if (typeof define === 'function' && define.amd) {
        // AMD
        define(['jquery', 'datatables.net-bs5', 'datatables.net-staterestore'], function ($) {
            return factory($);
        });
    }
    else if (typeof exports === 'object') {
        // CommonJS
        module.exports = function (root, $) {
            if (!root) {
                root = window;
            }
            if (!$ || !$.fn.dataTable) {
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                $ = require('datatables.net-bs5')(root, $).$;
            }
            if (!$.fn.dataTable.StateRestore) {
                // eslint-disable-next-line @typescript-eslint/no-var-requires
                require('datatables.net-staterestore')(root, $);
            }
            return factory($);
        };
    }
    else {
        // Browser
        factory(jQuery);
    }
}(function ($) {
    'use strict';
    var dataTable = $.fn.dataTable;
    $.extend(true, dataTable.StateRestoreCollection.classes, {
        checkBox: 'dtsr-check-box form-check-input',
        checkLabel: 'dtsr-check-label form-check-label',
        checkRow: 'dtsr-check-row form-check',
        creationButton: 'dtsr-creation-button btn btn-secondary',
        creationForm: 'dtsr-creation-form modal-body',
        creationText: 'dtsr-creation-text modal-header',
        creationTitle: 'dtsr-creation-title modal-title',
        nameInput: 'dtsr-name-input form-control',
        nameLabel: 'dtsr-name-label form-label'
    });
    $.extend(true, dataTable.StateRestore.classes, {
        confirmationButton: 'dtsr-confirmation-button btn btn-secondary',
        input: 'dtsr-input form-control'
    });
    return dataTable.stateRestore;
}));
