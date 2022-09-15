/*! Bootstrap integration for DataTables' StateRestore
 * ©2016 SpryMedia Ltd - datatables.net/license
 */
(function (factory) {
    if (typeof define === 'function' && define.amd) {
        // AMD
        define(['jquery', 'datatables.net-jq', 'datatables.net-staterestore'], function ($) {
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
                $ = require('datatables.net-jq')(root, $).$;
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
        checkRow: 'dtsr-check-row form',
        creationButton: 'dtsr-creation-button ui-button ui-corner-all ui-widget',
        creationForm: 'dtsr-creation-form modal-body',
        creationText: 'dtsr-creation-text modal-header',
        creationTitle: 'dtsr-creation-title modal-title',
        nameInput: 'dtsr-name-input form-control',
        nameLabel: 'dtsr-name-label form-label',
        nameRow: 'dtsr-name-row medium-6 cell'
    });
    $.extend(true, dataTable.StateRestore.classes, {
        // eslint-disable-next-line max-len
        confirmationButton: 'dtsr-confirmation-button ui-button ui-state-default ui-button-text-only ui-corner-all ui-widget'
    });
    return dataTable.stateRestore;
}));
