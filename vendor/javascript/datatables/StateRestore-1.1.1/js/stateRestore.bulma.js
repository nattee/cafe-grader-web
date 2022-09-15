/*! Bootstrap integration for DataTables' StateRestore
 * ©2016 SpryMedia Ltd - datatables.net/license
 */
(function (factory) {
    if (typeof define === 'function' && define.amd) {
        // AMD
        define(['jquery', 'datatables.net-bm', 'datatables.net-staterestore'], function ($) {
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
                $ = require('datatables.net-bm')(root, $).$;
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
        checkRow: 'dtsr-check-row checkbox',
        creationButton: 'dtsr-creation-button button',
        creationForm: 'dtsr-creation-form modal-content',
        creationText: 'dtsr-creation-text modal-header',
        creationTitle: 'dtsr-creation-title modal-card-title',
        nameInput: 'dtsr-name-input input'
    });
    $.extend(true, dataTable.StateRestore.classes, {
        confirmationButton: 'dtsr-confirmation-button button',
        confirmationTitle: 'dtsr-confirmation-title modal-card-title',
        input: 'dtsr-input input'
    });
    return dataTable.stateRestore;
}));
