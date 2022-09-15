(function (factory) {
    if (typeof define === 'function' && define.amd) {
        // AMD
        define(['jquery', 'datatables.net-bs', 'datatables.net-staterestore'], function ($) {
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
                $ = require('datatables.net-bs')(root, $).$;
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
        creationButton: 'dtsr-creation-button btn btn-default',
        creationForm: 'dtsr-creation-form modal-body',
        creationText: 'dtsr-creation-text modal-header',
        creationTitle: 'dtsr-creation-title modal-title',
        nameInput: 'dtsr-name-input form-control'
    });
    $.extend(true, dataTable.StateRestore.classes, {
        confirmationButton: 'dtsr-confirmation-button btn btn-default',
        confirmationTitle: 'dtsr-confirmation title modal-header',
        input: 'dtsr-input form-control'
    });
    return dataTable.stateRestore;
}));
