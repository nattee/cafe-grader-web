
/*! DataTables Editor v2.0.9
 *
 * ©2012-2022 SpryMedia Ltd, all rights reserved.
 * License: editor.datatables.net/license
 */

(function( factory ){
	if ( typeof define === 'function' && define.amd ) {
		// AMD
		define( ['jquery', 'datatables.net'], function ( $ ) {
			return factory( $, window, document );
		} );
	}
	else if ( typeof exports === 'object' ) {
		// CommonJS
		module.exports = function (root, $) {
			if ( ! root ) {
				// CommonJS environments without a window global must pass a
				// root. This will give an error otherwise
				root = window;
			}

			if ( ! $ ) {
				$ = typeof window !== 'undefined' ? // jQuery's factory checks for a global window
					require('jquery') :
					require('jquery')( root );
			}

			if ( ! $.fn.dataTable ) {
				require('datatables.net')(root, $);
			}


			return factory( $, root, root.document );
		};
	}
	else {
		// Browser
		factory( jQuery, window, document );
	}
}(function( $, window, document, undefined ) {
'use strict';
var DataTable = $.fn.dataTable;

var formOptions = {
    buttons: true,
    drawType: false,
    focus: 0,
    message: true,
    nest: false,
    onBackground: 'blur',
    onBlur: 'close',
    onComplete: 'close',
    onEsc: 'close',
    onFieldError: 'focus',
    onReturn: 'submit',
    scope: 'row',
    submit: 'all',
    submitHtml: '▶',
    submitTrigger: null,
    title: true
};

var defaults$1 = {
    /**
     * Parameter name to use to submit data to the server.
     *
     * @type string
     */
    actionName: 'action',
    /**
     * Control how the Ajax call to update data on the server.
     *
     * This option matches the `dt-init ajax` option in that is can be provided
     * in one of three different ways:
     *
     * * string - As a string, the value given is used as the url to target
     * the Ajax request to, using the default Editor Ajax options. Note that
     * for backwards compatibility you can use the form "METHOD URL" - for
     * example: `"PUT api/users"`, although it is recommended you use the
     * object form described below.
     * * object - As an object, the `ajax` property has two forms:
     * * Used to extend and override the default Ajax options that Editor
     * uses. This can be very useful for adding extra data for example, or
     * changing the HTTP request type.
     * * With `create`, `edit` and `remove` properties, Editor will use the
     * option for the action that it is taking, which can be useful for
     * REST style interfaces. The value of each property can be a string,
     * object or function, using exactly the same options as the main `ajax`
     * option. All three options must be defined if this form is to be used.
     * * function - As a function this gives complete control over the method
     * used to update the server (if indeed a server is being used!). For
     * example, you could use a different data store such as localStorage,
     * Firebase or route the data through a web-socket.
     *
     * @example
     *    // As a string - all actions are submitted to this URI as POST requests
     *    $(document).ready(function() {
     *      var editor = new $.fn.Editor( {
     *        "ajax": 'php/index.php',
     *        "table": "#example"
     *      } );
     *    } );
     *
     * @example
     *    // As an object - using GET rather than POST
     *    $(document).ready(function() {
     *      var editor = new $.fn.Editor( {
     *        "ajax": {
     *          "type": 'GET',
     *          "url": 'php/index.php
     *        },
     *        "table": "#example"
     *      } );
     *    } );
     *
     * @example
     *    // As an object - each action is submitted to a different URI as POST requests
     *    $(document).ready(function() {
     *      var editor = new $.fn.Editor( {
     *        "ajax": {
     *          "create": "/rest/user/create",
     *          "edit":   "/rest/user/_id_/edit",
     *          "remove": "/rest/user/_id_/delete"
     *        },
     *        "table": "#example"
     *      } );
     *    } );
     *
     * @example
     *    // As an object - with different HTTP methods for each action
     *    $(document).ready(function() {
     *      var editor = new $.fn.Editor( {
     *        "ajax": {
     *          "create": {
     *          	type: 'POST',
     *          	url:  '/rest/user/create'
     *          },
     *          "edit": {
     *          	type: 'PUT',
     *          	url:  '/rest/user/edit/_id_'
     *          },
     *          "remove": {
     *          	type: 'DELETE',
     *          	url:  '/rest/user/delete'
     *          }
     *        },
     *        "table": "#example"
     *      } );
     *    } );
     *
     *    // As a function - Making a custom `$.ajax` call
     *    $(document).ready(function() {
     *      var editor = new $.fn.Editor( {
     *        "table": "#example",
     *        "ajax": function ( method, url, data, successCallback, errorCallback ) {
     *          $.ajax( {
     *            "type": method,
     *            "url":  url,
     *            "data": data,
     *            "dataType": "json",
     *            "success": function (json) {
     *              successCallback( json );
     *            },
     *            "error": function (xhr, error, thrown) {
     *              errorCallback( xhr, error, thrown );
     *            }
     *          } );
     *        }
     *      } );
     *    } );
     */
    ajax: null,
    /**
     * The display controller for the form. The form itself is just a collection of
     * DOM elements which require a display container. This display controller allows
     * the visual appearance of the form to be significantly altered without major
     * alterations to the Editor code. There are two display controllers built into
     * Editor *lightbox* and *envelope*. The value of this property will
     * be used to access the display controller defined in {@link Editor.display}
     * for the given name. Additional display controllers can be added by adding objects
     * to that object, through extending the displayController model:
     * {@link Editor.models.displayController}.
     *
     * @type string
     * @default lightbox
     *
     * @example
     *    $(document).ready(function() {
     *      var editor = new $.fn.Editor( {
     *        "ajax": "php/index.php",
     *        "table": "#example",
     *        "display": 'envelope'
     *      } );
     *    } );
     */
    display: 'lightbox',
    /**
     * Events / callbacks - event handlers can be assigned as an individual function
     * during initialisation using the parameters in this name space. The names, and
     * the parameters passed to each callback match their event equivalent in the
     * {@link Editor} object.
     *
     * @namespace
     * @deprecated Since 1.3. Use the `on()` API method instead. Note that events
     * passed in do still operate as they did in 1.2- but are no longer
     * individually documented.
     */
    events: {},
    /**
     * Fields to initialise the form with - see {@link Editor.models.field} for
     * a full list of the options available to each field. Note that if fields are not
     * added to the form at initialisation time using this option, they can be added using
     * the {@link Editor#add} API method.
     *
     * @type array
     * @default []
     *
     * @example
     *    $(document).ready(function() {
     *      var editor = new $.fn.Editor( {
     *        "ajax": "php/index.php",
     *        "table": "#example",
     *        "fields": [ {
     *            "label": "User name:",
     *            "name": "username"
     *          }
     *          // More fields would typically be added here!
     *        } ]
     *      } );
     *    } );
     */
    fields: [],
    formOptions: {
        bubble: $.extend({}, formOptions, {
            buttons: '_basic',
            message: false,
            submit: 'changed',
            title: false
        }),
        inline: $.extend({}, formOptions, {
            buttons: false,
            submit: 'changed'
        }),
        main: $.extend({}, formOptions)
    },
    /**
     * Internationalisation options for Editor. All client-side strings that the
     * end user can see in the interface presented by Editor can be modified here.
     *
     * You may also wish to refer to the <a href="http://datatables.net/usage/i18n">
     * DataTables internationalisation options</a> to provide a fully language
     * customised table interface.
     *
     * @namespace
     *
     * @example
     *    // Set the 'create' button text. All other strings used are the
     *    // default values.
     *    var editor = new $.fn.Editor( {
     *      "ajax": "data/source",
     *      "table": "#example",
     *      "i18n": {
     *        "create": {
     *          "button": "New user"
     *        }
     *      }
     *    } );
     *
     * @example
     *    // Set the submit text for all three actions
     *    var editor = new $.fn.Editor( {
     *      "ajax": "data/source",
     *      "table": "#example",
     *      "i18n": {
     *        "create": {
     *          "submit": "Create new user"
     *        },
     *        "edit": {
     *          "submit": "Update user"
     *        },
     *        "remove": {
     *          "submit": "Remove user"
     *        }
     *      }
     *    } );
     */
    i18n: {
        /**
         * Close button title text
         *
         * @type string
         * @default Close
         */
        close: 'Close',
        /**
         * Strings used when working with the Editor 'create' action (creating new
         * records).
         *
         * @namespace
         */
        create: {
            /**
             * Buttons button text
             *
             * @type string
             * @default New
             */
            button: 'New',
            /**
             * Submit button text
             *
             * @type string
             * @default Create
             */
            submit: 'Create',
            /**
             * Display container title (when showing the editor display)
             *
             * @type string
             * @default Create new entry
             */
            title: 'Create new entry'
        },
        datetime: {
            amPm: ['am', 'pm'],
            hours: 'Hour',
            minutes: 'Minute',
            months: [
                'January',
                'February',
                'March',
                'April',
                'May',
                'June',
                'July',
                'August',
                'September',
                'October',
                'November',
                'December'
            ],
            next: 'Next',
            previous: 'Previous',
            seconds: 'Second',
            unknown: '-',
            weekdays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
        },
        /**
         * Strings used when working with the Editor 'edit' action (editing existing
         * records).
         *
         * @namespace
         */
        edit: {
            /**
             * Buttons button text
             *
             * @type string
             * @default Edit
             */
            button: 'Edit',
            /**
             * Submit button text
             *
             * @type string
             * @default Update
             */
            submit: 'Update',
            /**
             * Display container title (when showing the editor display)
             *
             * @type string
             * @default Edit entry
             */
            title: 'Edit entry'
        },
        /**
         * Strings used for error conditions.
         *
         * @namespace
         */
        error: {
            /**
             * Generic server error message
             *
             * @type string
             * @default
             * A system error has occurred (<a target=\"_blank\" href=\"//datatables.net/tn/12\">More information</a>)
             */
            system: 'A system error has occurred (<a target="_blank" href="//datatables.net/tn/12">More information</a>).'
        },
        /**
         * Strings used for multi-value editing
         *
         * @namespace
         */
        multi: {
            /**
             * Shown below the multi title text, although only the first
             * instance of this text is shown in the form to reduce redundancy
             */
            info: 'The selected items contain different values for this input. To edit and set all items for this input to the same value, click or tap here, otherwise they will retain their individual values.',
            /**
             * Disabled for multi-row editing
             */
            noMulti: 'This input can be edited individually, but not part of a group.',
            /**
             * Shown below the field input when group editing a value to allow
             * the user to return to the original multiple values
             */
            restore: 'Undo changes',
            /**
             * Shown in place of the field value when a field has multiple values
             */
            title: 'Multiple values'
        },
        /**
         * Strings used when working with the Editor 'delete' action (deleting
         * existing records).
         *
         * @namespace
         */
        remove: {
            /**
             * Buttons button text
             *
             * @type string
             * @default Delete
             */
            button: 'Delete',
            /**
             * Deletion confirmation message.
             *
             * As Editor has the ability to delete either a single or multiple rows
             * at a time, this option can be given as either a string (which will be
             * used regardless of how many records are selected) or as an object
             * where the property "_" will be used (with %d substituted for the number
             * of records to be deleted) as the delete message, unless there is a
             * key with the number of records to be deleted. This allows Editor
             * to consider the different pluralisation characteristics of different
             * languages.
             *
             * @type object|string
             * @default Are you sure you wish to delete %d rows?
             *
             * @example
             *    // String - no plural consideration
             *    var editor = new $.fn.Editor( {
             *      "ajax": "data/source",
             *      "table": "#example",
             *      "i18n": {
             *        "remove": {
             *          "confirm": "Are you sure you wish to delete %d record(s)?"
             *        }
             *      }
             *    } );
             *
             * @example
             *    // Basic 1 (singular) or _ (plural)
             *    var editor = new $.fn.Editor( {
             *      "ajax": "data/source",
             *      "table": "#example",
             *      "i18n": {
             *        "remove": {
             *          "confirm": {
             *            "_": "Confirm deletion of %d records.",
             *            "1": "Confirm deletion of record."
             *        }
             *      }
             *    } );
             *
             * @example
             *    // Singular, dual and plural
             *    var editor = new $.fn.Editor( {
             *      "ajax": "data/source",
             *      "table": "#example",
             *      "i18n": {
             *        "remove": {
             *          "confirm": {
             *            "_": "Confirm deletion of %d records.",
             *            "1": "Confirm deletion of record.",
             *            "2": "Confirm deletion of both record."
             *        }
             *      }
             *    } );
             *
             */
            confirm: {
                1: 'Are you sure you wish to delete 1 row?',
                _: 'Are you sure you wish to delete %d rows?'
            },
            /**
             * Submit button text
             *
             * @type string
             * @default Delete
             */
            submit: 'Delete',
            /**
             * Display container title (when showing the editor display)
             *
             * @type string
             * @default Delete
             */
            title: 'Delete',
        }
    },
    /**
     * JSON property from which to read / write the row's ID property (i.e. its
     * unique column index that identifies the row to the database). By default
     * Editor will use the `DT_RowId` property from the data source object
     * (DataTable's magic property to set the DOM id for the row).
     *
     * If you want to read a parameter from the data source object instead of
     * using `DT_RowId`, set this option to the property name to use.
     *
     * Like other data source options the `srcId` option can be given in dotted
     * object notation to read nested objects.
     *
     * @type null|string
     * @default DT_RowId
     *
     * @example
     *    // Using a data source such as:
     *    // { "id":12, "browser":"Chrome", ... }
     *    $(document).ready(function() {
     *      var editor = new $.fn.Editor( {
     *        "ajax": "php/index.php",
     *        "table": "#example",
     *        "idSrc": "id"
     *      } );
     *    } );
     */
    idSrc: 'DT_RowId',
    /**
     * jQuery selector that can be used to identify the table you wish to apply
     * this editor instance to.
     *
     * In previous versions of Editor (1.2 and earlier), this parameter was
     * called `table`. The name has been altered in 1.3+ to simplify the
     * initialisation. This is a backwards compatible change - if you pass in
     * a `table` option it will be used.
     *
     * @type string
     * @default <i>Empty string</i>
     *
     * @example
     *    $(document).ready(function() {
     *      var editor = new $.fn.Editor( {
     *        "ajax": "php/index.php",
     *        "table": "#example"
     *      } );
     *    } );
     */
    table: null,
};

var settings = {
    action: null,
    actionName: 'action',
    ajax: null,
    bubbleNodes: [],
    closeCb: null,
    closeIcb: null,
    dataSource: null,
    displayController: null,
    displayed: false,
    editCount: 0,
    editData: {},
    editFields: {},
    editOpts: {},
    fields: {},
    formOptions: {
        bubble: $.extend({}, formOptions),
        inline: $.extend({}, formOptions),
        main: $.extend({}, formOptions),
    },
    globalError: '',
    id: -1,
    idSrc: null,
    includeFields: [],
    mode: null,
    modifier: null,
    opts: null,
    order: [],
    processing: false,
    setFocus: null,
    table: null,
    template: null,
    unique: 0
};

var DataTable$6 = $.fn.dataTable;
var DtInternalApi = DataTable$6.ext.oApi;
function objectKeys(o) {
    var out = [];
    for (var key in o) {
        if (o.hasOwnProperty(key)) {
            out.push(key);
        }
    }
    return out;
}
function el(tag, ctx) {
    if (ctx === undefined) {
        ctx = document;
    }
    return $('*[data-dte-e="' + tag + '"]', ctx);
}
function safeDomId(id, prefix) {
    if (prefix === void 0) { prefix = '#'; }
    return typeof id === 'string' ?
        prefix + id.replace(/\./g, '-') :
        prefix + id;
}
function safeQueryId(id, prefix) {
    if (prefix === void 0) { prefix = '#'; }
    return typeof id === 'string' ?
        prefix + id.replace(/(:|\.|\[|\]|,)/g, '\\$1') :
        prefix + id;
}
function dataGet(src) {
    return DtInternalApi._fnGetObjectDataFn(src);
}
function dataSet(src) {
    return DtInternalApi._fnSetObjectDataFn(src);
}
var extend = DtInternalApi._fnExtend;
function pluck(a, prop) {
    var out = [];
    $.each(a, function (idx, elIn) {
        out.push(elIn[prop]);
    });
    return out;
}
/**
 * Compare parameters for difference - diving into arrays and objects if
 * needed, allowing the object reference to be different, but the contents to
 * match.
 *
 * Please note that LOOSE type checking is used
 */
function deepCompare(o1, o2) {
    if (typeof o1 !== 'object' || typeof o2 !== 'object') {
        return o1 == o2;
    }
    var o1Props = objectKeys(o1);
    var o2Props = objectKeys(o2);
    if (o1Props.length !== o2Props.length) {
        return false;
    }
    for (var i = 0, ien = o1Props.length; i < ien; i++) {
        var propName = o1Props[i];
        if (typeof o1[propName] === 'object') {
            if (!deepCompare(o1[propName], o2[propName])) {
                return false;
            }
        }
        else if (o1[propName] != o2[propName]) {
            return false;
        }
    }
    return true;
}

/* -  -  -  -  -  -  -  -  -  -
 * DataTables editor interface
 */
var _dtIsSsp = function (dt, editor) {
    // If the draw type is `none`, then we still need to use the DT API to
    // update the display with the new data
    return dt.settings()[0].oFeatures.bServerSide &&
        editor.s.editOpts.drawType !== 'none';
};
var _dtApi = function (table) {
    return table instanceof $.fn.dataTable.Api
        ? table
        : $(table).DataTable();
};
var _dtHighlight = function (node) {
    // Highlight a row using CSS transitions. The timeouts need to match the
    // transition duration from the CSS
    node = $(node);
    setTimeout(function () {
        node.addClass('highlight');
        setTimeout(function () {
            node
                .addClass('noHighlight')
                .removeClass('highlight');
            setTimeout(function () {
                node.removeClass('noHighlight');
            }, 550);
        }, 500);
    }, 20);
};
var _dtRowSelector = function (out, dt, identifier, fields, idFn) {
    dt.rows(identifier).indexes().each(function (idx) {
        var row = dt.row(idx);
        var data = row.data();
        var idSrc = idFn(data);
        if (idSrc === undefined) {
            Editor.error('Unable to find row identifier', 14);
        }
        out[idSrc] = {
            data: data,
            fields: fields,
            idSrc: idSrc,
            node: row.node(),
            type: 'row'
        };
    });
};
var _dtFieldsFromIdx = function (dt, fields, idx, ignoreUnknown) {
    var col = dt.settings()[0].aoColumns[idx];
    var dataSrc = col.editField !== undefined ?
        col.editField :
        col.mData;
    var resolvedFields = {};
    var run = function (field, dataSrcIn) {
        if (field.name() === dataSrcIn) {
            resolvedFields[field.name()] = field;
        }
    };
    $.each(fields, function (name, fieldInst) {
        if (Array.isArray(dataSrc)) {
            for (var _i = 0, dataSrc_1 = dataSrc; _i < dataSrc_1.length; _i++) {
                var data = dataSrc_1[_i];
                run(fieldInst, data);
            }
        }
        else {
            run(fieldInst, dataSrc);
        }
    });
    if ($.isEmptyObject(resolvedFields) && !ignoreUnknown) {
        Editor.error('Unable to automatically determine field from source. Please specify the field name.', 11);
    }
    return resolvedFields;
};
var _dtCellSelector = function (out, dt, identifier, allFields, idFn, forceFields) {
    if (forceFields === void 0) { forceFields = null; }
    var cells = dt.cells(identifier);
    cells.indexes().each(function (idx) {
        var cell = dt.cell(idx);
        var row = dt.row(idx.row);
        var data = row.data();
        var idSrc = idFn(data);
        var fields = forceFields || _dtFieldsFromIdx(dt, allFields, idx.column, cells.count() > 1);
        var isNode = (typeof identifier === 'object' && identifier.nodeName) || identifier instanceof $;
        var prevDisplayFields;
        var prevAttach;
        var prevAttachFields;
        // Only add if a field was found to edit
        if (Object.keys(fields).length) {
            // The row selector will create a new `out` object for the identifier, and the
            // cell selector might be called multiple times for a row, so we need to save
            // our specific items
            if (out[idSrc]) {
                prevAttach = out[idSrc].attach;
                prevAttachFields = out[idSrc].attachFields;
                prevDisplayFields = out[idSrc].displayFields;
            }
            // Use the row selector to get the row information
            _dtRowSelector(out, dt, idx.row, allFields, idFn);
            out[idSrc].attachFields = prevAttachFields || [];
            out[idSrc].attachFields.push(Object.keys(fields));
            out[idSrc].attach = prevAttach || [];
            out[idSrc].attach.push(isNode ?
                $(identifier).get(0) :
                cell.fixedNode ? // If its under a fixed column, get the floating node
                    cell.fixedNode() :
                    cell.node());
            out[idSrc].displayFields = prevDisplayFields || {};
            $.extend(out[idSrc].displayFields, fields);
        }
    });
};
var _dtColumnSelector = function (out, dt, identifier, fields, idFn) {
    dt.cells(null, identifier).indexes().each(function (idx) {
        _dtCellSelector(out, dt, idx, fields, idFn);
    });
};
var dataSource$1 = {
    commit: function (action, identifier, data, store) {
        // Updates complete - redraw
        var that = this;
        var dt = _dtApi(this.s.table);
        var ssp = dt.settings()[0].oFeatures.bServerSide;
        var ids = store.rowIds;
        // On edit, if there are any rows left in the `store.rowIds`, then they
        // were not returned by the server and should be removed (they might not
        // meet filtering requirements any more for example)
        if (!_dtIsSsp(dt, this) && action === 'edit' && store.rowIds.length) {
            var row = void 0;
            var compare = function (id) {
                return function (rowIdx, rowData, rowNode) {
                    return id == dataSource$1.id.call(that, rowData);
                };
            };
            for (var i = 0, ien = ids.length; i < ien; i++) {
                // Find the row to edit - attempt to do an id look up first for speed
                try {
                    row = dt.row(safeQueryId(ids[i]));
                }
                catch (e) {
                    row = dt;
                }
                // If not found, then we need to do it the slow way
                if (!row.any()) {
                    row = dt.row(compare(ids[i]));
                }
                if (row.any() && !ssp) {
                    row.remove();
                }
            }
        }
        var drawType = this.s.editOpts.drawType;
        if (drawType !== 'none') {
            var dtAny = dt;
            // SSP highlighting has to go after the draw, but this can't be
            // merged with client-side processing highlight as we want that
            // to work even when there isn't a draw happening.
            if (ssp && ids && ids.length) {
                dt.one('draw', function () {
                    for (var i = 0, ien = ids.length; i < ien; i++) {
                        var row = dt.row(safeQueryId(ids[i]));
                        if (row.any()) {
                            _dtHighlight(row.node());
                        }
                    }
                });
            }
            dt.draw(drawType);
            // Responsive needs to take account of new data column widths
            if (dtAny.responsive) {
                dtAny.responsive.recalc();
            }
            // Rebuild searchpanes
            if (typeof dtAny.searchPanes === 'function' && !ssp) {
                dtAny.searchPanes.rebuildPane(undefined, true);
            }
            // Rebuild searchbuilder
            if (dtAny.searchBuilder !== undefined && typeof dtAny.searchBuilder.rebuild === 'function' && !ssp) {
                dtAny.searchBuilder.rebuild(dtAny.searchBuilder.getDetails());
            }
        }
    },
    create: function (fields, data) {
        var dt = _dtApi(this.s.table);
        if (!_dtIsSsp(dt, this)) {
            var row = dt.row.add(data);
            _dtHighlight(row.node());
        }
    },
    edit: function (identifier, fields, data, store) {
        var that = this;
        var dt = _dtApi(this.s.table);
        // No point in doing anything when server-side processing - the commit
        // will redraw the table
        if (!_dtIsSsp(dt, this) || this.s.editOpts.drawType === 'none') {
            // The identifier can select one or more rows, but the data will
            // refer to just a single row. We need to determine which row from
            // the set is the one to operator on.
            var rowId_1 = dataSource$1.id.call(this, data);
            var row = void 0;
            // Find the row to edit - attempt to do an id look up first for speed
            try {
                row = dt.row(safeQueryId(rowId_1));
            }
            catch (e) {
                row = dt;
            }
            // If not found, then we need to do it the slow way
            if (!row.any()) {
                row = dt.row(function (rowIdx, rowData, rowNode) {
                    return rowId_1 == dataSource$1.id.call(that, rowData);
                });
            }
            if (row.any()) {
                // Merge data to allow for a sub-set to be returned
                var toSave = extend({}, row.data(), true);
                toSave = extend(toSave, data, true);
                row.data(toSave);
                // Remove the item from the list of indexes now that is has been
                // updated
                var idx = $.inArray(rowId_1, store.rowIds);
                store.rowIds.splice(idx, 1);
            }
            else {
                // If not found, then its a new row (change in pkey possibly)
                row = dt.row.add(data);
            }
            _dtHighlight(row.node());
        }
    },
    fakeRow: function (insertPoint) {
        var dt = _dtApi(this.s.table);
        var tr = $('<tr class="dte-inlineAdd">');
        var attachFields = [];
        var attach = [];
        var displayFields = {};
        for (var i = 0, ien = dt.columns(':visible').count(); i < ien; i++) {
            var visIdx = dt.column(i + ':visible').index();
            var td = $('<td>').appendTo(tr);
            var fields = _dtFieldsFromIdx(dt, this.s.fields, visIdx, true);
            var cell = dt.cell(':eq(0)', visIdx).node();
            if (cell) {
                td.addClass(cell.className);
            }
            if (Object.keys(fields).length) {
                attachFields.push(Object.keys(fields));
                attach.push(td[0]);
                $.extend(displayFields, fields);
            }
        }
        var append = function () {
            var action = insertPoint === 'end'
                ? 'appendTo'
                : 'prependTo';
            tr[action](dt.table(undefined).body());
        };
        this.__dtFakeRow = tr;
        // Insert into the table
        append();
        dt.on('draw.dte-createInline', function () {
            append();
        });
        return {
            0: {
                attach: attach,
                attachFields: attachFields,
                displayFields: displayFields,
                fields: this.s.fields,
                type: 'row'
            }
        };
    },
    fakeRowEnd: function () {
        var dt = _dtApi(this.s.table);
        dt.off('draw.dte-createInline');
        this.__dtFakeRow.remove();
        this.__dtFakeRow = null;
    },
    // get idSrc, fields to edit, data and node for each item
    fields: function (identifier) {
        var idFn = dataGet(this.s.idSrc);
        var dt = _dtApi(this.s.table);
        var fields = this.s.fields;
        var out = {};
        if ($.isPlainObject(identifier) &&
            (identifier.rows !== undefined || identifier.columns !== undefined || identifier.cells !== undefined)) {
            // Multi-item type selector
            if (identifier.rows !== undefined) {
                _dtRowSelector(out, dt, identifier.rows, fields, idFn);
            }
            if (identifier.columns !== undefined) {
                _dtColumnSelector(out, dt, identifier.columns, fields, idFn);
            }
            if (identifier.cells !== undefined) {
                _dtCellSelector(out, dt, identifier.cells, fields, idFn);
            }
        }
        else {
            // Just a rows selector
            _dtRowSelector(out, dt, identifier, fields, idFn);
        }
        return out;
    },
    id: function (data) {
        var idFn = dataGet(this.s.idSrc);
        return idFn(data);
    },
    individual: function (identifier, fieldNames) {
        var idFn = dataGet(this.s.idSrc);
        var dt = _dtApi(this.s.table);
        var fields = this.s.fields;
        var out = {};
        var forceFields;
        if (fieldNames) {
            if (!Array.isArray(fieldNames)) {
                fieldNames = [fieldNames];
            }
            forceFields = {};
            $.each(fieldNames, function (i, name) {
                forceFields[name] = fields[name];
            });
        }
        _dtCellSelector(out, dt, identifier, fields, idFn, forceFields);
        return out;
    },
    prep: function (action, identifier, submit, json, store) {
        var _this = this;
        // Get the id of the rows created / edited
        if (action === 'create') {
            store.rowIds = $.map(json.data, function (row) { return dataSource$1.id.call(_this, row); });
        }
        if (action === 'edit') {
            var cancelled_1 = json.cancelled || [];
            store.rowIds = $.map(submit.data, function (val, key) {
                return !$.isEmptyObject(submit.data[key]) && // was submitted
                    $.inArray(key, cancelled_1) === -1 ? // was not cancelled on the server-side
                    key :
                    undefined;
            });
        }
        else if (action === 'remove') {
            store.cancelled = json.cancelled || [];
        }
    },
    refresh: function () {
        // Reload a table's data - used when nested data is changed
        var dt = _dtApi(this.s.table);
        dt.ajax.reload(null, false);
    },
    remove: function (identifier, fields, store) {
        // No confirmation from the server
        var that = this;
        var dt = _dtApi(this.s.table);
        var cancelled = store.cancelled;
        if (cancelled.length === 0) {
            // No rows were cancelled on the server-side, remove them all
            dt.rows(identifier).remove();
        }
        else {
            // One or more rows were cancelled, so we need to identify them
            // and not remove those rows
            var indexes_1 = [];
            dt.rows(identifier).every(function () {
                var id = dataSource$1.id.call(that, this.data());
                if ($.inArray(id, cancelled) === -1) {
                    // Don't use `remove` here - it messes up the indexes
                    indexes_1.push(this.index());
                }
            });
            dt.rows(indexes_1).remove();
        }
    }
};

/* -  -  -  -  -  -  -  -
 * HTML editor interface
 */
function _htmlId(identifier) {
    if (identifier === 'keyless') {
        return $(document);
    }
    var specific = $('[data-editor-id="' + identifier + '"]');
    if (specific.length === 0) {
        specific = typeof identifier === 'string' ?
            $(safeQueryId(identifier)) :
            $(identifier);
    }
    if (specific.length === 0) {
        throw new Error('Could not find an element with `data-editor-id` or `id` of: ' + identifier);
    }
    return specific;
}
function _htmlEl(identifier, name) {
    var context = _htmlId(identifier);
    return $('[data-editor-field="' + name + '"]', context);
}
function _htmlEls(identifier, names) {
    var out = $();
    for (var i = 0, ien = names.length; i < ien; i++) {
        out = out.add(_htmlEl(identifier, names[i]));
    }
    return out;
}
function _htmlGet(identifier, dataSrc) {
    var el = _htmlEl(identifier, dataSrc);
    return el.filter('[data-editor-value]').length ?
        el.attr('data-editor-value') :
        el.html();
}
function _htmlSet(identifier, fields, data) {
    $.each(fields, function (name, field) {
        var val = field.valFromData(data);
        if (val !== undefined) {
            var el = _htmlEl(identifier, field.dataSrc());
            if (el.filter('[data-editor-value]').length) {
                el.attr('data-editor-value', val);
            }
            else {
                el.each(function () {
                    // This is very frustrating, but in IE if you just write directly
                    // to innerHTML, and elements that are overwritten are GC'ed,
                    // even if there is a reference to them elsewhere
                    while (this.childNodes.length) {
                        this.removeChild(this.firstChild);
                    }
                })
                    .html(val);
            }
        }
    });
}
var dataSource = {
    create: function (fields, data) {
        // If there is an element with the id that has been created, then use it
        // to assign the values
        if (data) {
            var id = dataSource.id.call(this, data);
            try {
                if (_htmlId(id).length) {
                    _htmlSet(id, fields, data);
                }
            }
            catch (e) {
                // noop - use `postCreate` to add items to the DOM
            }
        }
    },
    edit: function (identifier, fields, data) {
        // Get the ids from the returned data or `keyless` if not found
        var id = dataSource.id.call(this, data) || 'keyless';
        _htmlSet(id, fields, data);
    },
    // get idSrc, fields to edit, data and node for each item
    fields: function (identifier) {
        var out = {};
        // Allow multi-point editing
        if (Array.isArray(identifier)) {
            for (var i = 0, ien = identifier.length; i < ien; i++) {
                var res = dataSource.fields.call(this, identifier[i]);
                out[identifier[i]] = res[identifier[i]];
            }
            return out;
        }
        // else
        var data = {};
        var fields = this.s.fields;
        if (!identifier) {
            identifier = 'keyless';
        }
        $.each(fields, function (name, field) {
            var val = _htmlGet(identifier, field.dataSrc());
            // If no HTML element is present, jQuery returns null. We want undefined
            field.valToData(data, val === null ? undefined : val);
        });
        out[identifier] = {
            data: data,
            fields: fields,
            idSrc: identifier,
            node: document,
            type: 'row'
        };
        return out;
    },
    id: function (data) {
        var idFn = dataGet(this.s.idSrc);
        return idFn(data);
    },
    individual: function (identifier, fieldNames) {
        var attachEl;
        // Auto detection of the field name and id
        if (identifier instanceof $ || identifier.nodeName) {
            attachEl = identifier;
            if (!fieldNames) {
                fieldNames = [$(identifier).attr('data-editor-field')];
            }
            var back = $.fn.addBack ? 'addBack' : 'andSelf';
            identifier = $(identifier).parents('[data-editor-id]')[back]().data('editor-id');
        }
        // no id given and none found
        if (!identifier) {
            identifier = 'keyless';
        }
        // no field name - cannot continue
        if (fieldNames && !Array.isArray(fieldNames)) {
            fieldNames = [fieldNames];
        }
        if (!fieldNames || fieldNames.length === 0) {
            throw new Error('Cannot automatically determine field name from data source');
        }
        var out = dataSource.fields.call(this, identifier);
        var fields = this.s.fields;
        var forceFields = {};
        $.each(fieldNames, function (i, name) {
            forceFields[name] = fields[name];
        });
        $.each(out, function (id, set) {
            set.type = 'cell';
            set.attachFields = [fieldNames];
            set.attach = attachEl ?
                $(attachEl) :
                _htmlEls(identifier, fieldNames).toArray();
            set.fields = fields;
            set.displayFields = forceFields;
        });
        return out;
    },
    initField: function (cfg) {
        // This is before the field has been initialised so can't use it API
        var label = $('[data-editor-label="' + (cfg.data || cfg.name) + '"]');
        if (!cfg.label && label.length) {
            cfg.label = label.html();
        }
    },
    remove: function (identifier, fields) {
        // If there is an element with an ID property matching the identifier,
        // remove it
        _htmlId(identifier).remove();
    }
};

/**
 * Class names that are used by Editor for its various display components.
 * A copy of this object is taken when an Editor instance is initialised, thus
 * allowing different classes to be used in different instances if required.
 * Class name changes can be useful for easy integration with CSS frameworks,
 * for example Twitter Bootstrap.
 *
 * @namespace
 */
var classNames = {
    /**
     * Action classes - these are added to the Editor base element ("wrapper")
     * and allows styling based on the type of form view that is being employed.
     *
     * @namespace
     */
    actions: {
        /**
         * Editor is in 'create' state
         */
        create: 'DTE_Action_Create',
        /**
         * Editor is in 'edit' state
         */
        edit: 'DTE_Action_Edit',
        /**
         * Editor is in 'remove' state
         */
        remove: 'DTE_Action_Remove'
    },
    /**
     * Display body classes
     *
     * @namespace
     */
    body: {
        /**
         * Liner for the body content
         */
        content: 'DTE_Body_Content',
        /**
         * Container for the body elements
         */
        wrapper: 'DTE_Body'
    },
    /**
     * Bubble editing classes - these are used to display the bubble editor
     *
     * @namespace
     */
    bubble: {
        /**
         * Fixed background
         */
        bg: 'DTE_Bubble_Background',
        /**
         * Close button
         */
        close: 'icon close',
        /**
         * Bubble content liner
         */
        liner: 'DTE_Bubble_Liner',
        /**
         * Pointer shown which node is being edited
         */
        pointer: 'DTE_Bubble_Triangle',
        /**
         * Bubble table display wrapper, so the buttons and form can be shown
         * as table cells (via css)
         */
        table: 'DTE_Bubble_Table',
        /**
         * Bubble container element
         */
        wrapper: 'DTE DTE_Bubble'
    },
    /**
     * Field classes
     *
     * @namespace
     */
    field: {
        /**
         * Field is disabled
         */
        'disabled': 'disabled',
        /**
         * Field error state (added to the field.wrapper element when in error state
         */
        'error': 'DTE_Field_StateError',
        /**
         * Field input container
         */
        'input': 'DTE_Field_Input',
        /**
         * Input elements wrapper
         */
        'inputControl': 'DTE_Field_InputControl',
        /**
         * Field label
         */
        'label': 'DTE_Label',
        /**
         * Error information text
         */
        'msg-error': 'DTE_Field_Error',
        /**
         * General information text
         */
        'msg-info': 'DTE_Field_Info',
        /**
         * Label information text
         */
        'msg-label': 'DTE_Label_Info',
        /**
         * Live messaging (API) information text
         */
        'msg-message': 'DTE_Field_Message',
        /**
         * Multi-value information descriptive text
         */
        'multiInfo': 'multi-info',
        /**
         * Multi-value not editable (field.multiEditable)
         */
        'multiNoEdit': 'multi-noEdit',
        /**
         * Multi-value information display
         */
        'multiRestore': 'multi-restore',
        /**
         * Multi-value information display wrapper
         */
        'multiValue': 'multi-value',
        /**
         * Class prefix for the field name - field name is added to the end allowing
         * styling based on field name.
         */
        'namePrefix': 'DTE_Field_Name_',
        /**
         * Field's processing element
         */
        'processing': 'DTE_Processing_Indicator',
        /**
         * Class prefix for the field type - field type is added to the end allowing
         * styling based on field type.
         */
        'typePrefix': 'DTE_Field_Type_',
        /**
         * Container for each field
         */
        'wrapper': 'DTE_Field'
    },
    /**
     * Display footer classes
     *
     * @namespace
     */
    footer: {
        /**
         * Liner for the footer content
         */
        content: 'DTE_Footer_Content',
        /**
         * Container for the footer elements
         */
        wrapper: 'DTE_Footer'
    },
    /**
     * Form classes
     *
     * @namespace
     */
    form: {
        /**
         * Button
         */
        button: 'btn',
        /**
         * Button inside the form
         */
        buttonInternal: 'btn',
        /**
         * Buttons container
         */
        buttons: 'DTE_Form_Buttons',
        /**
         * Liner for the form content
         */
        content: 'DTE_Form_Content',
        /**
         * Global error imformation
         */
        error: 'DTE_Form_Error',
        /**
         * Global form information
         */
        info: 'DTE_Form_Info',
        /**
         * Applied to the <form> tag
         */
        tag: '',
        /**
         * Container for the form elements
         */
        wrapper: 'DTE_Form'
    },
    /**
     * Display header classes
     *
     * @namespace
     */
    header: {
        /**
         * Liner for the header content
         */
        content: 'DTE_Header_Content',
        /**
         * Container for the header elements
         */
        wrapper: 'DTE_Header'
    },
    /**
     * Inline editing classes - these are used to display the inline editor
     *
     * @namespace
     */
    inline: {
        buttons: 'DTE_Inline_Buttons',
        liner: 'DTE_Inline_Field',
        wrapper: 'DTE DTE_Inline',
    },
    /**
     * Processing classes
     *
     * @namespace
     */
    processing: {
        /**
         * Added to the base element ("wrapper") when the form is "processing"
         */
        active: 'processing',
        /**
         * Processing indicator element
         */
        indicator: 'DTE_Processing_Indicator'
    },
    /**
     * Applied to the base DIV element that contains all other Editor elements
     */
    wrapper: 'DTE'
};

var displayed$2 = false;
var cssBackgroundOpacity = 1;
var dom$1 = {
    background: $('<div class="DTED_Envelope_Background"><div></div></div>')[0],
    close: $('<div class="DTED_Envelope_Close"></div>')[0],
    content: null,
    wrapper: $('<div class="DTED DTED_Envelope_Wrapper">' +
        '<div class="DTED_Envelope_Shadow"></div>' +
        '<div class="DTED_Envelope_Container"></div>' +
        '</div>')[0]
};
function findAttachRow(editor, attach) {
    var dt = new $.fn.dataTable.Api(editor.s.table);
    // Figure out where we want to put the form display
    if (attach === 'head') {
        return dt.table(undefined).header(); // typing error in DT type file
    }
    else if (editor.s.action === 'create') {
        return dt.table(undefined).header();
    }
    else {
        return dt.row(editor.s.modifier).node();
    }
}
function heightCalc$1(dte) {
    // Set the max-height for the form content
    var header = $('div.DTE_Header', dom$1.wrapper).outerHeight();
    var footer = $('div.DTE_Footer', dom$1.wrapper).outerHeight();
    var maxHeight = $(window).height() - (envelope.conf.windowPadding * 2) -
        header - footer;
    $('div.DTE_Body_Content', dom$1.wrapper).css('maxHeight', maxHeight);
    return $(dte.dom.wrapper).outerHeight();
}
function hide$2(dte, callback) {
    if (!callback) {
        callback = function () { };
    }
    if (displayed$2) {
        $(dom$1.content).animate({
            top: -(dom$1.content.offsetHeight + 50)
        }, 600, function () {
            $([dom$1.wrapper, dom$1.background]).fadeOut('normal', function () {
                $(this).detach();
                callback();
            });
        });
        displayed$2 = false;
    }
}
function init$1() {
    dom$1.content = $('div.DTED_Envelope_Container', dom$1.wrapper)[0];
    cssBackgroundOpacity = $(dom$1.background).css('opacity');
}
function show$2(dte, callback) {
    if (!callback) {
        callback = function () { };
    }
    $('body')
        .append(dom$1.background)
        .append(dom$1.wrapper);
    // Adjust size for the content
    dom$1.content.style.height = 'auto';
    if (!displayed$2) {
        var style = dom$1.wrapper.style;
        style.opacity = '0';
        style.display = 'block';
        var height = heightCalc$1(dte);
        var targetRow = findAttachRow(dte, envelope.conf.attach);
        var width = targetRow.offsetWidth;
        style.display = 'none';
        style.opacity = '1';
        // Prep the display
        dom$1.wrapper.style.width = width + 'px';
        dom$1.wrapper.style.marginLeft = -(width / 2) + 'px';
        dom$1.wrapper.style.top = ($(targetRow).offset().top + targetRow.offsetHeight) + 'px';
        dom$1.content.style.top = ((-1 * height) - 20) + 'px';
        // Start animating in the background
        dom$1.background.style.opacity = '0';
        dom$1.background.style.display = 'block';
        $(dom$1.background).animate({
            opacity: cssBackgroundOpacity
        }, 'normal');
        // Animate in the display
        $(dom$1.wrapper).fadeIn();
        $(dom$1.content).animate({ top: 0 }, 600, callback);
    }
    // Event handlers
    $(dom$1.close)
        .attr('title', dte.i18n.close)
        .off('click.DTED_Envelope')
        .on('click.DTED_Envelope', function (e) {
        dte.close();
    });
    $(dom$1.background)
        .off('click.DTED_Envelope')
        .on('click.DTED_Envelope', function (e) {
        dte.background();
    });
    $('div.DTED_Lightbox_Content_Wrapper', dom$1.wrapper)
        .off('click.DTED_Envelope')
        .on('click.DTED_Envelope', function (e) {
        if ($(e.target).hasClass('DTED_Envelope_Content_Wrapper')) {
            dte.background();
        }
    });
    $(window)
        .off('resize.DTED_Envelope')
        .on('resize.DTED_Envelope', function () {
        heightCalc$1(dte);
    });
    displayed$2 = true;
}
var envelope = {
    close: function (dte, callback) {
        hide$2(dte, callback);
    },
    conf: {
        attach: 'row',
        windowPadding: 50
    },
    destroy: function (dte) {
        hide$2();
    },
    init: function (dte) {
        init$1();
        return envelope;
    },
    node: function (dte) {
        return dom$1.wrapper[0];
    },
    open: function (dte, append, callback) {
        $(dom$1.content).children().detach();
        dom$1.content.appendChild(append);
        dom$1.content.appendChild(dom$1.close);
        show$2(dte, callback);
    }
};

function isMobile() {
    return typeof window.orientation !== 'undefined' && window.outerWidth <= 576
        ? true
        : false;
}
var displayed$1 = false;
var ready = false;
var scrollTop = 0;
var dom = {
    background: $('<div class="DTED_Lightbox_Background"><div></div></div>'),
    close: $('<div class="DTED_Lightbox_Close"></div>'),
    content: null,
    wrapper: $('<div class="DTED DTED_Lightbox_Wrapper">' +
        '<div class="DTED_Lightbox_Container">' +
        '<div class="DTED_Lightbox_Content_Wrapper">' +
        '<div class="DTED_Lightbox_Content">' +
        '</div>' +
        '</div>' +
        '</div>' +
        '</div>')
};
function heightCalc() {
    var headerFooter = $('div.DTE_Header', dom.wrapper).outerHeight() +
        $('div.DTE_Footer', dom.wrapper).outerHeight();
    if (isMobile()) {
        $('div.DTE_Body_Content', dom.wrapper).css('maxHeight', 'calc(100vh - ' + headerFooter + 'px)');
    }
    else {
        // Set the max-height for the form content
        var maxHeight = $(window).height() - (self.conf.windowPadding * 2) - headerFooter;
        $('div.DTE_Body_Content', dom.wrapper).css('maxHeight', maxHeight);
    }
}
function hide$1(dte, callback) {
    if (!callback) {
        callback = function () { };
    }
    // Restore scroll state
    $('body').scrollTop(scrollTop);
    dte._animate(dom.wrapper, {
        opacity: 0,
        top: self.conf.offsetAni
    }, function () {
        $(this).detach();
        callback();
    });
    dte._animate(dom.background, {
        opacity: 0
    }, function () {
        $(this).detach();
    });
    displayed$1 = false;
    $(window).off('resize.DTED_Lightbox');
}
function init() {
    if (ready) {
        return;
    }
    dom.content = $('div.DTED_Lightbox_Content', dom.wrapper);
    dom.wrapper.css('opacity', 0);
    dom.background.css('opacity', 0);
    ready = true;
}
function show$1(dte, callback) {
    // Mobiles have very poor position fixed abilities, so we need to know
    // when using mobile A media query isn't good enough
    if (isMobile()) {
        $('body').addClass('DTED_Lightbox_Mobile');
    }
    $('body')
        .append(dom.background)
        .append(dom.wrapper);
    heightCalc();
    if (!displayed$1) {
        displayed$1 = true;
        dom.content.css('height', 'auto');
        dom.wrapper.css({
            top: -self.conf.offsetAni
        });
        dte._animate(dom.wrapper, {
            opacity: 1,
            top: 0
        }, callback);
        dte._animate(dom.background, {
            opacity: 1
        });
        $(window).on('resize.DTED_Lightbox', function () {
            heightCalc();
        });
        scrollTop = $('body').scrollTop();
    }
    // Event handlers - assign on show, premoving previous bindings
    dom.close
        .attr('title', dte.i18n.close)
        .off('click.DTED_Lightbox')
        .on('click.DTED_Lightbox', function (e) {
        dte.close();
    });
    dom.background
        .off('click.DTED_Lightbox')
        .on('click.DTED_Lightbox', function (e) {
        e.stopImmediatePropagation();
        dte.background();
    });
    $('div.DTED_Lightbox_Content_Wrapper', dom.wrapper)
        .off('click.DTED_Lightbox')
        .on('click.DTED_Lightbox', function (e) {
        if ($(e.target).hasClass('DTED_Lightbox_Content_Wrapper')) {
            e.stopImmediatePropagation();
            dte.background();
        }
    });
}
var self = {
    close: function (dte, callback) {
        hide$1(dte, callback);
    },
    conf: {
        offsetAni: 25,
        windowPadding: 25
    },
    destroy: function (dte) {
        if (displayed$1) {
            hide$1(dte);
        }
    },
    init: function (dte) {
        init();
        return self;
    },
    node: function (dte) {
        return dom.wrapper[0];
    },
    open: function (dte, append, callback) {
        var content = dom.content;
        content.children().detach();
        content
            .append(append)
            .append(dom.close);
        show$1(dte, callback);
    },
};

var DataTable$5 = $.fn.dataTable;
/**
 * Add a new field to the from. This is the method that is called automatically when
 * fields are given in the initialisation objects as {@link Editor.defaults.fields}.
 *
 * @memberOf Editor
 * @param {object|array} field The object that describes the field (the full
 * object is described by {@link Editor.model.field}. Note that multiple
 * fields can be given by passing in an array of field definitions.
 * @param {string} [after] Existing field to insert the new field after. This
 * can be `undefined` (insert at end), `null` (insert at start) or `string`
 * the field name to insert after.
 * @param {boolean} [reorder] INTERNAL for array adding performance only
 */
function add(cfg, after, reorder) {
    if (reorder === void 0) { reorder = true; }
    // Allow multiple fields to be added at the same time
    if (Array.isArray(cfg)) {
        // Do it in reverse to allow fields to appear in the same order given, otherwise,
        // the would appear in reverse if given an `after`
        if (after !== undefined) {
            cfg.reverse();
        }
        for (var _i = 0, cfg_1 = cfg; _i < cfg_1.length; _i++) {
            var cfgDp = cfg_1[_i];
            this.add(cfgDp, after, false);
        }
        this._displayReorder(this.order());
        return this;
    }
    var name = cfg.name;
    if (name === undefined) {
        throw new Error('Error adding field. The field requires a `name` option');
    }
    if (this.s.fields[name]) {
        throw new Error('Error adding field \'' + name + '\'. A field already exists with this name');
    }
    // Allow the data source to add / modify the field properties
    // Dev: would this be better as an event `preAddField`? And have the
    // data sources init only once, but can listen for such events? More
    // complexity, but probably more flexible...
    this._dataSource('initField', cfg);
    var editorField = new Editor.Field(cfg, this.classes.field, this);
    // If in an editing mode, we need to set the field up for the data
    if (this.s.mode) {
        var editFields = this.s.editFields;
        editorField.multiReset();
        $.each(editFields, function (idSrc, editIn) {
            var value;
            if (editIn.data) {
                value = editorField.valFromData(editIn.data);
            }
            editorField.multiSet(idSrc, value !== undefined ?
                value :
                editorField.def());
        });
    }
    this.s.fields[name] = editorField;
    if (after === undefined) {
        this.s.order.push(name);
    }
    else if (after === null) {
        this.s.order.unshift(name);
    }
    else {
        var idx = $.inArray(after, this.s.order);
        this.s.order.splice(idx + 1, 0, name);
    }
    if (reorder !== false) {
        this._displayReorder(this.order());
    }
    return this;
}
// TODO
/**
 * Get / set the Ajax configuration for the Editor instance
 *
 * @return {object|Editor} Editor instance, for chaining when used as a
 *   setter, the Ajax configuration when used as a getter.
 */
function ajax(newAjax) {
    if (newAjax) {
        this.s.ajax = newAjax;
        return this;
    }
    return this.s.ajax;
}
/**
 * Perform background activation tasks.
 *
 * This is NOT publicly documented on the Editor web-site, but rather can be
 * used by display controller plug-ins to perform the required task on
 * background activation.
 *
 * @return {Editor} Editor instance, for chaining
 */
function background() {
    var onBackground = this.s.editOpts.onBackground;
    if (typeof onBackground === 'function') {
        onBackground(this);
    }
    else if (onBackground === 'blur') {
        this.blur();
    }
    else if (onBackground === 'close') {
        this.close();
    }
    else if (onBackground === 'submit') {
        this.submit();
    }
    return this;
}
/**
 * Blur the currently displayed editor.
 *
 * A blur is different from a `close()` in that it might cause either a close or
 * the form to be submitted. A typical example of a blur would be clicking on
 * the background of the bubble or main editing forms - i.e. it might be a
 * close, or it might submit depending upon the configuration, while a click on
 * the close box is a very definite close.
 *
 * @return {Editor} Editor instance, for chaining
 */
function blur() {
    this._blur();
    return this;
}
function bubble(cells, fieldNames, showIn, opts) {
    var _this = this;
    var that = this;
    // Some other field in inline edit mode?
    if (this._tidy(function () {
        that.bubble(cells, fieldNames, opts);
    })) {
        return this;
    }
    // Argument shifting
    if ($.isPlainObject(fieldNames)) {
        opts = fieldNames;
        fieldNames = undefined;
        showIn = true;
    }
    else if (typeof fieldNames === 'boolean') {
        showIn = fieldNames;
        fieldNames = undefined;
        opts = undefined;
    }
    if ($.isPlainObject(showIn)) {
        opts = showIn;
        showIn = true;
    }
    if (showIn === undefined) {
        showIn = true;
    }
    opts = $.extend({}, this.s.formOptions.bubble, opts);
    var editFields = this._dataSource('individual', cells, fieldNames);
    this._edit(cells, editFields, 'bubble', opts, function () {
        var namespace = _this._formOptions(opts);
        var ret = _this._preopen('bubble');
        if (!ret) {
            return _this;
        }
        // Keep the bubble in position on resize
        $(window).on('resize.' + namespace, function () {
            _this.bubblePosition();
        });
        // Store the nodes this are being used so the bubble can be positioned
        var nodes = [];
        _this.s.bubbleNodes = nodes.concat.apply(nodes, pluck(editFields, 'attach'));
        // Create container display
        var classes = _this.classes.bubble;
        var backgroundNode = $('<div class="' + classes.bg + '"><div></div></div>');
        var container = $('<div class="' + classes.wrapper + '">' +
            '<div class="' + classes.liner + '">' +
            '<div class="' + classes.table + '">' +
            '<div class="' + classes.close + '" title="' + _this.i18n.close + '"></div>' +
            '<div class="DTE_Processing_Indicator"><span></div>' +
            '</div>' +
            '</div>' +
            '<div class="' + classes.pointer + '"></div>' +
            '</div>');
        if (showIn) {
            container.appendTo('body');
            backgroundNode.appendTo('body');
        }
        var liner = container.children().eq(0);
        var tableNode = liner.children();
        var closeNode = tableNode.children();
        liner.append(_this.dom.formError);
        tableNode.prepend(_this.dom.form);
        if (opts.message) {
            liner.prepend(_this.dom.formInfo);
        }
        if (opts.title) {
            liner.prepend(_this.dom.header);
        }
        if (opts.buttons) {
            tableNode.append(_this.dom.buttons);
        }
        // Need to use a small anon function here as the animate callback is the scope
        // of the element being animated and TS won't allow access to the private methods
        var finish = function () {
            _this._clearDynamicInfo();
            _this._event('closed', ['bubble']);
        };
        var pair = $().add(container).add(backgroundNode);
        _this._closeReg(function (submitComplete) {
            _this._animate(pair, { opacity: 0 }, function () {
                if (this === container[0]) {
                    pair.detach();
                    $(window).off('resize.' + namespace);
                    finish();
                }
            });
        });
        // Close event handlers
        backgroundNode.on('click', function () {
            _this.blur();
        });
        closeNode.on('click', function () {
            _this._close();
        });
        _this.bubblePosition();
        _this._postopen('bubble', false);
        var opened = function () {
            _this._focus(_this.s.includeFields, opts.focus);
            _this._event('opened', ['bubble', _this.s.action]);
        };
        _this._animate(pair, { opacity: 1 }, function () {
            // Otherwise the callback will happen on both elements
            if (this === container[0]) {
                opened();
            }
        });
    });
    return this;
}
/**
 * Reposition the editing bubble (`bubble()`) when it is visible. This can be
 * used to update the bubble position if other elements on the page change
 * position. Editor will automatically call this method on window resize.
 *
 * @return {Editor} Editor instance, for chaining
 */
function bubblePosition() {
    var wrapper = $('div.DTE_Bubble');
    var liner = $('div.DTE_Bubble_Liner');
    var nodes = this.s.bubbleNodes;
    // Average the node positions to insert the container
    var position = { bottom: 0, left: 0, right: 0, top: 0 };
    $.each(nodes, function (i, nodeIn) {
        var pos = $(nodeIn).offset();
        nodeIn = $(nodeIn).get(0);
        position.top += pos.top;
        position.left += pos.left;
        position.right += pos.left + nodeIn.offsetWidth;
        position.bottom += pos.top + nodeIn.offsetHeight;
    });
    position.top /= nodes.length;
    position.left /= nodes.length;
    position.right /= nodes.length;
    position.bottom /= nodes.length;
    var top = position.top;
    var left = (position.left + position.right) / 2;
    var width = liner.outerWidth();
    var visLeft = left - (width / 2);
    var visRight = visLeft + width;
    var docWidth = $(window).width();
    var padding = 15;
    this.classes.bubble;
    wrapper.css({
        left: left,
        top: top
    });
    // Correct for overflow from the top of the document by positioning below
    // the field if needed
    if (liner.length && liner.offset().top < 0) {
        wrapper
            .css('top', position.bottom)
            .addClass('below');
    }
    else {
        wrapper.removeClass('below');
    }
    // Attempt to correct for overflow to the right of the document
    if (visRight + padding > docWidth) {
        var diff = visRight - docWidth;
        // If left overflowing, that takes priority
        liner.css('left', visLeft < padding ?
            -(visLeft - padding) :
            -(diff + padding));
    }
    else {
        // Correct overflow to the left
        liner.css('left', visLeft < padding ? -(visLeft - padding) : 0);
    }
    return this;
}
/**
 * Setup the buttons that will be shown in the footer of the form - calling this
 * method will replace any buttons which are currently shown in the form.
 *
 * @param {array|object} buttonsIn A single button definition to add to the form or
 * an array of objects with the button definitions to add more than one button.
 * The options for the button definitions are fully defined by the
 * {@link Editor.models.button} object.
 * @param {string} buttons.text The text to put into the button. This can be any
 * HTML string you wish as it will be rendered as HTML (allowing images etc to
 * be shown inside the button).
 * @param {function} [buttons.action] Callback function which the button is activated.
 * For example for a 'submit' button you would call the {@link Editor#submit} method,
 * while for a cancel button you would call the {@link Editor#close} method. Note that
 * the function is executed in the scope of the Editor instance, so you can call
 * the Editor's API methods using the `this` keyword.
 * @param {string} [buttons.className] The CSS class(es) to apply to the button
 * which can be useful for styling buttons which perform different functions
 * each with a distinctive visual appearance.
 * @return {Editor} Editor instance, for chaining
 */
function buttons(buttonsIn) {
    var _this = this;
    if (buttonsIn === '_basic') {
        // Special string to create a basic button - undocumented
        buttonsIn = [{
                action: function () {
                    this.submit();
                },
                text: this.i18n[this.s.action].submit
            }];
    }
    else if (!Array.isArray(buttonsIn)) {
        // Allow a single button to be passed in as an object with an array
        buttonsIn = [buttonsIn];
    }
    $(this.dom.buttons).empty();
    $.each(buttonsIn, function (i, btn) {
        if (typeof btn === 'string') {
            btn = {
                action: function () {
                    this.submit();
                },
                text: btn
            };
        }
        var text = btn.text || btn.label;
        var action = btn.action || btn.fn;
        var attr = btn.attr || {};
        $('<button></button>', {
            class: _this.classes.form.button + (btn.className ? ' ' + btn.className : '')
        })
            .html(typeof text === 'function' ?
            text(_this) :
            text || '')
            .attr('tabindex', btn.tabIndex !== undefined ? btn.tabIndex : 0)
            .attr(attr)
            .on('keyup', function (e) {
            if (e.which === 13 && action) {
                action.call(_this);
            }
        })
            .on('keypress', function (e) {
            // Stop the browser activating the click event - if we don't
            // have this and the Ajax return is fast, the keyup in
            // `_formOptions()` might trigger another submit
            if (e.which === 13) {
                e.preventDefault();
            }
        })
            .on('click', function (e) {
            e.preventDefault();
            if (action) {
                action.call(_this, e);
            }
        })
            .appendTo(_this.dom.buttons);
    });
    return this;
}
/**
 * Remove fields from the form (fields are those that have been added using the
 * {@link Editor#add} method or the `fields` initialisation option). A single,
 * multiple or all fields can be removed at a time based on the passed parameter.
 * Fields are identified by the `name` property that was given to each field
 * when added to the form.
 *
 * @param {string|array} [fieldName] Field or fields to remove from the form. If
 * not given then all fields are removed from the form. If given as a string
 * then the single matching field will be removed. If given as an array of
 * strings, then all matching fields will be removed.
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Clear the form of current fields and then add a new field
 * // before displaying a 'create' display
 * editor.clear();
 * editor.add( {
 *  "label": "User name",
 *  "name": "username"
 * } );
 * editor.create( "Create user" );
 *
 * @example
 * // Remove an individual field
 * editor.clear( "username" );
 *
 * @example
 * // Remove multiple fields
 * editor.clear( [ "first_name", "last_name" ] );
 */
function clear(fieldName) {
    var that = this;
    var sFields = this.s.fields;
    if (typeof fieldName === 'string') {
        // Remove an individual form element
        that.field(fieldName).destroy();
        delete sFields[fieldName];
        var orderIdx = $.inArray(fieldName, this.s.order);
        this.s.order.splice(orderIdx, 1);
        var includeIdx = $.inArray(fieldName, this.s.includeFields);
        if (includeIdx !== -1) {
            this.s.includeFields.splice(includeIdx, 1);
        }
    }
    else {
        $.each(this._fieldNames(fieldName), function (i, name) {
            that.clear(name);
        });
    }
    return this;
}
/**
 * Close the form display.
 *
 * Note that `close()` will close any of the three Editor form types (main,
 * bubble and inline).
 *
 * @return {Editor} Editor instance, for chaining
 */
function close() {
    this._close(false);
    return this;
}
/**
 * Create a new record - show the form that allows the user to enter information
 * for a new row and then subsequently submit that data.
 *
 * @param {boolean} [show=true] Show the form or not.
 *
 * @example
 * // Show the create form with a submit button
 * editor
 *  .title( 'Add new record' )
 *  .buttons( {
 *    "label": "Save",
 *    "fn": function () {
 *      this.submit();
 *    }
 *  } )
 *  .create();
 *
 * @example
 * // Don't show the form and automatically submit it after programmatically
 * // setting the values of fields (and using the field defaults)
 * editor
 *  create()
 *  set( 'name',   'Test user' )
 *  set( 'access', 'Read only' )
 *  submit();
 */
function create(arg1, arg2, arg3, arg4) {
    var _this = this;
    var that = this;
    var sFields = this.s.fields;
    var count = 1;
    // Some other field in inline edit mode?
    if (this._tidy(function () {
        that.create(arg1, arg2, arg3, arg4);
    })) {
        return this;
    }
    // Multi-row creation support (only supported by the 1.3+ style of calling
    // this method, so a max of three arguments
    if (typeof arg1 === 'number') {
        count = arg1;
        arg1 = arg2;
        arg2 = arg3;
    }
    // Set up the edit fields for submission
    this.s.editFields = {};
    for (var i = 0; i < count; i++) {
        this.s.editFields[i] = {
            fields: this.s.fields
        };
    }
    var argOpts = this._crudArgs(arg1, arg2, arg3, arg4);
    this.s.mode = 'main';
    this.s.action = 'create';
    this.s.modifier = null;
    this.dom.form.style.display = 'block';
    this._actionClass();
    // Allow all fields to be displayed for the create form
    this._displayReorder(this.fields());
    // Set the default for the fields
    $.each(sFields, function (name, fieldIn) {
        fieldIn.multiReset();
        // Set a value marker for each multi, so the field
        // knows what the id's are (ints in this case)
        for (var i = 0; i < count; i++) {
            fieldIn.multiSet(i, fieldIn.def());
        }
        fieldIn.set(fieldIn.def());
    });
    this._event('initCreate', null, function () {
        _this._assembleMain();
        _this._formOptions(argOpts.opts);
        argOpts.maybeOpen();
    });
    return this;
}
/**
 * Remove dependent links from a field
 *
 * @param {string} parent The name of the field to remove the existing dependencies
 * @return {Editor} Editor instance, for chaining
 */
function undependent(parent) {
    if (Array.isArray(parent)) {
        for (var i = 0, ien = parent.length; i < ien; i++) {
            this.undependent(parent[i]);
        }
        return this;
    }
    $(this.field(parent).node()).off('.edep');
    return this;
}
/**
 * Create a dependent link between two or more fields. This method is used to
 * listen for a change in a field's value which will trigger updating of the
 * form. This update can consist of updating an options list, changing values
 * or making fields hidden / visible.
 *
 * @param {string} parent The name of the field to listen to changes from
 * @param {string|object|function} url Callback definition. This can be:
 * * A string, which will be used as a URL to submit the request for update to
 * * An object, which is used to extend an Ajax object for the request. The
 * `url` parameter must be specified.
 * * A function, which is used as a callback, allowing non-ajax updates.
 * @return {Editor} Editor instance, for chaining
 */
function dependent(parent, url, opts) {
    var _this = this;
    if (Array.isArray(parent)) {
        for (var i = 0, ien = parent.length; i < ien; i++) {
            this.dependent(parent[i], url, opts);
        }
        return this;
    }
    var that = this;
    var parentField = this.field(parent);
    var ajaxOpts = {
        dataType: 'json',
        type: 'POST'
    };
    opts = $.extend({
        data: null,
        event: 'change',
        postUpdate: null,
        preUpdate: null
    }, opts);
    var update = function (json) {
        if (opts.preUpdate) {
            opts.preUpdate(json);
        }
        // Field specific
        $.each({
            errors: 'error',
            labels: 'label',
            messages: 'message',
            options: 'update',
            values: 'val'
        }, function (jsonProp, fieldFn) {
            if (json[jsonProp]) {
                $.each(json[jsonProp], function (fieldIn, valIn) {
                    that.field(fieldIn)[fieldFn](valIn);
                });
            }
        });
        // Form level
        $.each(['hide', 'show', 'enable', 'disable'], function (i, key) {
            if (json[key]) {
                that[key](json[key], json.animate);
            }
        });
        if (opts.postUpdate) {
            opts.postUpdate(json);
        }
        parentField.processing(false);
    };
    // Use a delegate handler to account for field elements which are added and
    // removed after `depenedent` has been called
    $(parentField.node()).on(opts.event + '.edep', function (e) {
        // Make sure that it was one of the field's elements that triggered the ev
        if ($(parentField.node()).find(e.target).length === 0) {
            return;
        }
        parentField.processing(true);
        var data = {};
        data.rows = _this.s.editFields ?
            pluck(_this.s.editFields, 'data') :
            null;
        data.row = data.rows ?
            data.rows[0] :
            null;
        data.values = _this.val();
        if (opts.data) {
            var ret = opts.data(data);
            if (ret) {
                opts.data = ret;
            }
        }
        if (typeof url === 'function') {
            var o = url.call(_this, parentField.val(), data, update, e);
            if (o) {
                if (typeof o === 'object' && typeof o.then === 'function') {
                    o.then(function (resolved) {
                        if (resolved) {
                            update(resolved);
                        }
                    });
                }
                else {
                    update(o);
                }
            }
        }
        else {
            if ($.isPlainObject(url)) {
                $.extend(ajaxOpts, url);
            }
            else {
                ajaxOpts.url = url;
            }
            $.ajax($.extend(ajaxOpts, {
                data: data,
                success: update
            }));
        }
    });
    return this;
}
/**
 * Destroy the Editor instance, cleaning up fields, display and event handlers
 */
function destroy() {
    if (this.s.displayed) {
        this.close();
    }
    this.clear();
    // Stick the template back into the document so it can be reused
    if (this.s.template) {
        $('body').append(this.s.template);
    }
    var controller = this.s.displayController;
    if (controller.destroy) {
        controller.destroy(this);
    }
    $(document).off('.dte' + this.s.unique);
    this.dom = null;
    this.s = null;
}
/**
 * Disable one or more field inputs, disallowing subsequent user interaction with the
 * fields until they are re-enabled.
 *
 * @param {string|array} name The field name (from the `name` parameter given when
 * originally setting up the field) to disable, or an array of field names to disable
 * multiple fields with a single call.
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Show a 'create' record form, but with a field disabled
 * editor.disable( 'account_type' );
 * editor.create( 'Add new user', {
 *  "label": "Save",
 *  "fn": function () { this.submit(); }
 * } );
 *
 * @example
 * // Disable multiple fields by using an array of field names
 * editor.disable( ['account_type', 'access_level'] );
 */
function disable(name) {
    var that = this;
    $.each(this._fieldNames(name), function (i, n) {
        that.field(n).disable();
    });
    return this;
}
function display(showIn) {
    if (showIn === undefined) {
        return this.s.displayed;
    }
    return this[showIn ? 'open' : 'close']();
}
/**
 * Fields which are currently displayed
 *
 * @return {string[]} Field names that are shown
 */
function displayed() {
    return $.map(this.s.fields, function (fieldIn, name) {
        return fieldIn.displayed() ? name : null;
    });
}
/**
 * Get display controller node
 *
 * @return {node} Display controller host element
 */
function displayNode() {
    return this.s.displayController.node(this);
}
/**
 * Edit a record - show the form, pre-populated with the data that is in the given
 * DataTables row, that allows the user to enter information for the row to be modified
 * and then subsequently submit that data.
 *
 * @param {node} items The TR element from the DataTable that is to be edited
 * @param {boolean} [show=true] Show the form or not.
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Show the edit form for the first row in the DataTable with a submit button
 * editor.edit( $('#example tbody tr:eq(0)')[0], 'Edit record', {
 *  "label": "Update",
 *  "fn": function () { this.submit(); }
 * } );
 *
 * @example
 * // Use the title and buttons API methods to show an edit form (this provides
 * // the same result as example above, but is a different way of achieving it
 * editor.title( 'Edit record' );
 * editor.buttons( {
 *  "label": "Update",
 *  "fn": function () { this.submit(); }
 * } );
 * editor.edit( $('#example tbody tr:eq(0)')[0] );
 *
 * @example
 * // Automatically submit an edit without showing the user the form
 * editor.edit( TRnode, null, null, false );
 * editor.set( 'name', 'Updated name' );
 * editor.set( 'access', 'Read only' );
 * editor.submit();
 */
function edit(items, arg1, arg2, arg3, arg4) {
    var _this = this;
    var that = this;
    // Some other field in inline edit mode?
    if (this._tidy(function () {
        that.edit(items, arg1, arg2, arg3, arg4);
    })) {
        return this;
    }
    var argOpts = this._crudArgs(arg1, arg2, arg3, arg4);
    this._edit(items, this._dataSource('fields', items), 'main', argOpts.opts, function () {
        _this._assembleMain();
        _this._formOptions(argOpts.opts);
        argOpts.maybeOpen();
    });
    return this;
}
/**
 * Enable one or more field inputs, restoring user interaction with the fields.
 *
 * @param {string|array} name The field name (from the `name` parameter given when
 * originally setting up the field) to enable, or an array of field names to enable
 * multiple fields with a single call.
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Show a 'create' form with buttons which will enable and disable certain fields
 * editor.create( 'Add new user', [
 *  {
 *    "label": "User name only",
 *    "fn": function () {
 *      this.enable('username');
 *      this.disable( ['first_name', 'last_name'] );
 *    }
 *  }, {
 *    "label": "Name based",
 *    "fn": function () {
 *      this.disable('username');
 *      this.enable( ['first_name', 'last_name'] );
 *    }
 *  }, {
 *    "label": "Submit",
 *    "fn": function () { this.submit(); }
 *  }
 * );
 */
function enable(name) {
    var that = this;
    $.each(this._fieldNames(name), function (i, n) {
        that.field(n).enable();
    });
    return this;
}
function error$1(name, msg) {
    var wrapper = $(this.dom.wrapper);
    if (msg === undefined) {
        // Global error
        this._message(this.dom.formError, name, true, function () {
            wrapper.toggleClass('inFormError', name !== undefined && name !== '');
        });
        // Store the error message so `inError` can check if there is an
        // error or not without considering animation
        this.s.globalError = name;
    }
    else {
        // Field error
        this.field(name).error(msg);
    }
    return this;
}
/**
 * Get a field object, configured for a named field, which can then be
 * manipulated through its API. This function effectively acts as a
 * proxy to the field extensions, allowing easy access to the methods
 * for a named field. The methods that are available depend upon the field
 * type plug-in for Editor.
 *
 * @param {string} name Field name to be obtained
 * @return {Editor.Field} Field instance
 *
 * @example
 * // Update the values available in a select list
 * editor.field('island').update( [
 *   'Lewis and Harris',
 *   'South Uist',
 *   'North Uist',
 *   'Benbecula',
 *   'Barra'
 * ] );
 *
 * @example
 * // Equivalent calls
 * editor.field('name').set('John Smith');
 *
 * // results in the same action as:
 * editor.set('John Smith');
 */
function field(name) {
    var sFields = this.s.fields;
    if (!sFields[name]) {
        throw new Error('Unknown field name - ' + name);
    }
    return sFields[name];
}
/**
 * Get a list of the fields that are used by the Editor instance.
 *
 * @returns {string[]} Array of field names
 *
 * @example
 * // Get current fields and move first item to the end
 * var fields = editor.fields();
 * var first = fields.shift();
 * fields.push( first );
 * editor.order( fields );
 */
function fields() {
    return $.map(this.s.fields, function (fieldIn, name) {
        return name;
    });
}
/**
 * Get data object for a file from a table and id
 *
 * @param  {string} name Table name
 * @param  {string|number} id Primary key identifier
 * @return {object} Table information
 */
function file(name, id) {
    var tableFromFile = this.files(name); // can throw. `this` will be Editor or
    var fileFromTable = tableFromFile[id]; //  DataTables.Api context. Both work.
    if (!fileFromTable) {
        throw new Error('Unknown file id ' + id + ' in table ' + name);
    }
    return tableFromFile[id];
}
/**
 * Get data objects for available files
 *
 * @param  {string} [name] Table name
 * @return {object} Table array
 */
function files(name) {
    if (!name) {
        return Editor.files;
    }
    var editorTable = Editor.files[name];
    if (!editorTable) {
        throw new Error('Unknown file table name: ' + name);
    }
    return editorTable;
}
/**
 * Get the value of a field
 *
 * @param {string|array} [name] The field name (from the `name` parameter given
 * when originally setting up the field) to disable. If not given, then an
 * object of fields is returned, with the value of each field from the
 * instance represented in the array (the object properties are the field
 * names). Also an array of field names can be given to get a collection of
 * data from the form.
 * @returns {*|object} Value from the named field
 *
 * @example
 * // Client-side validation - check that a field has been given a value
 * // before submitting the form
 * editor.create( 'Add new user', {
 *  "label": "Submit",
 *  "fn": function () {
 *    if ( this.get('username') === '' ) {
 *      this.error( 'username', 'A user name is required' );
 *      return;
 *    }
 *    this.submit();
 *  }
 * } );
 */
function get(name) {
    var that = this;
    if (!name) {
        name = this.fields();
    }
    if (Array.isArray(name)) {
        var out_1 = {};
        $.each(name, function (i, n) {
            out_1[n] = that.field(n).get();
        });
        return out_1;
    }
    return this.field(name).get();
}
/**
 * Remove a field from the form display. Note that the field will still be submitted
 * with the other fields in the form, but it simply won't be visible to the user.
 *
 * @param {string|array} [name] The field name (from the `name` parameter given when
 * originally setting up the field) to hide or an array of names. If not given then all
 * fields are hidden.
 * @param {boolean} [animate=true] Animate if visible
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Show a 'create' record form, but with some fields hidden
 * editor.hide( 'account_type' );
 * editor.hide( 'access_level' );
 * editor.create( 'Add new user', {
 *  "label": "Save",
 *  "fn": function () { this.submit(); }
 * } );
 *
 * @example
 * // Show a single field by hiding all and then showing one
 * editor.hide();
 * editor.show('access_type');
 */
function hide(names, animate) {
    var that = this;
    $.each(this._fieldNames(names), function (i, n) {
        that.field(n).hide(animate);
    });
    return this;
}
/**
 * Get the ids of the rows being edited
 */
function ids(includeHash) {
    if (includeHash === void 0) { includeHash = false; }
    return $.map(this.s.editFields, function (editIn, idSrc) {
        return includeHash === true ?
            '#' + idSrc :
            idSrc;
    });
}
/**
 * Determine if there is an error state in the form, either the form's global
 * error message, or one or more fields.
 *
 * @param {string|array|undefined} [inNames] The field names to check. All
 * fields checked if undefined.
 * @return {boolean} `true` if there is an error in the form
 */
function inError(inNames) {
    $(this.dom.formError);
    // Is there a global error?
    if (this.s.globalError) {
        return true;
    }
    // Field specific
    var names = this._fieldNames(inNames);
    for (var i = 0, ien = names.length; i < ien; i++) {
        if (this.field(names[i]).inError()) {
            return true;
        }
    }
    return false;
}
/**
 * Inline editing. This method provides a method to allow
 * end users to very quickly edit fields in place. For example, a user could
 * simply click on a cell in a table, the contents of which would be replaced
 * with the editing input field for that cell.
 *
 * @param {string|node|DataTables.Api|cell-selector} cell The cell or field to
 * be edited (note that for table editing this must be a cell - for standalone
 * editing it can also be the field name to edit).
 * @param {string} [fieldName] The field name to be edited. This parameter is
 * optional. If not provided, Editor will attempt to resolve the correct field
 * from the cell / element given as the first parameter. If it is unable to do
 * so, it will throw an error.
 * @param {object} [opts] Inline editing options - see the `form-options` type
 * @return {Editor} Editor instance, for chaining
 */
function inline(cell, fieldName, opts) {
    var _this = this;
    var that = this;
    // Argument shifting
    if ($.isPlainObject(fieldName)) {
        opts = fieldName;
        fieldName = undefined;
    }
    opts = $.extend({}, this.s.formOptions.inline, opts);
    var editFields = this._dataSource('individual', cell, fieldName);
    var keys = Object.keys(editFields);
    // Only a single row
    if (keys.length > 1) {
        throw new Error('Cannot edit more than one row inline at a time');
    }
    var editRow = editFields[keys[0]];
    // Remap so easier to use
    var hosts = [];
    for (var _i = 0, _a = editRow.attach; _i < _a.length; _i++) {
        var row = _a[_i];
        hosts.push(row);
    }
    // Already in edit mode for this cell?
    if ($('div.DTE_Field', hosts).length) {
        return this;
    }
    // Some other field in inline edit mode?
    if (this._tidy(function () {
        that.inline(cell, fieldName, opts);
    })) {
        return this;
    }
    // Start a full row edit, but don't display - we will be showing the field
    this._edit(cell, editFields, 'inline', opts, function () {
        _this._inline(editFields, opts);
    });
    return this;
}
/**
 * Inline creation of data.
 */
function inlineCreate(insertPoint, opts) {
    var _this = this;
    // Argument juggling - allow no insert point, just options
    if ($.isPlainObject(insertPoint)) {
        opts = insertPoint;
        insertPoint = null;
    }
    if (this._tidy(function () {
        _this.inlineCreate(insertPoint, opts);
    })) {
        return this;
    }
    // Set the default for the fields
    $.each(this.s.fields, function (name, fieldIn) {
        fieldIn.multiReset();
        fieldIn.multiSet(0, fieldIn.def());
        fieldIn.set(fieldIn.def());
    });
    this.s.mode = 'main';
    this.s.action = 'create';
    this.s.modifier = null;
    this.s.editFields = this._dataSource('fakeRow', insertPoint);
    opts = $.extend({}, this.s.formOptions.inline, opts);
    this._actionClass();
    this._inline(this.s.editFields, opts, function () {
        // When the form is closed (cancelled or submitted) we need to remove the
        // fake row
        _this._dataSource('fakeRowEnd');
    });
    this._event('initCreate', null);
    return this;
}
/**
 * Show an information message for the form as a whole, or for an individual
 * field. This can be used to provide helpful information to a user about an
 * individual field, or more typically the form (for example when deleting
 * a record and asking for confirmation).
 *
 * @param {string} [name] The name of the field to show the message for. If not
 * given then a global message is shown for the form
 * @param {string|function} msg The message to show
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Show a global message for a 'create' form
 * editor.message( 'Add a new user to the database by completing the fields below' );
 * editor.create( 'Add new user', {
 *  "label": "Submit",
 *  "fn": function () { this.submit(); }
 * } );
 *
 * @example
 * // Show a message for an individual field when a 'help' icon is clicked on
 * $('#user_help').click( function () {
 *  editor.message( 'user', 'The user name is what the system user will login with' );
 * } );
 */
function message(name, msg) {
    if (msg === undefined) {
        // Global message
        this._message(this.dom.formInfo, name);
    }
    else {
        // Field message
        this.field(name).message(msg);
    }
    return this;
}
/**
 * Get which mode of operation the Editor form is in
 *
 * @return {string} `create`, `edit`, `remove` or `null` if no active state.
 */
function mode(modeIn) {
    if (!modeIn) {
        return this.s.action;
    }
    if (!this.s.action) {
        throw new Error('Not currently in an editing mode');
    }
    else if (this.s.action === 'create' && modeIn !== 'create') {
        throw new Error('Changing from create mode is not supported');
    }
    this.s.action = modeIn;
    return this;
}
/**
 * Get the modifier that was used to trigger the edit or delete action.
 *
 * @return {*} The identifier that was used for the editing / remove method
 * called.
 */
function modifier() {
    return this.s.modifier;
}
/**
 * Get the values from one or more fields, taking into account multiple data
 * points being edited at the same time.
 *
 * @param  {string|array} fieldNames A single field name or an array of field
 * names.
 * @return {object} If a string is given as the first parameter an object that
 * contains the value for each row being edited is returned. If an array is
 * given, then the object has the field names as the parameter name and the
 * value is the value object with values for each row being edited.
 */
function multiGet(fieldNames) {
    var that = this;
    if (fieldNames === undefined) {
        fieldNames = this.fields();
    }
    if (Array.isArray(fieldNames)) {
        var out_2 = {};
        $.each(fieldNames, function (i, name) {
            out_2[name] = that.field(name).multiGet();
        });
        return out_2;
    }
    // String
    return this.field(fieldNames).multiGet();
}
/**
 * Set the values for one or more fields, taking into account multiple data
 * points being edited at the same time.
 *
 * @param  {object|string} fieldNames The name of the field to set, or an object
 * with the field names as the parameters that contains the value object to
 * set for each field.
 * @param  {*} [valIn] Value to set if first parameter is given as a string.
 * Otherwise it is ignored.
 * @return {Editor} Editor instance, for chaining
 */
function multiSet(fieldNames, valIn) {
    var that = this;
    if ($.isPlainObject(fieldNames) && valIn === undefined) {
        $.each(fieldNames, function (name, value) {
            that.field(name).multiSet(value);
        });
    }
    else {
        this.field(fieldNames).multiSet(valIn);
    }
    return this;
}
/**
 * Get the container node for an individual field.
 *
 * @param {string|array} name The field name (from the `name` parameter given
 * when originally setting up the field) to get the DOM node for.
 * @return {node|array} Field container node
 *
 * @example
 * // Dynamically add a class to a field's container
 * $(editor.node( 'account_type' )).addClass( 'account' );
 */
function node(name) {
    var that = this;
    if (!name) {
        name = this.order();
    }
    return Array.isArray(name) ?
        $.map(name, function (n) {
            return that.field(n).node();
        }) :
        this.field(name).node();
}
/**
 * Remove a bound event listener to the editor instance. This method provides a
 * shorthand way of binding jQuery events that would be the same as writing
 * `$(editor).off(...)` for convenience.
 *
 * @param {string} name Event name to remove the listeners for - event names are
 * defined by {@link Editor}.
 * @param {function} [fn] The function to remove. If not given, all functions which
 * are assigned to the given event name will be removed.
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Add an event to alert when the form is shown and then remove the listener
 * // so it will only fire once
 * editor.on( 'open', function () {
 *  alert('Form displayed!');
 *  editor.off( 'open' );
 * } );
 */
function off(name, fn) {
    $(this).off(this._eventName(name), fn);
    return this;
}
/**
 * Listen for an event which is fired off by Editor when it performs certain
 * actions. This method provides a shorthand way of binding jQuery events that
 * would be the same as writing  `$(editor).on(...)` for convenience.
 *
 * @param {string} name Event name to add the listener for - event names are
 * defined by {@link Editor}.
 * @param {function} fn The function to run when the event is triggered.
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Log events on the console when they occur
 * editor.on( 'open', function () { console.log( 'Form opened' ); } );
 * editor.on( 'close', function () { console.log( 'Form closed' ); } );
 * editor.on( 'submit', function () { console.log( 'Form submitted' ); } );
 */
function on(name, fn) {
    $(this).on(this._eventName(name), fn);
    return this;
}
/**
 * Listen for a single event event which is fired off by Editor when it performs
 * certain actions. This method provides a shorthand way of binding jQuery
 * events that would be the same as writing  `$(editor).one(...)` for
 * convenience.
 *
 * @param {string} name Event name to add the listener for - event names are
 * defined by {@link Editor}.
 * @param {function} fn The function to run when the event is triggered.
 * @return {Editor} Editor instance, for chaining
 */
function one(name, fn) {
    $(this).one(this._eventName(name), fn);
    return this;
}
/**
 * Display the main form editor to the end user in the web-browser.
 *
 * Note that the `close()` method will close any of the three Editor form types
 * (main, bubble and inline), but this method will open only the main type.
 *
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Build a 'create' form, but don't display it until some values have
 * // been set. When done, then display the form.
 * editor.create( 'Create user', {
 *  "label": "Submit",
 *  "fn": function () { this.submit(); }
 * }, false );
 * editor.set( 'name', 'Test user' );
 * editor.set( 'access', 'Read only' );
 * editor.open();
 */
function open() {
    var _this = this;
    // Insert the display elements in order
    this._displayReorder();
    // Define how to do a close
    this._closeReg(function () {
        _this._nestedClose(function () {
            _this._clearDynamicInfo();
            _this._event('closed', ['main']);
        });
    });
    // Run the standard open with common events
    var ret = this._preopen('main');
    if (!ret) {
        return this;
    }
    this._nestedOpen(function () {
        _this._focus($.map(_this.s.order, function (name) { return _this.s.fields[name]; }), _this.s.editOpts.focus);
        _this._event('opened', ['main', _this.s.action]);
    }, this.s.editOpts.nest);
    this._postopen('main', false);
    return this;
}
function order(setIn /* , ... */) {
    if (!setIn) {
        return this.s.order;
    }
    // Allow new layout to be passed in as arguments
    if (arguments.length && !Array.isArray(setIn)) {
        setIn = Array.prototype.slice.call(arguments);
    }
    // Sanity check - array must exactly match the fields we have available
    if (this.s.order.slice().sort().join('-') !== setIn.slice().sort().join('-')) {
        throw new Error('All fields, and no additional fields, must be provided for ordering.');
    }
    // Copy the new array into the order (so the reference is maintained)
    $.extend(this.s.order, setIn);
    this._displayReorder();
    return this;
}
/**
 * Remove (delete) entries from the table. The rows to remove are given as
 * either a single DOM node or an array of DOM nodes (including a jQuery
 * object).
 *
 * @param {node|array} items The row, or array of nodes, to delete
 * @param {boolean} [show=true] Show the form or not.
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Delete a given row with a message to let the user know exactly what is
 * // happening
 * editor.message( "Are you sure you want to remove this row?" );
 * editor.remove( row_to_delete, 'Delete row', {
 *  "label": "Confirm",
 *  "fn": function () { this.submit(); }
 * } );
 *
 * @example
 * // Delete the first row in a table without asking the user for confirmation
 * editor.remove( '', $('#example tbody tr:eq(0)')[0], null, false );
 * editor.submit();
 *
 * @example
 * // Delete all rows in a table with a submit button
 * editor.remove( $('#example tbody tr'), 'Delete all rows', {
 *  "label": "Delete all",
 *  "fn": function () { this.submit(); }
 * } );
 */
function remove(items, arg1, arg2, arg3, arg4) {
    var _this = this;
    var that = this;
    // Some other field in inline edit mode?
    if (this._tidy(function () {
        that.remove(items, arg1, arg2, arg3, arg4);
    })) {
        return this;
    }
    // Allow a single row node to be passed in to remove, Can't use Array.isArray
    // as we also allow array like objects to be passed in (API, jQuery)
    if (items.length === undefined) {
        items = [items];
    }
    var argOpts = this._crudArgs(arg1, arg2, arg3, arg4);
    var editFields = this._dataSource('fields', items);
    this.s.action = 'remove';
    this.s.modifier = items;
    this.s.editFields = editFields;
    this.dom.form.style.display = 'none';
    this._actionClass();
    this._event('initRemove', [
        pluck(editFields, 'node'),
        pluck(editFields, 'data'),
        items
    ], function () {
        _this._event('initMultiRemove', // undocumented and to be removed in v2
        [editFields, items], function () {
            _this._assembleMain();
            _this._formOptions(argOpts.opts);
            argOpts.maybeOpen();
            var opts = _this.s.editOpts;
            if (opts.focus !== null) {
                $('button', _this.dom.buttons).eq(opts.focus).focus();
            }
        });
    });
    return this;
}
/**
 * Set the value of a field
 *
 * @param {string|object} name The field name (from the `name` parameter given
 * when originally setting up the field) to set the value of. If given as an
 * object the object parameter name will be the value of the field to set and
 * the value the value to set for the field.
 * @param {*} [valIn] The value to set the field to. The format of the value will
 * depend upon the field type. Not required if the first parameter is given
 * as an object.
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Set the values of a few fields before then automatically submitting the form
 * editor.create( null, null, false );
 * editor.set( 'name', 'Test user' );
 * editor.set( 'access', 'Read only' );
 * editor.submit();
 */
function set(setIn, valIn) {
    var that = this;
    if (!$.isPlainObject(setIn)) {
        var o = {};
        o[setIn] = valIn;
        setIn = o;
    }
    $.each(setIn, function (n, v) {
        that.field(n).set(v);
    });
    return this;
}
/**
 * Show a field in the display that was previously hidden.
 *
 * @param {string|array} [names] The field name (from the `name` parameter
 * given when originally setting up the field) to make visible, or an array of
 * field names to make visible. If not given all fields are shown.
 * @param {boolean} [animate=true] Animate if visible
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Shuffle the fields that are visible, hiding one field and making two
 * // others visible before then showing the {@link Editor#create} record form.
 * editor.hide( 'username' );
 * editor.show( 'account_type' );
 * editor.show( 'access_level' );
 * editor.create( 'Add new user', {
 *  "label": "Save",
 *  "fn": function () { this.submit(); }
 * } );
 *
 * @example
 * // Show all fields
 * editor.show();
 */
function show(names, animate) {
    var that = this;
    $.each(this._fieldNames(names), function (i, n) {
        that.field(n).show(animate);
    });
    return this;
}
/**
 * Submit a form to the server for processing. The exact action performed will depend
 * on which of the methods {@link Editor#create}, {@link Editor#edit} or
 * {@link Editor#remove} were called to prepare the form - regardless of which one is
 * used, you call this method to submit data.
 *
 * @param {function} [successCallback] Callback function that is executed once the
 * form has been successfully submitted to the server and no errors occurred.
 * @param {function} [errorCallback] Callback function that is executed if the
 * server reports an error due to the submission (this includes a JSON formatting
 * error should the error return invalid JSON).
 * @param {function} [formatdata] Callback function that is passed in the data
 * that will be submitted to the server, allowing pre-formatting of the data,
 * removal of data or adding of extra fields.
 * @param {boolean} [hideIn=true] When the form is successfully submitted, by default
 * the form display will be hidden - this option allows that to be overridden.
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Submit data from a form button
 * editor.create( 'Add new record', {
 *  "label": "Save",
 *  "fn": function () {
 *    this.submit();
 *  }
 * } );
 *
 * @example
 * // Submit without showing the user the form
 * editor.create( null, null, false );
 * editor.submit();
 *
 * @example
 * // Provide success and error callback methods
 * editor.create( 'Add new record', {
 *  "label": "Save",
 *  "fn": function () {
 *    this.submit( function () {
 *        alert( 'Form successfully submitted!' );
 *      }, function () {
 *        alert( 'Form  encountered an error :-(' );
 *      }
 *    );
 *  }
 * } );
 *
 * @example
 * // Add an extra field to the data
 * editor.create( 'Add new record', {
 *  "label": "Save",
 *  "fn": function () {
 *    this.submit( null, null, function (data) {
 *      data.extra = "Extra information";
 *    } );
 *  }
 * } );
 *
 * @example
 * // Don't hide the form immediately - change the title and then close the form
 * // after a small amount of time
 * editor.create( 'Add new record', {
 *  "label": "Save",
 *  "fn": function () {
 *    this.submit(
 *      function () {
 *        var that = this;
 *        this.title( 'Data successfully added!' );
 *        setTimeout( function () {
 *          that.close();
 *        }, 1000 );
 *      },
 *      null,
 *      null,
 *      false
 *    );
 *  }
 * } );
 *
 */
function submit(successCallback, errorCallback, formatdata, hideIn) {
    var _this = this;
    var sFields = this.s.fields;
    var errorFields = [];
    var errorReady = 0;
    var sent = false;
    if (this.s.processing || !this.s.action) {
        return this;
    }
    this._processing(true);
    // If there are fields in error, we want to wait for the error notification
    // to be cleared before the form is submitted - errorFields tracks the
    // fields which are in the error state, while errorReady tracks those which
    // are ready to submit
    var send = function () {
        if (errorFields.length !== errorReady || sent) {
            return;
        }
        _this._event('initSubmit', [_this.s.action], function (result) {
            if (result === false) {
                _this._processing(false);
                return;
            }
            sent = true;
            _this._submit(successCallback, errorCallback, formatdata, hideIn);
        });
    };
    // Remove the global error (don't know if the form is still in an error
    // state!)
    this.error();
    // Count how many fields are in error
    $.each(sFields, function (name, fieldIn) {
        if (fieldIn.inError()) {
            errorFields.push(name);
        }
    });
    // Remove the error display
    $.each(errorFields, function (i, name) {
        sFields[name].error('', function () {
            errorReady++;
            send();
        });
    });
    send();
    return this;
}
/**
 * Get / set the DataTable assoc. with this Editor instance
 *
 * @param  {string|node|jQuery|undefined} setIn If undefined, treat as a getter,
 * otherwise set the host DataTable
 * @return {Editor|string|node|jQuery} Self is a setter, otherwise the DataTable
 * / DataTable selector
 */
function table(setIn) {
    if (setIn === undefined) {
        return this.s.table;
    }
    this.s.table = setIn;
    return this;
}
/**
 * Get / set the form template
 *
 * @param  {string|node|jQuery|undefined} setIn If undefined, treat as a getter,
 * otherwise set as the template - usually a selector.
 * @return {Editor|string|node|jQuery} Self is a setter, otherwise the template
 */
function template(setIn) {
    if (setIn === undefined) {
        return this.s.template;
    }
    this.s.template = setIn === null ?
        null :
        $(setIn);
    return this;
}
/**
 * Set the title of the form
 *
 * @param {string|function} titleIn The title to give to the form
 * @return {Editor} Editor instance, for chaining
 *
 * @example
 * // Create an edit display used the title, buttons and edit methods (note that
 * // this is just an example, typically you would use the parameters of the edit
 * // method to achieve this.
 * editor.title( 'Edit record' );
 * editor.buttons( {
 *  "label": "Update",
 *  "fn": function () { this.submit(); }
 * } );
 * editor.edit( TR_to_edit );
 *
 * @example
 * // Show a create form, with a timer for the duration that the form is open
 * editor.create( 'Add new record - time on form: 0s', {
 *  "label": "Save",
 *  "fn": function () { this.submit(); }
 * } );
 *
 * // Add an event to the editor to stop the timer when the display is removed
 * var runTimer = true;
 * var timer = 0;
 * editor.on( 'close', function () {
 *  runTimer = false;
 *  editor.off( 'close' );
 * } );
 * // Start the timer running
 * updateTitle();
 *
 * // Local function to update the title once per second
 * function updateTitle() {
 *  editor.title( 'Add new record - time on form: '+timer+'s' );
 *  timer++;
 *  if ( runTimer ) {
 *    setTimeout( function() {
 *      updateTitle();
 *    }, 1000 );
 *  }
 * }
 */
function title(titleIn) {
    var header = $(this.dom.header).children('div.' + this.classes.header.content);
    if (titleIn === undefined) {
        return header.html();
    }
    if (typeof titleIn === 'function') {
        titleIn = titleIn(this, new DataTable$5.Api(this.s.table));
    }
    header.html(titleIn);
    return this;
}
function val(fieldIn, value) {
    if (value !== undefined || $.isPlainObject(fieldIn)) {
        return this.set(fieldIn, value);
    }
    return this.get(fieldIn); // field can be undefined to get all
}

/**
 * Common error message emitter. This method is not (yet) publicly documented on
 * the Editor site. It might be in future.
 *
 * @param  {string} msg Error message
 * @param  {int}    tn  Tech note link
 */
function error(msg, tn, thro) {
    if (thro === void 0) { thro = true; }
    var display = tn ?
        msg + ' For more information, please refer to https://datatables.net/tn/' + tn :
        msg;
    if (thro) {
        throw display;
    }
    else {
        console.warn(display);
    }
}
/**
 * Obtain label / value pairs of data from a data source, be it an array or
 * object, for use in an input that requires label / value pairs such as
 * `select`, `radio` and `checkbox` inputs.
 *
 * A callback function is triggered for each label / value pair found, so the
 * caller can add it to the input as required.
 *
 * @static
 * @param {object|array} An object or array of data to iterate over getting the
 * label / value pairs.
 * @param {object} props When an array of objects is passed in as the data
 * source by default the label will be read from the `label` property and
 * the value from the `value` property of the object. This option can alter
 * that behaviour.
 * @param {function} fn Callback function. Takes three parameters: the label,
 * the value and the iterator index.
 */
function pairs(data, props, fn) {
    var i;
    var ien;
    var dataPoint;
    // Define default properties to read the data from if using an object.
    // The passed in `props` object and override.
    props = $.extend({
        label: 'label',
        value: 'value'
    }, props);
    if (Array.isArray(data)) {
        // As an array, we iterate each item which can be an object or value
        for (i = 0, ien = data.length; i < ien; i++) {
            dataPoint = data[i];
            if ($.isPlainObject(dataPoint)) {
                fn(dataPoint[props.value] === undefined ?
                    dataPoint[props.label] :
                    dataPoint[props.value], dataPoint[props.label], i, dataPoint.attr // optional - can be undefined
                );
            }
            else {
                fn(dataPoint, dataPoint, i);
            }
        }
    }
    else {
        // As an object the key is the label and the value is the value
        i = 0;
        $.each(data, function (key, val) {
            fn(val, key, i);
            i++;
        });
    }
}
/**
 * Field specific upload method. This can be used to upload a file to the Editor
 * libraries. This method is not (yet) publicly documented on the Editor site.
 * It might be in future.
 *
 * @static
 * @param {Editor} editor The Editor instance operating on
 * @param {object} conf Field configuration object
 * @param {Files} files The file(s) to upload
 * @param {function} progressCallback Upload progress callback
 * @param {function} completeCallback Callback function for once the file has
 * been uploaded
 */
function upload$1(editor, conf, files, progressCallback, completeCallback) {
    var reader = new FileReader();
    var counter = 0;
    var ids = [];
    var generalError = 'A server error occurred while uploading the file';
    // Clear any existing errors, as the new upload might not be in error
    editor.error(conf.name, '');
    if (typeof conf.ajax === 'function') {
        conf.ajax(files, function (idsIn) {
            completeCallback.call(editor, idsIn);
        });
        return;
    }
    progressCallback(conf, conf.fileReadText || '<i>Uploading file</i>');
    reader.onload = function (e) {
        var data = new FormData();
        var ajax;
        data.append('action', 'upload');
        data.append('uploadField', conf.name);
        data.append('upload', files[counter]);
        if (conf.ajaxData) {
            conf.ajaxData(data, files[counter], counter);
        }
        if (conf.ajax) {
            ajax = conf.ajax;
        }
        else if ($.isPlainObject(editor.s.ajax)) {
            ajax = editor.s.ajax.upload ?
                editor.s.ajax.upload :
                editor.s.ajax;
        }
        else if (typeof editor.s.ajax === 'string') {
            ajax = editor.s.ajax;
        }
        if (!ajax) {
            throw new Error('No Ajax option specified for upload plug-in');
        }
        if (typeof ajax === 'string') {
            ajax = { url: ajax };
        }
        // Handle the case when the ajax data is given as a function
        if (typeof ajax.data === 'function') {
            var d = {};
            var ret = ajax.data(d);
            // Allow the return to be used, or the object passed in
            if (ret !== undefined && typeof ret !== 'string') {
                d = ret;
            }
            $.each(d, function (key, value) {
                data.append(key, value);
            });
        }
        else if ($.isPlainObject(ajax.data)) {
            throw new Error('Upload feature cannot use `ajax.data` with an object. Please use it as a function instead.');
        }
        // Dev cancellable event
        editor._event('preUpload', [conf.name, files[counter], data], function (preRet) {
            // Upload was cancelled
            if (preRet === false) {
                // If there are other files still to read, spin through them
                if (counter < files.length - 1) {
                    counter++;
                    reader.readAsDataURL(files[counter]);
                }
                else {
                    completeCallback.call(editor, ids);
                }
                return;
            }
            // Use preSubmit to stop form submission during an upload, since the
            // value won't be known until that point.
            var submit = false;
            editor
                .on('preSubmit.DTE_Upload', function () {
                submit = true;
                return false;
            });
            $.ajax($.extend({}, ajax, {
                contentType: false,
                data: data,
                dataType: 'json',
                error: function (xhr) {
                    editor.error(conf.name, generalError);
                    editor._event('uploadXhrError', [conf.name, xhr]);
                    progressCallback(conf);
                },
                processData: false,
                success: function (json) {
                    editor.off('preSubmit.DTE_Upload');
                    editor._event('uploadXhrSuccess', [conf.name, json]);
                    if (json.fieldErrors && json.fieldErrors.length) {
                        var errors = json.fieldErrors;
                        for (var i = 0, ien = errors.length; i < ien; i++) {
                            editor.error(errors[i].name, errors[i].status);
                        }
                    }
                    else if (json.error) {
                        editor.error(json.error);
                    }
                    else if (!json.upload || !json.upload.id) {
                        editor.error(conf.name, generalError);
                    }
                    else {
                        if (json.files) {
                            // Loop over the tables that are defined
                            $.each(json.files, function (table, filesIn) {
                                if (!Editor.files[table]) {
                                    Editor.files[table] = {};
                                }
                                $.extend(Editor.files[table], filesIn);
                            });
                        }
                        ids.push(json.upload.id);
                        if (counter < files.length - 1) {
                            counter++;
                            reader.readAsDataURL(files[counter]);
                        }
                        else {
                            completeCallback.call(editor, ids);
                            if (submit) {
                                editor.submit();
                            }
                        }
                    }
                    progressCallback(conf);
                },
                type: 'post',
                xhr: function () {
                    var xhr = $.ajaxSettings.xhr();
                    if (xhr.upload) {
                        xhr.upload.onprogress = function () {
                            if (e.lengthComputable) {
                                var percent = (e.loaded / e.total * 100).toFixed(0) + '%';
                                progressCallback(conf, files.length === 1 ?
                                    percent :
                                    counter + ':' + files.length + ' ' + percent);
                            }
                        };
                        xhr.upload.onloadend = function () {
                            progressCallback(conf, conf.processingText || 'Processing');
                        };
                    }
                    return xhr;
                }
            }));
        });
    };
    // Convert to a plain array
    files = $.map(files, function (val) {
        return val;
    });
    // Truncate the selected files if needed
    if (conf._limitLeft !== undefined) {
        files.splice(conf._limitLeft, files.length);
    }
    reader.readAsDataURL(files[0]);
}

var DataTable$4 = $.fn.dataTable;
var _inlineCounter = 0;
/**
 * Set the class on the form to relate to the action that is being performed.
 * This allows styling to be applied to the form to reflect the state that
 * it is in.
 *
 * @private
 */
function _actionClass() {
    var classesActions = this.classes.actions;
    var action = this.s.action;
    var wrapper = $(this.dom.wrapper);
    wrapper.removeClass([classesActions.create, classesActions.edit, classesActions.remove].join(' '));
    if (action === 'create') {
        wrapper.addClass(classesActions.create);
    }
    else if (action === 'edit') {
        wrapper.addClass(classesActions.edit);
    }
    else if (action === 'remove') {
        wrapper.addClass(classesActions.remove);
    }
}
/**
 * Create an Ajax request in the same style as DataTables 1.10, with full
 * backwards compatibility for Editor 1.2.
 *
 * @param  {object} data Data to submit
 * @param  {function} success Success callback
 * @param  {function} error Error callback
 * @param  {object} submitParams Submitted data
 * @private
 */
function _ajax(data, success, error, submitParams) {
    var action = this.s.action;
    var thrown;
    var opts = {
        complete: [function (xhr, text) {
                // Use `complete` rather than `success` so that all status codes are
                // caught and can return valid JSON (useful when working with REST
                // services).
                var json = null;
                if (xhr.status === 204 || xhr.responseText === 'null') {
                    json = {};
                }
                else {
                    try {
                        // jQuery 1.12 or newer for responseJSON, but its the only
                        // way to get the JSON from a JSONP. So if you want to use
                        // JSONP with Editor you have to use jQuery 1.12+.
                        json = xhr.responseJSON ?
                            xhr.responseJSON :
                            JSON.parse(xhr.responseText);
                    }
                    catch (e) { }
                }
                if ($.isPlainObject(json) || Array.isArray(json)) {
                    success(json, xhr.status >= 400, xhr);
                }
                else {
                    error(xhr, text, thrown);
                }
            }],
        data: null,
        dataType: 'json',
        error: [function (xhr, text, err) {
                thrown = err;
            }],
        success: [],
        type: 'POST'
    };
    var a;
    var ajaxSrc = this.s.ajax;
    var id = action === 'edit' || action === 'remove' ?
        pluck(this.s.editFields, 'idSrc').join(',') :
        null;
    // Get the correct object for rest style
    if ($.isPlainObject(ajaxSrc) && ajaxSrc[action]) {
        ajaxSrc = ajaxSrc[action];
    }
    if (typeof ajaxSrc === 'function') {
        // As a function, execute it, passing in the required parameters
        ajaxSrc(null, null, data, success, error);
        return;
    }
    else if (typeof ajaxSrc === 'string') {
        // As a string it gives the URL. For backwards compatibility it can also
        // give the method.
        if (ajaxSrc.indexOf(' ') !== -1) {
            a = ajaxSrc.split(' ');
            opts.type = a[0];
            opts.url = a[1];
        }
        else {
            opts.url = ajaxSrc;
        }
    }
    else {
        // As an object, we extend the Editor defaults - with the exception of
        // the error and complete functions which get added in so the user can
        // specify their own in addition to ours
        var optsCopy = $.extend({}, ajaxSrc || {});
        if (optsCopy.complete) {
            opts.complete.unshift(optsCopy.complete);
            delete optsCopy.complete;
        }
        if (optsCopy.error) {
            opts.error.unshift(optsCopy.error);
            delete optsCopy.error;
        }
        opts = $.extend({}, opts, optsCopy);
    }
    // URL macros
    if (opts.replacements) {
        $.each(opts.replacements, function (key, repl) {
            opts.url = opts.url.replace('{' + key + '}', repl.call(this, key, id, action, data));
        });
    }
    opts.url = opts.url
        .replace(/_id_/, id)
        .replace(/{id}/, id);
    // Data processing option like in DataTables
    if (opts.data) {
        var isFn = typeof opts.data === 'function';
        var newData = isFn ?
            opts.data(data) : // fn can manipulate data or return an object
            opts.data; // object or array to merge
        // If the function returned something, use that alone
        data = isFn && newData ?
            newData :
            $.extend(true, data, newData);
    }
    opts.data = data;
    // If a DELETE method is used there are a number of servers which will
    // reject the request if it has a body. So we need to append to the URL.
    //
    // http://stackoverflow.com/questions/15088955
    // http://bugs.jquery.com/ticket/11586
    if (opts.type === 'DELETE' && (opts.deleteBody === undefined || opts.deleteBody === true)) {
        var params = $.param(opts.data);
        opts.url += opts.url.indexOf('?') === -1 ?
            '?' + params :
            '&' + params;
        delete opts.data;
    }
    // Finally, make the ajax call
    $.ajax(opts);
}
/**
 * Abstraction for jQuery's animate method, to support jQuery slim which doesn't
 * include the animate module
 *
 * @private
 */
function _animate(target, style, time, callback) {
    if ($.fn.animate) {
        target
            .stop()
            .animate(style, time, callback);
    }
    else {
        target.css(style);
        if (typeof time === 'function') {
            time.call(target);
        }
        else if (callback) {
            callback.call(target);
        }
    }
}
/**
 * Create the DOM structure from the source elements for the main form.
 * This is required since the elements can be moved around for other form types
 * (bubble).
 *
 * @private
 */
function _assembleMain() {
    var dom = this.dom;
    $(dom.wrapper)
        .prepend(dom.header);
    $(dom.footer)
        .append(dom.formError)
        .append(dom.buttons);
    $(dom.bodyContent)
        .append(dom.formInfo)
        .append(dom.form);
}
/**
 * Blur the editing window. A blur is different from a close in that it might
 * cause either a close or the form to be submitted. A typical example of a
 * blur would be clicking on the background of the bubble or main editing forms
 * - i.e. it might be a close, or it might submit depending upon the
 * configuration, while a click on the close box is a very definite close.
 *
 * @private
 */
function _blur() {
    var opts = this.s.editOpts;
    var onBlur = opts.onBlur;
    if (this._event('preBlur') === false) {
        return;
    }
    if (typeof onBlur === 'function') {
        onBlur(this);
    }
    else if (onBlur === 'submit') {
        this.submit();
    }
    else if (onBlur === 'close') {
        this._close();
    }
}
/**
 * Clear all of the information that might have been dynamically set while
 * the form was visible - specifically errors and dynamic messages
 *
 * @private
 */
function _clearDynamicInfo(errorsOnly) {
    if (errorsOnly === void 0) { errorsOnly = false; }
    // Can be triggered due to a destroy if the editor is open
    if (!this.s) {
        return;
    }
    var errorClass = this.classes.field.error;
    var fields = this.s.fields;
    $('div.' + errorClass, this.dom.wrapper).removeClass(errorClass);
    $.each(fields, function (name, field) {
        field.error('');
        if (!errorsOnly) {
            field.message('');
        }
    });
    this.error('');
    if (!errorsOnly) {
        this.message('');
    }
}
/**
 * Close an editing display, firing callbacks and events as needed
 *
 * @param  {function} submitComplete Function to call after the preClose event
 * @param  {string} mode Editing mode that is just finished
 * @private
 */
function _close(submitComplete, mode) {
    var closed;
    // Allow preClose event to cancel the opening of the display
    if (this._event('preClose') === false) {
        return;
    }
    if (this.s.closeCb) {
        closed = this.s.closeCb(submitComplete, mode);
        this.s.closeCb = null;
    }
    if (this.s.closeIcb) {
        this.s.closeIcb();
        this.s.closeIcb = null;
    }
    // Remove focus control
    $('body').off('focus.editor-focus');
    this.s.displayed = false;
    this._event('close');
    if (closed) {
        // Note that `bubble` will call this itself due to the animation
        this._event('closed', [closed]);
    }
}
/**
 * Register a function to be called when the editing display is closed. This is
 * used by function that create the editing display to tidy up the display on
 * close - for example removing event handlers to prevent memory leaks.
 *
 * @param  {function} fn Function to call on close
 * @private
 */
function _closeReg(fn) {
    this.s.closeCb = fn;
}
/**
 * Argument shifting for the create(), edit() and remove() methods. In Editor
 * 1.3 the preferred form of calling those three methods is with just two
 * parameters (one in the case of create() - the id and the show flag), while in
 * previous versions four / three parameters could be passed in, including the
 * buttons and title options. In 1.3 the chaining API is preferred, but we want
 * to support the old form as well, so this function is provided to perform
 * that argument shifting, common to all three.
 *
 * @private
 */
function _crudArgs(arg1, arg2, arg3, arg4) {
    var that = this;
    var title;
    var buttons;
    var show;
    var opts;
    if ($.isPlainObject(arg1)) {
        // Form options passed in as the first option
        opts = arg1;
    }
    else if (typeof arg1 === 'boolean') {
        // Show / hide passed in as the first option - form options second
        show = arg1;
        opts = arg2; // can be undefined
    }
    else {
        // Old style arguments
        title = arg1; // can be undefined
        buttons = arg2; // can be undefined
        show = arg3; // can be undefined
        opts = arg4; // can be undefined
    }
    // If all undefined, then fall into here
    if (show === undefined) {
        show = true;
    }
    if (title) {
        that.title(title);
    }
    if (buttons) {
        that.buttons(buttons);
    }
    return {
        maybeOpen: function () {
            if (show) {
                that.open();
            }
        },
        opts: $.extend({}, this.s.formOptions.main, opts)
    };
}
/**
 * Execute the data source abstraction layer functions. This is simply a case
 * of executing the function with the Editor scope, passing in the remaining
 * parameters.
 *
 * @param {string} name Function name to execute
 * @private
 */
function _dataSource(name) {
    var args = [];
    for (var _i = 1; _i < arguments.length; _i++) {
        args[_i - 1] = arguments[_i];
    }
    var dataSource = this.s.table
        ? Editor.dataSources.dataTable
        : Editor.dataSources.html;
    var fn = dataSource[name];
    if (fn) {
        return fn.apply(this, args);
    }
}
/**
 * Insert the fields into the DOM, in the correct order
 *
 * @private
 */
function _displayReorder(includeFields) {
    var _this = this;
    var formContent = $(this.dom.formContent);
    var fields = this.s.fields;
    var order = this.s.order;
    var template = this.s.template;
    var mode = this.s.mode || 'main';
    if (includeFields) {
        this.s.includeFields = includeFields;
    }
    else {
        includeFields = this.s.includeFields;
    }
    // Empty before adding in the required fields
    formContent.children().detach();
    $.each(order, function (i, name) {
        if (_this._weakInArray(name, includeFields) !== -1) {
            if (template && mode === 'main') {
                template.find('editor-field[name="' + name + '"]').after(fields[name].node());
                template.find('[data-editor-template="' + name + '"]').append(fields[name].node());
            }
            else {
                formContent.append(fields[name].node());
            }
        }
    });
    if (template && mode === 'main') {
        template.appendTo(formContent);
    }
    this._event('displayOrder', [
        this.s.displayed,
        this.s.action,
        formContent
    ]);
}
/**
 * Generic editing handler. This can be called by the three editing modes (main,
 * bubble and inline) to configure Editor for a row edit, and fire the required
 * events to ensure that the editing interfaces all provide a common API.
 *
 * @param {*} rows Identifier for the item(s) to be edited
 * @param {string} type Editing type - for the initEdit event
 * @private
 */
function _edit(items, editFields, type, formOptions, setupDone) {
    var _this = this;
    var fields = this.s.fields;
    var usedFields = [];
    var includeInOrder;
    var editData = {};
    this.s.editFields = editFields;
    this.s.editData = editData;
    this.s.modifier = items;
    this.s.action = 'edit';
    this.dom.form.style.display = 'block';
    this.s.mode = type;
    this._actionClass();
    // Setup the field values for editing
    $.each(fields, function (name, field) {
        field.multiReset();
        includeInOrder = false;
        editData[name] = {};
        $.each(editFields, function (idSrc, edit) {
            if (edit.fields[name]) {
                var val = field.valFromData(edit.data);
                var nullDefault = field.nullDefault();
                // Save the set data values so we can decided in submit if data has changed
                // Note that `null` is stored as an empty string since fields do not currently
                // have the ability to store a null value - when they are read back (in the
                // submit) they would be an empty string. When null handling is added to
                // fields, this will need to be removed.
                editData[name][idSrc] = val === null ?
                    '' :
                    Array.isArray(val) ?
                        val.slice() :
                        val;
                // If scoped to edit the whole row, then set all of the fields
                if (!formOptions || formOptions.scope === 'row') {
                    field.multiSet(idSrc, val === undefined || (nullDefault && val === null) ?
                        field.def() :
                        val, false);
                    if (!edit.displayFields || edit.displayFields[name]) {
                        includeInOrder = true;
                    }
                }
                else {
                    // Limit editing to only those fields selected if any are selected
                    if (!edit.displayFields || edit.displayFields[name]) {
                        field.multiSet(idSrc, val === undefined || (nullDefault && val === null) ?
                            field.def() :
                            val, false);
                        includeInOrder = true;
                    }
                }
            }
        });
        // Loop finished - can do a multi-value check for display of the field now
        field._multiValueCheck();
        // If the field is used, then add it to the fields to be shown
        if (field.multiIds().length !== 0 && includeInOrder) {
            usedFields.push(name);
        }
    });
    // Remove the fields that are not required from the display
    var currOrder = this.order().slice();
    for (var i = currOrder.length - 1; i >= 0; i--) {
        // Use `toString()` to convert numbers to strings, since usedFields
        // contains strings (object property names)
        if ($.inArray(currOrder[i].toString(), usedFields) === -1) {
            currOrder.splice(i, 1);
        }
    }
    this._displayReorder(currOrder);
    // Events
    this._event('initEdit', [
        pluck(editFields, 'node')[0],
        pluck(editFields, 'data')[0],
        items,
        type
    ], function () {
        _this._event('initMultiEdit', // undocumented and to be removed in v2
        [editFields, items, type], function () {
            setupDone();
        });
    });
}
/**
 * Fire callback functions and trigger events.
 *
 * @param {string|array} trigger Name(s) of the jQuery custom event to trigger
 * @param {array} args Array of arguments to pass to the triggered event
 * @return {*} Return from the event
 * @private
 */
function _event(trigger, args, promiseComplete) {
    if (args === void 0) { args = []; }
    if (promiseComplete === void 0) { promiseComplete = undefined; }
    // Allow an array to be passed in for the trigger to fire multiple events
    if (Array.isArray(trigger)) {
        for (var i = 0, ien = trigger.length; i < ien; i++) {
            this._event(trigger[i], args);
        }
    }
    else {
        var e = $.Event(trigger);
        $(this).triggerHandler(e, args);
        var result = e.result;
        // Automatically trigger a cancelled event if a `pre` event handler
        // was cancelled by the callback
        if (trigger.indexOf('pre') === 0 && result === false) {
            $(this).triggerHandler($.Event(trigger + 'Cancelled'), args);
        }
        // Allow for a promise to be returned and execute a callback
        if (promiseComplete) {
            if (result && typeof result === 'object' && result.then) {
                // jQuery and "real" promises both provide "then"
                result.then(promiseComplete);
            }
            else {
                // If there wasn't a promise returned, then execute immediately
                promiseComplete(result);
            }
        }
        return result;
    }
}
/**
 * 'Modernise' event names, from the old style `on[A-Z]` names to camelCase.
 * This is done to provide backwards compatibility with Editor 1.2- event names.
 * The names themselves were updated for consistency with DataTables.
 *
 * @param {string} Event name to modernise
 * @return {string} String with new event name structure
 * @private
 */
function _eventName(input) {
    var name;
    var names = input.split(' ');
    for (var i = 0, ien = names.length; i < ien; i++) {
        name = names[i];
        // Strip the 'on' part and lowercase the first character
        var onStyle = name.match(/^on([A-Z])/);
        if (onStyle) {
            name = onStyle[1].toLowerCase() + name.substring(3);
        }
        names[i] = name;
    }
    return names.join(' ');
}
/**
 * Find a field from a DOM node. All children are searched.
 *
 * @param  {node} node DOM node to search for
 * @return {Field}     Field instance
 */
function _fieldFromNode(node) {
    var foundField = null;
    $.each(this.s.fields, function (name, field) {
        if ($(field.node()).find(node).length) {
            foundField = field;
        }
    });
    return foundField;
}
/**
 * Convert a field name input parameter to an array of field names.
 *
 * Many of the API methods provide the ability to pass `undefined` a string or
 * array of strings to identify fields. This method harmonises that.
 *
 * @param  {array|string} [fieldNames] Field names to get
 * @return {array}                     Field names
 * @private
 */
function _fieldNames(fieldNames) {
    if (fieldNames === undefined) {
        return this.fields();
    }
    else if (!Array.isArray(fieldNames)) {
        return [fieldNames];
    }
    return fieldNames;
}
/**
 * Focus on a field. Providing the logic to allow complex focus expressions
 *
 * @param {array} fields Array of Field instances or field names for the fields
 * that are shown
 * @param {null|string|integer} focus Field identifier to focus on
 * @private
 */
function _focus(fieldsIn, focus) {
    var _this = this;
    // Can't focus on a field when in remove mode (they aren't shown).
    if (this.s.action === 'remove') {
        return;
    }
    var field;
    var fields = $.map(fieldsIn, function (fieldOrName) { return typeof fieldOrName === 'string' ?
        _this.s.fields[fieldOrName] :
        fieldOrName; });
    if (typeof focus === 'number') {
        field = fields[focus];
    }
    else if (focus) {
        if (focus.indexOf('jq:') === 0) {
            field = $('div.DTE ' + focus.replace(/^jq:/, ''));
        }
        else {
            field = this.s.fields[focus];
        }
    }
    else {
        document.activeElement.blur();
    }
    this.s.setFocus = field;
    if (field) {
        field.focus();
    }
}
/**
 * Form options - common function so all editing methods can provide the same
 * basic options, DRY.
 *
 * @param {object} opts Editing options. See model.formOptions
 * @private
 */
function _formOptions(opts) {
    var _this = this;
    var that = this;
    var inlineCount = _inlineCounter++;
    var namespace = '.dteInline' + inlineCount;
    // Backwards compatibility with 1.4
    // if ( opts.closeOnComplete !== undefined ) {
    // 	opts.onComplete = opts.closeOnComplete ? 'close' : 'none';
    // }
    // if ( opts.submitOnBlur !== undefined ) {
    // 	opts.onBlur = opts.submitOnBlur ? 'submit' : 'close';
    // }
    // if ( opts.submitOnReturn !== undefined ) {
    // 	opts.onReturn = opts.submitOnReturn ? 'submit' : 'none';
    // }
    // if ( opts.blurOnBackground !== undefined ) {
    // 	opts.onBackground = opts.blurOnBackground ? 'blur' : 'none';
    // }
    this.s.editOpts = opts;
    // When submitting by Ajax we don't want to close a form that has been
    // opened during the ajax request, so we keep a count of the form opening
    this.s.editCount = inlineCount;
    if (typeof opts.title === 'string' || typeof opts.title === 'function') {
        this.title(opts.title);
        opts.title = true;
    }
    if (typeof opts.message === 'string' || typeof opts.message === 'function') {
        this.message(opts.message);
        opts.message = true;
    }
    if (typeof opts.buttons !== 'boolean') {
        this.buttons(opts.buttons);
        opts.buttons = true;
    }
    // Prevent submit by a host `<form>`
    $(document).on('keydown' + namespace, function (e) {
        if (e.which === 13 && _this.s.displayed) { // return
            var el = $(document.activeElement);
            if (el) {
                var field = _this._fieldFromNode(el);
                if (field && typeof field.canReturnSubmit === 'function' && field.canReturnSubmit(el)) {
                    e.preventDefault();
                }
            }
        }
    });
    $(document).on('keyup' + namespace, function (e) {
        var el = $(document.activeElement);
        if (e.which === 13 && _this.s.displayed) { // return
            var field = _this._fieldFromNode(el);
            // Allow the field plug-in to say if we can submit or not
            if (field && typeof field.canReturnSubmit === 'function' && field.canReturnSubmit(el)) {
                if (opts.onReturn === 'submit') {
                    e.preventDefault();
                    _this.submit();
                }
                else if (typeof opts.onReturn === 'function') {
                    e.preventDefault();
                    opts.onReturn(_this, e);
                }
            }
        }
        else if (e.which === 27) { // esc
            e.preventDefault();
            if (typeof opts.onEsc === 'function') {
                opts.onEsc(that, e);
            }
            else if (opts.onEsc === 'blur') {
                that.blur();
            }
            else if (opts.onEsc === 'close') {
                that.close();
            }
            else if (opts.onEsc === 'submit') {
                that.submit();
            }
        }
        else if (el.parents('.DTE_Form_Buttons').length) {
            if (e.which === 37) { // left
                el.prev('button').trigger('focus');
            }
            else if (e.which === 39) { // right
                el.next('button').trigger('focus');
            }
        }
    });
    this.s.closeIcb = function () {
        $(document).off('keydown' + namespace);
        $(document).off('keyup' + namespace);
    };
    return namespace;
}
/**
 * Inline editing insertion of fields
 */
function _inline(editFields, opts, closeCb) {
    var _this = this;
    if (closeCb === void 0) { closeCb = null; }
    var closed = false;
    var classes = this.classes.inline;
    var keys = Object.keys(editFields);
    var editRow = editFields[keys[0]];
    var children = null;
    var lastAttachPoint;
    var elements = [];
    for (var i = 0; i < editRow.attach.length; i++) {
        var name_1 = editRow.attachFields[i][0];
        elements.push({
            field: this.s.fields[name_1],
            name: name_1,
            node: $(editRow.attach[i]),
        });
    }
    var namespace = this._formOptions(opts);
    var ret = this._preopen('inline');
    if (!ret) {
        return this;
    }
    for (var _i = 0, elements_1 = elements; _i < elements_1.length; _i++) {
        var el = elements_1[_i];
        var node = el.node;
        el.children = node.contents().detach();
        // Note the wdith setting shouldn't be required, but Edge increases the column's
        // width if a % width is used (even 1%). This is the workaround
        var style = navigator.userAgent.indexOf('Edge/') !== -1 ?
            'style="width:' + node.width() + 'px"' :
            '';
        node.append($('<div class="' + classes.wrapper + '">' +
            '<div class="' + classes.liner + '" ' + style + '>' +
            '<div class="DTE_Processing_Indicator"><span></span></div>' +
            '</div>' +
            '<div class="' + classes.buttons + '"></div>' +
            '</div>'));
        node.find('div.' + classes.liner.replace(/ /g, '.'))
            .append(el.field.node())
            .append(this.dom.formError);
        // Need the last insert point to allow for number submitTrigger
        lastAttachPoint = el.field.node();
        if (opts.buttons) {
            // Use prepend for the CSS, so we can float the buttons right
            node.find('div.' + classes.buttons.replace(/ /g, '.')).append(this.dom.buttons);
        }
    }
    // If there is a submit trigger target, we need to modify the document to allow submission
    var submitTrigger = opts.submitTrigger;
    if (submitTrigger !== null) {
        // Allow the input to be a column index, including a negative to count from right
        if (typeof submitTrigger === 'number') {
            var kids = $(lastAttachPoint).closest('tr').children();
            submitTrigger = submitTrigger < 0
                ? kids[kids.length + submitTrigger]
                : kids[submitTrigger];
        }
        children = Array.prototype.slice.call($(submitTrigger)[0].childNodes);
        $(children).detach();
        // Event handler to submit the form and do nothing else
        $(submitTrigger)
            .on('click.dte-submit', function (e) {
            e.stopImmediatePropagation();
            _this.submit();
        })
            .append(opts.submitHtml);
    }
    this._closeReg(function (submitComplete, action) {
        // Mark that this specific inline edit has closed
        closed = true;
        $(document).off('click' + namespace);
        // If there was no submit, we need to put the DOM back as it was. If
        // there was a submit, the write of the new value will set the DOM to
        // how it should be. Note also, check if it was an edit action, if not
        // a create will create new row so we tidy this one up
        if (!submitComplete || action !== 'edit') {
            elements.forEach(function (el) {
                el.node.contents().detach();
                el.node.append(el.children);
            });
        }
        if (submitTrigger) {
            $(submitTrigger)
                .off('click.dte-submit')
                .empty()
                .append(children);
        }
        // Clear error messages "offline"
        _this._clearDynamicInfo();
        if (closeCb) {
            closeCb();
        }
        return 'inline'; // trigger `closed`
    });
    // Submit and blur actions
    setTimeout(function () {
        // If already closed, possibly due to some other aspect of the event
        // that triggered the inline call, don't add the event listener - it
        // isn't needed (and is dangerous)
        if (closed) {
            return;
        }
        // andSelf is deprecated in jQ1.8, but we want 1.7 compat
        var back = $.fn.addBack ? 'addBack' : 'andSelf';
        // Chrome uses the target as the element where the mouse up happens,
        // but we want the target being where the mouse down is, to allow for
        // text selection in an input - so listen on mousedown as well.
        var target;
        $(document)
            .on('mousedown' + namespace, function (e) {
            target = e.target;
        })
            .on('keydown' + namespace, function (e) {
            target = e.target;
        })
            .on('click' + namespace, function (e) {
            // Was the click inside or owned by one of the editing nodes? If
            // not, then come out of editing mode.
            var isIn = false;
            for (var _i = 0, elements_2 = elements; _i < elements_2.length; _i++) {
                var el = elements_2[_i];
                if (el.field._typeFn('owns', target) ||
                    $.inArray(el.node[0], $(target).parents()[back]()) !== -1) {
                    isIn = true;
                }
            }
            if (!isIn) {
                _this.blur();
            }
        });
    }, 0);
    this._focus($.map(elements, function (el) { return el.field; }), opts.focus);
    this._postopen('inline', true);
}
/**
 * Update the field options from a JSON data source
 *
 * @param  {object} json JSON object from the server
 * @private
 */
function _optionsUpdate(json) {
    var that = this;
    if (json.options) {
        $.each(this.s.fields, function (name, field) {
            if (json.options[name] !== undefined) {
                var fieldInst = that.field(name);
                if (fieldInst && fieldInst.update) {
                    fieldInst.update(json.options[name]);
                }
            }
        });
    }
}
/**
 * Show a message in the form. This can be used for error messages or dynamic
 * messages (information display) as the structure for each is basically the
 * same. This method will take into account if the form is visible or not - if
 * so then the message is shown with an effect for the end user, otherwise
 * it is just set immediately.
 *
 * @param {element} el The field display node to use
 * @param {string|function} msg The message to show
 * @private
 */
function _message(el, msg, title, fn) {
    // Allow for jQuery slim
    var canAnimate = $.fn.animate ? true : false;
    if (title === undefined) {
        title = false;
    }
    if (!fn) {
        fn = function () { };
    }
    if (typeof msg === 'function') {
        msg = msg(this, new DataTable$4.Api(this.s.table));
    }
    el = $(el);
    if (canAnimate) {
        el.stop();
    }
    if (!msg) {
        if (this.s.displayed && canAnimate) {
            // Clear the message with visual effect since the form is visible
            el
                .fadeOut(function () {
                el.html('');
                fn();
            });
        }
        else {
            // Clear the message without visual effect
            el
                .html('')
                .css('display', 'none');
            fn();
        }
        if (title) {
            el.removeAttr('title');
        }
    }
    else {
        fn();
        if (this.s.displayed && canAnimate) {
            // Show the message with visual effect
            el
                .html(msg)
                .fadeIn();
        }
        else {
            // Show the message without visual effect
            el
                .html(msg)
                .css('display', 'block');
        }
        if (title) {
            el.attr('title', msg);
        }
    }
}
/**
 * Update the multi-value information display to not show redundant information
 *
 * @private
 */
function _multiInfo() {
    var fields = this.s.fields;
    var include = this.s.includeFields;
    var show = true;
    var state;
    if (!include) {
        return;
    }
    for (var i = 0, ien = include.length; i < ien; i++) {
        var field = fields[include[i]];
        var multiEditable = field.multiEditable();
        if (field.isMultiValue() && multiEditable && show) {
            // Multi-row editable. Only show first message
            state = true;
            show = false;
        }
        else if (field.isMultiValue() && !multiEditable) {
            // Not multi-row editable. Always show message
            state = true;
        }
        else {
            state = false;
        }
        fields[include[i]].multiInfoShown(state);
    }
}
/**
 * Close the current form, which can result in the display controller
 * hiding its display, or showing a form from a level up if nesting
 */
function _nestedClose(cb) {
    var disCtrl = this.s.displayController;
    var show = disCtrl._show;
    if (!show || !show.length) {
        // Nothing shown just now
        if (cb) {
            cb();
        }
    }
    else if (show.length > 1) {
        // Got nested forms - remove current and go one layer up
        show.pop();
        // Get the one to show
        var last = show[show.length - 1];
        if (cb) {
            cb();
        }
        this.s.displayController.open(last.dte, last.append, last.callback);
    }
    else {
        this.s.displayController.close(this, cb);
        show.length = 0;
    }
}
/**
 * Display a form, adding it to the display stack for nesting
 */
function _nestedOpen(cb, nest) {
    var disCtrl = this.s.displayController;
    // This needs to be per display controller, but the controller
    // itself doesn't know anything about the nesting, so we add a
    // "hidden" property to it, used here, but not by the controller
    // itself.
    if (!disCtrl._show) {
        disCtrl._show = [];
    }
    if (!nest) {
        disCtrl._show.length = 0;
    }
    disCtrl._show.push({
        append: this.dom.wrapper,
        callback: cb,
        dte: this,
    });
    this.s.displayController.open(this, this.dom.wrapper, cb);
}
/**
 * Common display editing form method called by all editing methods after the
 * form has been configured and displayed. This is to ensure all fire the same
 * events.
 *
 * @param  {string} type Editing type
 * @param  {boolean} immediate indicate if the open is immediate (in which case
 * `opened` is also triggered).
 * @return {boolean} `true`
 * @private
 */
function _postopen(type, immediate) {
    var _this = this;
    var focusCapture = this.s.displayController.captureFocus;
    if (focusCapture === undefined) {
        focusCapture = true;
    }
    $(this.dom.form)
        .off('submit.editor-internal')
        .on('submit.editor-internal', function (e) {
        e.preventDefault();
    });
    // Focus capture - when the Editor form is shown we capture the browser's
    // focus action. Without doing this is would result in the user being able
    // to control items under the Editor display - triggering actions that
    // shouldn't be possible while the editing is shown.
    if (focusCapture && (type === 'main' || type === 'bubble')) {
        $('body').on('focus.editor-focus', function () {
            if ($(document.activeElement).parents('.DTE').length === 0 &&
                $(document.activeElement).parents('.DTED').length === 0) {
                if (_this.s.setFocus) {
                    _this.s.setFocus.focus();
                }
            }
        });
    }
    this._multiInfo();
    this._event('open', [type, this.s.action]);
    if (immediate) {
        this._event('opened', [type, this.s.action]);
    }
    return true;
}
/**
 * Common display editing form method called by all editing methods before the
 * form has been configured and displayed. This is to ensure all fire the same
 * events.
 *
 * @param  {string} Editing type
 * @return {boolean} `false` if the open is cancelled by the preOpen event,
 * otherwise `true`
 * @private
 */
function _preopen(type) {
    // Allow preOpen event to cancel the opening of the display
    if (this._event('preOpen', [type, this.s.action]) === false) {
        // Tidy- this would normally be done on close, but we never get that far
        this._clearDynamicInfo();
        this._event('cancelOpen', [type, this.s.action]);
        // inline and bubble methods cannot be opened using `open()`, they
        // have to be called again, so we need to clean up the event
        // listener added by _formOptions
        if ((this.s.mode === 'inline' || this.s.mode === 'bubble') && this.s.closeIcb) {
            this.s.closeIcb();
        }
        this.s.closeIcb = null;
        return false;
    }
    this._clearDynamicInfo(true);
    this.s.displayed = type;
    return true;
}
/**
 * Set the form into processing mode or take it out of processing mode. In
 * processing mode a processing indicator is shown and user interaction with the
 * form buttons is blocked
 *
 * @param {boolean} processing true if to go into processing mode and false if
 * to come out of processing mode
 * @private
 */
function _processing(processing) {
    var procClass = this.classes.processing.active;
    $(['div.DTE', this.dom.wrapper]).toggleClass(procClass, processing);
    this.s.processing = processing;
    this._event('processing', [processing]);
}
/**
 * Check if any of the fields are processing for the submit to carry on. It
 * can recurse.
 *
 * @private
 */
function _noProcessing(args) {
    var processing = false;
    $.each(this.s.fields, function (name, field) {
        if (field.processing()) {
            processing = true;
        }
    });
    if (processing) {
        this.one('processing-field', function () {
            // Are any other fields in a processing state? - Might need to wait again
            if (this._noProcessing(args) === true) {
                this._submit.apply(this, args);
            }
        });
    }
    return !processing;
}
/**
 * Submit a form to the server for processing. This is the private method that is used
 * by the 'submit' API method, which should always be called in preference to calling
 * this method directly.
 *
 * @param {function} [successCallback] Callback function that is executed once the
 * form has been successfully submitted to the server and no errors occurred.
 * @param {function} [errorCallback] Callback function that is executed if the
 * server reports an error due to the submission (this includes a JSON formatting
 * error should the error return invalid JSON).
 * @param {function} [formatdata] Callback function that is passed in the data
 * that will be submitted to the server, allowing pre-formatting of the data,
 * removal of data or adding of extra fields.
 * @param {boolean} [hide=true] When the form is successfully submitted, by default
 * the form display will be hidden - this option allows that to be overridden.
 * @private
 */
function _submit(successCallback, errorCallback, formatdata, hide) {
    var _this = this;
    var changed = false;
    var allData = {};
    var changedData = {};
    var setBuilder = dataSet;
    var fields = this.s.fields;
    var editCount = this.s.editCount;
    var editFields = this.s.editFields;
    var editData = this.s.editData;
    var opts = this.s.editOpts;
    var changedSubmit = opts.submit;
    var submitParamsLocal;
    // First - are any of the fields currently "processing"? If so, then we
    // want to let them complete before submitting
    if (this._noProcessing(arguments) === false) {
        Editor.error('Field is still processing', 16, false);
        return;
    }
    // After initSubmit to allow `mode()` to be used as a setter
    var action = this.s.action;
    var submitParams = {
        data: {}
    };
    submitParams[this.s.actionName] = action;
    // Gather the data that is to be submitted
    if (action === 'create' || action === 'edit') {
        $.each(editFields, function (idSrc, edit) {
            var allRowData = {};
            var changedRowData = {};
            $.each(fields, function (name, field) {
                if (edit.fields[name] && field.submittable()) {
                    var multiGet = field.multiGet();
                    var builder = setBuilder(name);
                    // If it wasn't an edit field, we still need to get the original
                    // data, so we can submit it if `all` or `allIfChanged`
                    if (multiGet[idSrc] === undefined) {
                        var originalVal = field.valFromData(edit.data);
                        builder(allRowData, originalVal);
                        return;
                    }
                    var value = multiGet[idSrc];
                    var manyBuilder = Array.isArray(value) && typeof name === 'string' && name.indexOf('[]') !== -1 ?
                        setBuilder(name.replace(/\[.*$/, '') + '-many-count') :
                        null;
                    builder(allRowData, value);
                    // We need to tell the server-side if an array submission
                    // actually has no elements so it knows if the array was
                    // being submitted or not (since otherwise it doesn't know
                    // if the array was empty, or just not being submitted)
                    if (manyBuilder) {
                        manyBuilder(allRowData, value.length);
                    }
                    // Build a changed object for if that is the selected data
                    // type
                    if (action === 'edit' && (!editData[name] || !field.compare(value, editData[name][idSrc]))) {
                        builder(changedRowData, value);
                        changed = true;
                        if (manyBuilder) {
                            manyBuilder(changedRowData, value.length);
                        }
                    }
                }
            });
            if (!$.isEmptyObject(allRowData)) {
                allData[idSrc] = allRowData;
            }
            if (!$.isEmptyObject(changedRowData)) {
                changedData[idSrc] = changedRowData;
            }
        });
        // Decide what data to submit to the server for edit (create is all, always)
        if (action === 'create' || changedSubmit === 'all' || (changedSubmit === 'allIfChanged' && changed)) {
            submitParams.data = allData;
        }
        else if (changedSubmit === 'changed' && changed) {
            submitParams.data = changedData;
        }
        else {
            // Nothing to submit
            this.s.action = null;
            if (opts.onComplete === 'close' && (hide === undefined || hide)) {
                this._close(false);
            }
            else if (typeof opts.onComplete === 'function') {
                opts.onComplete(this);
            }
            if (successCallback) {
                successCallback.call(this);
            }
            this._processing(false);
            this._event('submitComplete');
            return;
        }
    }
    else if (action === 'remove') {
        $.each(editFields, function (idSrc, edit) {
            submitParams.data[idSrc] = edit.data;
        });
    }
    // Local copy of the submit parameters, needed for the data lib prep since
    // the preSubmit can modify the format and we need to know what the format is
    submitParamsLocal = $.extend(true, {}, submitParams);
    // Allow the data to be submitted to the server to be preprocessed by callback
    // and event functions
    if (formatdata) {
        formatdata(submitParams);
    }
    this._event('preSubmit', [submitParams, action], function (result) {
        if (result === false) {
            _this._processing(false);
        }
        else {
            // Submit to the server (or whatever method is defined in the settings)
            var submitWire = _this.s.ajax ?
                _this._ajax :
                _this._submitTable;
            submitWire.call(_this, submitParams, function (json, notGood, xhr) {
                _this._submitSuccess(json, notGood, submitParams, submitParamsLocal, _this.s.action, editCount, hide, successCallback, errorCallback, xhr);
            }, function (xhr, err, thrown) {
                _this._submitError(xhr, err, thrown, errorCallback, submitParams, _this.s.action);
            }, submitParams);
        }
    });
}
/**
 * Save submitted data without an Ajax request. This will write to a local
 * table only - not saving it permanently, but rather using the DataTable itself
 * as a data store.
 *
 * @param  {object} data Data to submit
 * @param  {function} success Success callback
 * @param  {function} error Error callback
 * @param  {object} submitParams Submitted data
 * @private
 */
function _submitTable(data, success, error, submitParams) {
    var action = data.action;
    var out = { data: [] };
    var idGet = dataGet(this.s.idSrc);
    var idSet = dataSet(this.s.idSrc);
    // Nothing required for remove - create and edit get a copy of the data
    if (action !== 'remove') {
        var originalData_1 = this.s.mode === 'main' ?
            this._dataSource('fields', this.modifier()) :
            this._dataSource('individual', this.modifier());
        $.each(data.data, function (key, vals) {
            var toSave;
            var extender = extend;
            // Get the original row's data, so we can modify it with new values.
            // This allows Editor to not need to submit all fields
            if (action === 'edit') {
                var rowData = originalData_1[key].data;
                toSave = extender({}, rowData, true);
                toSave = extender(toSave, vals, true);
            }
            else {
                toSave = extender({}, vals, true);
            }
            // If create and there isn't an id for the new row, create
            // one. An id could be creased by `preSubmit`
            var overrideId = idGet(toSave);
            if (action === 'create' && overrideId === undefined) {
                idSet(toSave, +new Date() + key.toString());
            }
            else {
                idSet(toSave, overrideId);
            }
            out.data.push(toSave);
        });
    }
    success(out);
}
/**
 * Submit success callback function
 *
 * @param  {object} json                Payload
 * @param  {bool} notGood               True if the returned status code was
 * >=400 (i.e. processing failed). This is called `notGood` rather than
 * `success` since the request was successfully processed, just not written to
 * the db. It is also inverted from "good" to make it optional when overriding
 * the `ajax` function.
 * @param  {object} submitParams        Submitted data
 * @param  {object} submitParamsLocal   Unmodified copy of submitted data
 * (before it could be modified by the user)
 * @param  {string} action              CRUD action being taken
 * @param  {int} editCount              Protection against async errors
 * @param  {bool} hide                  Hide the form flag
 * @param  {function} successCallback   Success callback
 * @param  {function} errorCallback     Error callback
 * @private
 */
function _submitSuccess(json, notGood, submitParams, submitParamsLocal, action, editCount, hide, successCallback, errorCallback, xhr) {
    var _this = this;
    var that = this;
    var setData;
    var fields = this.s.fields;
    var opts = this.s.editOpts;
    var modifier = this.s.modifier;
    this._event('postSubmit', [json, submitParams, action, xhr]);
    if (!json.error) {
        json.error = '';
    }
    if (!json.fieldErrors) {
        json.fieldErrors = [];
    }
    if (notGood || json.error || json.fieldErrors.length) {
        // Global form error
        var globalError_1 = [];
        if (json.error) {
            globalError_1.push(json.error);
        }
        // Field specific errors
        $.each(json.fieldErrors, function (i, err) {
            var field = fields[err.name];
            if (!field) {
                throw new Error('Unknown field: ' + err.name);
            }
            else if (field.displayed()) {
                field.error(err.status || 'Error');
                if (i === 0) {
                    if (opts.onFieldError === 'focus') {
                        // Scroll the display to the first error and focus
                        _this._animate($(_this.dom.bodyContent), { scrollTop: $(field.node()).position().top }, 500);
                        field.focus();
                    }
                    else if (typeof opts.onFieldError === 'function') {
                        opts.onFieldError(_this, err);
                    }
                }
            }
            else {
                // If the field isn't visible, we need to make it display as a global error
                // This _shouldn't_ happen - it means there is invalid data if it does
                globalError_1.push(field.name() + ': ' + (err.status || 'Error'));
            }
        });
        this.error(globalError_1.join('<br>'));
        this._event('submitUnsuccessful', [json]);
        if (errorCallback) {
            errorCallback.call(that, json);
        }
    }
    else {
        // Create a data store that the data source can use, which is
        // unique to this action
        var store = {};
        if (json.data && (action === 'create' || action === 'edit')) {
            this._dataSource('prep', action, modifier, submitParamsLocal, json, store);
            for (var _i = 0, _a = json.data; _i < _a.length; _i++) {
                var data = _a[_i];
                setData = data;
                var id = this._dataSource('id', data);
                this._event('setData', [json, data, action]); // legacy
                if (action === 'create') {
                    // New row was created to add it to the DT
                    this._event('preCreate', [json, data, id]);
                    this._dataSource('create', fields, data, store);
                    this._event(['create', 'postCreate'], [json, data, id]);
                }
                else if (action === 'edit') {
                    // Row was updated, so tell the DT
                    this._event('preEdit', [json, data, id]);
                    this._dataSource('edit', modifier, fields, data, store);
                    this._event(['edit', 'postEdit'], [json, data, id]);
                }
            }
            this._dataSource('commit', action, modifier, json.data, store);
        }
        else if (action === 'remove') {
            this._dataSource('prep', action, modifier, submitParamsLocal, json, store);
            // Remove the rows given and then redraw the table
            this._event('preRemove', [json, this.ids()]);
            this._dataSource('remove', modifier, fields, store);
            this._event(['remove', 'postRemove'], [json, this.ids()]);
            this._dataSource('commit', action, modifier, json.data, store);
        }
        // Submission complete
        if (editCount === this.s.editCount) {
            var sAction = this.s.action;
            this.s.action = null; // Must do before close, in case close starts a new edit
            if (opts.onComplete === 'close' && (hide === undefined || hide)) {
                // If no data returned, then treat as not complete
                this._close(json.data ? true : false, sAction);
            }
            else if (typeof opts.onComplete === 'function') {
                opts.onComplete(this);
            }
        }
        // All done - fire off the callbacks and events
        if (successCallback) {
            successCallback.call(that, json);
        }
        this._event('submitSuccess', [json, setData, action]);
    }
    this._processing(false);
    this._event('submitComplete', [json, setData, action]);
}
/**
 * Submit error callback function
 *
 * @private
 */
function _submitError(xhr, err, thrown, errorCallback, submitParams, action) {
    this._event('postSubmit', [null, submitParams, action, xhr]);
    this.error(this.i18n.error.system);
    this._processing(false);
    if (errorCallback) {
        errorCallback.call(this, xhr, err, thrown);
    }
    this._event(['submitError', 'submitComplete'], [xhr, err, thrown, submitParams]);
}
/**
 * Check to see if the form needs to be tidied before a new action can be performed.
 * This includes if the from is currently processing an old action and if it
 * is inline editing.
 *
 * @param {function} fn Callback function
 * @returns {boolean} `true` if was in inline mode, `false` otherwise
 * @private
 */
function _tidy(fn) {
    var _this = this;
    var dt = this.s.table ?
        new $.fn.dataTable.Api(this.s.table) :
        null;
    var ssp = false;
    if (dt) {
        ssp = dt.settings()[0].oFeatures.bServerSide;
    }
    if (this.s.processing) {
        // If currently processing, wait until the action is complete
        this.one('submitComplete', function () {
            // If server-side processing is being used in DataTables, first
            // check that we are still processing (might not be if nothing was
            // submitted) and then wait for the draw to finished
            if (ssp) {
                dt.one('draw', fn);
            }
            else {
                setTimeout(function () {
                    fn();
                }, 10);
            }
        });
        return true;
    }
    else if (this.display() === 'inline' || this.display() === 'bubble') {
        // If there is an inline edit box, it needs to be tidied
        this
            .one('close', function () {
            // On close if processing then we need to wait for the submit to
            // complete before running the callback as onBlur was set to
            // submit
            if (!_this.s.processing) {
                // IE needs a small timeout, otherwise it may not focus on a
                // field if one already has focus
                setTimeout(function () {
                    // Check this Editor wasn't destroyed
                    if (_this.s) {
                        fn();
                    }
                }, 10);
            }
            else {
                // Need to wait for the submit to finish
                _this.one('submitComplete', function (e, json) {
                    // If SSP then need to wait for the draw
                    if (ssp && json) {
                        dt.one('draw', fn);
                    }
                    else {
                        setTimeout(function () {
                            if (_this.s) {
                                fn();
                            }
                        }, 10);
                    }
                });
            }
        })
            .blur();
        return true;
    }
    return false;
}
/**
 * Same as $.inArray but with weak type checking
 *
 * @param {any} name Value to look for in the array
 * @param {array} arr Array to scan through
 * @returns {number} -1 if not found, index otherwise
 */
function _weakInArray(name, arr) {
    for (var i = 0, ien = arr.length; i < ien; i++) {
        if (name == arr[i]) {
            return i;
        }
    }
    return -1;
}

var fieldType = {
    create: function () { },
    disable: function () { },
    enable: function () { },
    get: function () { },
    set: function () { }
};

var DataTable$3 = $.fn.dataTable;
// Upload private helper method
function _buttonText(conf, textIn) {
    if (textIn === null || textIn === undefined) {
        textIn = conf.uploadText || 'Choose file...';
    }
    conf._input.find('div.upload button').html(textIn);
}
function _commonUpload(editor, conf, dropCallback, multiple) {
    if (multiple === void 0) { multiple = false; }
    var btnClass = editor.classes.form.buttonInternal;
    var container = $('<div class="editor_upload">' +
        '<div class="eu_table">' +
        '<div class="row">' +
        '<div class="cell upload limitHide">' +
        '<button class="' + btnClass + '"></button>' +
        '<input type="file" ' + (multiple ? 'multiple' : '') + '></input>' +
        '</div>' +
        '<div class="cell clearValue">' +
        '<button class="' + btnClass + '"></button>' +
        '</div>' +
        '</div>' +
        '<div class="row second">' +
        '<div class="cell limitHide">' +
        '<div class="drop"><span></span></div>' +
        '</div>' +
        '<div class="cell">' +
        '<div class="rendered"></div>' +
        '</div>' +
        '</div>' +
        '</div>' +
        '</div>');
    conf._input = container;
    conf._enabled = true;
    if (conf.id) {
        container.find('input[type=file]').attr('id', Editor.safeId(conf.id));
    }
    if (conf.attr) {
        container.find('input[type=file]').attr(conf.attr);
    }
    _buttonText(conf);
    if (window.FileReader && conf.dragDrop !== false) {
        container.find('div.drop span').text(conf.dragDropText || 'Drag and drop a file here to upload');
        var dragDrop_1 = container.find('div.drop');
        dragDrop_1
            .on('drop', function (e) {
            if (conf._enabled) {
                Editor.upload(editor, conf, e.originalEvent.dataTransfer.files, _buttonText, dropCallback);
                dragDrop_1.removeClass('over');
            }
            return false;
        })
            .on('dragleave dragexit', function (e) {
            if (conf._enabled) {
                dragDrop_1.removeClass('over');
            }
            return false;
        })
            .on('dragover', function (e) {
            if (conf._enabled) {
                dragDrop_1.addClass('over');
            }
            return false;
        });
        // When an Editor is open with a file upload input there is a
        // reasonable chance that the user will miss the drop point when
        // dragging and dropping. Rather than loading the file in the browser,
        // we want nothing to happen, otherwise the form will be lost.
        editor
            .on('open', function () {
            $('body').on('dragover.DTE_Upload drop.DTE_Upload', function (e) {
                return false;
            });
        })
            .on('close', function () {
            $('body').off('dragover.DTE_Upload drop.DTE_Upload');
        });
    }
    else {
        container.addClass('noDrop');
        container.append(container.find('div.rendered'));
    }
    container.find('div.clearValue button').on('click', function (e) {
        e.preventDefault();
        if (conf._enabled) {
            upload.set.call(editor, conf, '');
        }
    });
    container.find('input[type=file]').on('input', function () {
        Editor.upload(editor, conf, this.files, _buttonText, function (ids) {
            dropCallback.call(editor, ids);
            container.find('input[type=file]')[0].value = '';
        });
    });
    return container;
}
// Typically a change event caused by the end user will be added to a queue that
// the browser will handle when no other script is running. However, using
// `$().trigger()` will cause it to happen immediately, so in order to simulate
// the standard browser behaviour we use setTimeout. This also means that
// `dependent()` and other change event listeners will trigger when the field
// values have all been set, rather than as they are being set - 31594
function _triggerChange(input) {
    setTimeout(function () {
        input.trigger('change', { editor: true, editorSet: true }); // editorSet legacy
    }, 0);
}
// A number of the fields in this file use the same get, set, enable and disable
// methods (specifically the text based controls), so in order to reduce the code
// size, we just define them once here in our own local base model for the field
// types.
var baseFieldType = $.extend(true, {}, fieldType, {
    canReturnSubmit: function (conf, node) {
        return true;
    },
    disable: function (conf) {
        conf._input.prop('disabled', true);
    },
    enable: function (conf) {
        conf._input.prop('disabled', false);
    },
    get: function (conf) {
        return conf._input.val();
    },
    set: function (conf, val) {
        conf._input.val(val);
        _triggerChange(conf._input);
    }
});
var hidden = {
    create: function (conf) {
        conf._val = conf.value;
        return null;
    },
    get: function (conf) {
        return conf._val;
    },
    set: function (conf, val) {
        conf._val = val;
    }
};
var readonly = $.extend(true, {}, baseFieldType, {
    create: function (conf) {
        conf._input = $('<input/>').attr($.extend({
            id: Editor.safeId(conf.id),
            readonly: 'readonly',
            type: 'text'
        }, conf.attr || {}));
        return conf._input[0];
    }
});
var text = $.extend(true, {}, baseFieldType, {
    create: function (conf) {
        conf._input = $('<input/>').attr($.extend({
            id: Editor.safeId(conf.id),
            type: 'text'
        }, conf.attr || {}));
        return conf._input[0];
    }
});
var password = $.extend(true, {}, baseFieldType, {
    create: function (conf) {
        conf._input = $('<input/>').attr($.extend({
            id: Editor.safeId(conf.id),
            type: 'password'
        }, conf.attr || {}));
        return conf._input[0];
    }
});
var textarea = $.extend(true, {}, baseFieldType, {
    canReturnSubmit: function (conf, node) {
        return false;
    },
    create: function (conf) {
        conf._input = $('<textarea></textarea>').attr($.extend({
            id: Editor.safeId(conf.id)
        }, conf.attr || {}));
        return conf._input[0];
    }
});
var select = $.extend(true, {}, baseFieldType, {
    // Locally "private" function that can be reused for the create and update methods
    _addOptions: function (conf, opts, append) {
        if (append === void 0) { append = false; }
        var elOpts = conf._input[0].options;
        var countOffset = 0;
        if (!append) {
            elOpts.length = 0;
            if (conf.placeholder !== undefined) {
                var placeholderValue = conf.placeholderValue !== undefined ?
                    conf.placeholderValue :
                    '';
                countOffset += 1;
                elOpts[0] = new Option(conf.placeholder, placeholderValue);
                var disabled = conf.placeholderDisabled !== undefined ?
                    conf.placeholderDisabled :
                    true;
                elOpts[0].hidden = disabled; // can't be hidden if not disabled!
                elOpts[0].disabled = disabled;
                elOpts[0]._editor_val = placeholderValue;
            }
        }
        else {
            countOffset = elOpts.length;
        }
        if (opts) {
            Editor.pairs(opts, conf.optionsPair, function (val, label, i, attr) {
                var option = new Option(label, val);
                option._editor_val = val;
                if (attr) {
                    $(option).attr(attr);
                }
                elOpts[i + countOffset] = option;
            });
        }
    },
    create: function (conf) {
        conf._input = $('<select></select>')
            .attr($.extend({
            id: Editor.safeId(conf.id),
            multiple: conf.multiple === true
        }, conf.attr || {}))
            .on('change.dte', function (e, d) {
            // On change, get the user selected value and store it as the
            // last set, so `update` can reflect it. This way `_lastSet`
            // always gives the intended value, be it set via the API or by
            // the end user.
            if (!d || !d.editor) {
                conf._lastSet = select.get(conf);
            }
        });
        select._addOptions(conf, conf.options || conf.ipOpts);
        return conf._input[0];
    },
    destroy: function (conf) {
        conf._input.off('change.dte');
    },
    get: function (conf) {
        var val = conf._input.find('option:selected').map(function () {
            return this._editor_val;
        }).toArray();
        if (conf.multiple) {
            return conf.separator ?
                val.join(conf.separator) :
                val;
        }
        return val.length ? val[0] : null;
    },
    set: function (conf, val, localUpdate) {
        if (!localUpdate) {
            conf._lastSet = val;
        }
        // Can't just use `$().val()` because it won't work with strong types
        if (conf.multiple && conf.separator && !Array.isArray(val)) {
            val = typeof val === 'string' ?
                val.split(conf.separator) :
                [];
        }
        else if (!Array.isArray(val)) {
            val = [val];
        }
        var i;
        var len = val.length;
        var found;
        var allFound = false;
        var options = conf._input.find('option');
        conf._input.find('option').each(function () {
            found = false;
            for (i = 0; i < len; i++) {
                // Weak typing
                if (this._editor_val == val[i]) {
                    found = true;
                    allFound = true;
                    break;
                }
            }
            this.selected = found;
        });
        // If there is a placeholder, we might need to select it if nothing else
        // was selected. It doesn't make sense to select when multi is enabled
        if (conf.placeholder && !allFound && !conf.multiple && options.length) {
            options[0].selected = true;
        }
        // Update will call change itself, otherwise multiple might be called
        if (!localUpdate) {
            _triggerChange(conf._input);
        }
        return allFound;
    },
    update: function (conf, options, append) {
        select._addOptions(conf, options, append);
        // Attempt to set the last selected value (set by the API or the end
        // user, they get equal priority)
        var lastSet = conf._lastSet;
        if (lastSet !== undefined) {
            select.set(conf, lastSet, true);
        }
        _triggerChange(conf._input);
    }
});
var checkbox = $.extend(true, {}, baseFieldType, {
    // Locally "private" function that can be reused for the create and update methods
    _addOptions: function (conf, opts, append) {
        if (append === void 0) { append = false; }
        var jqInput = conf._input;
        var offset = 0;
        if (!append) {
            jqInput.empty();
        }
        else {
            offset = $('input', jqInput).length;
        }
        if (opts) {
            Editor.pairs(opts, conf.optionsPair, function (val, label, i, attr) {
                jqInput.append('<div>' +
                    '<input id="' + Editor.safeId(conf.id) + '_' + (i + offset) + '" type="checkbox" />' +
                    '<label for="' + Editor.safeId(conf.id) + '_' + (i + offset) + '">' + label + '</label>' +
                    '</div>');
                $('input:last', jqInput).attr('value', val)[0]._editor_val = val;
                if (attr) {
                    $('input:last', jqInput).attr(attr);
                }
            });
        }
    },
    create: function (conf) {
        conf._input = $('<div></div>');
        checkbox._addOptions(conf, conf.options || conf.ipOpts);
        return conf._input[0];
    },
    disable: function (conf) {
        conf._input.find('input').prop('disabled', true);
    },
    enable: function (conf) {
        conf._input.find('input').prop('disabled', false);
    },
    get: function (conf) {
        var out = [];
        var selected = conf._input.find('input:checked');
        if (selected.length) {
            selected.each(function () {
                out.push(this._editor_val);
            });
        }
        else if (conf.unselectedValue !== undefined) {
            out.push(conf.unselectedValue);
        }
        return conf.separator === undefined || conf.separator === null ?
            out :
            out.join(conf.separator);
    },
    set: function (conf, val) {
        var jqInputs = conf._input.find('input');
        if (!Array.isArray(val) && typeof val === 'string') {
            val = val.split(conf.separator || '|');
        }
        else if (!Array.isArray(val)) {
            val = [val];
        }
        var i;
        var len = val.length;
        var found;
        jqInputs.each(function () {
            found = false;
            for (i = 0; i < len; i++) {
                if (this._editor_val == val[i]) {
                    found = true;
                    break;
                }
            }
            this.checked = found;
        });
        _triggerChange(jqInputs);
    },
    update: function (conf, options, append) {
        // Get the current value
        var currVal = checkbox.get(conf);
        checkbox._addOptions(conf, options, append);
        checkbox.set(conf, currVal);
    }
});
var radio = $.extend(true, {}, baseFieldType, {
    // Locally "private" function that can be reused for the create and update methods
    _addOptions: function (conf, opts, append) {
        if (append === void 0) { append = false; }
        var jqInput = conf._input;
        var offset = 0;
        if (!append) {
            jqInput.empty();
        }
        else {
            offset = $('input', jqInput).length;
        }
        if (opts) {
            Editor.pairs(opts, conf.optionsPair, function (val, label, i, attr) {
                jqInput.append('<div>' +
                    '<input id="' + Editor.safeId(conf.id) + '_' + (i + offset) + '" type="radio" name="' + conf.name + '" />' +
                    '<label for="' + Editor.safeId(conf.id) + '_' + (i + offset) + '">' + label + '</label>' +
                    '</div>');
                $('input:last', jqInput).attr('value', val)[0]._editor_val = val;
                if (attr) {
                    $('input:last', jqInput).attr(attr);
                }
            });
        }
    },
    create: function (conf) {
        conf._input = $('<div />');
        radio._addOptions(conf, conf.options || conf.ipOpts);
        // this is ugly, but IE6/7 has a problem with radio elements that are created
        // and checked before being added to the DOM! Basically it doesn't check them. As
        // such we use the _preChecked property to set cache the checked button and then
        // check it again when the display is shown. This has no effect on other browsers
        // other than to cook a few clock cycles.
        this.on('open', function () {
            conf._input.find('input').each(function () {
                if (this._preChecked) {
                    this.checked = true;
                }
            });
        });
        return conf._input[0];
    },
    disable: function (conf) {
        conf._input.find('input').prop('disabled', true);
    },
    enable: function (conf) {
        conf._input.find('input').prop('disabled', false);
    },
    get: function (conf) {
        var el = conf._input.find('input:checked');
        if (el.length) {
            return el[0]._editor_val;
        }
        return conf.unselectedValue !== undefined ?
            conf.unselectedValue :
            undefined;
    },
    set: function (conf, val) {
        conf._input.find('input').each(function () {
            this._preChecked = false;
            if (this._editor_val == val) {
                this.checked = true;
                this._preChecked = true;
            }
            else {
                // In a detached DOM tree, there is no relationship between the
                // input elements, so we need to uncheck any element that does
                // not match the value
                this.checked = false;
                this._preChecked = false;
            }
        });
        _triggerChange(conf._input.find('input:checked'));
    },
    update: function (conf, options, append) {
        var currVal = radio.get(conf);
        radio._addOptions(conf, options, append);
        // Select the current value if it exists in the new data set, otherwise
        // select the first radio input so there is always a value selected
        var inputs = conf._input.find('input');
        radio.set(conf, inputs.filter('[value="' + currVal + '"]').length ?
            currVal :
            inputs.eq(0).attr('value'));
    }
});
var datetime = $.extend(true, {}, baseFieldType, {
    create: function (conf) {
        conf._input = $('<input />').attr($.extend(true, {
            id: Editor.safeId(conf.id),
            type: 'text'
        }, conf.attr));
        if (!DataTable$3.DateTime) {
            Editor.error('DateTime library is required', 15);
        }
        conf._picker = new DataTable$3.DateTime(conf._input, $.extend({
            format: conf.displayFormat || conf.format,
            i18n: this.i18n.datetime,
        }, conf.opts));
        conf._closeFn = function () {
            conf._picker.hide();
        };
        if (conf.keyInput === false) {
            conf._input.on('keydown', function (e) {
                e.preventDefault();
            });
        }
        this.on('close', conf._closeFn);
        return conf._input[0];
    },
    destroy: function (conf) {
        this.off('close', conf._closeFn);
        conf._input.off('keydown');
        conf._picker.destroy();
    },
    errorMessage: function (conf, msg) {
        conf._picker.errorMsg(msg);
    },
    get: function (conf) {
        var val = conf._input.val();
        var inst = conf._picker.c;
        var moment = window.moment;
        // If a wire format is specified, convert the display format to the wire
        return val && conf.wireFormat && moment ?
            moment(val, inst.format, inst.momentLocale, inst.momentStrict).format(conf.wireFormat) :
            val;
    },
    maxDate: function (conf, max) {
        conf._picker.max(max);
    },
    minDate: function (conf, min) {
        conf._picker.min(min);
    },
    // default disable and enable options are okay
    owns: function (conf, node) {
        return conf._picker.owns(node);
    },
    set: function (conf, val) {
        var inst = conf._picker.c;
        var moment = window.moment;
        // If there is a wire format, convert it to the display format
        // Note that special values (e.g. `--now` and empty) do not get formatted
        conf._picker.val(typeof val === 'string' && val && val.indexOf('--') !== 0 && conf.wireFormat && moment ?
            moment(val, conf.wireFormat, inst.momentLocale, inst.momentStrict).format(inst.format) :
            val);
        _triggerChange(conf._input);
    }
});
var upload = $.extend(true, {}, baseFieldType, {
    canReturnSubmit: function (conf, node) {
        return false;
    },
    create: function (conf) {
        var editor = this;
        var container = _commonUpload(editor, conf, function (val) {
            upload.set.call(editor, conf, val[0]);
            editor._event('postUpload', [conf.name, val[0]]);
        });
        return container;
    },
    disable: function (conf) {
        conf._input.find('input').prop('disabled', true);
        conf._enabled = false;
    },
    enable: function (conf) {
        conf._input.find('input').prop('disabled', false);
        conf._enabled = true;
    },
    get: function (conf) {
        return conf._val;
    },
    set: function (conf, val) {
        conf._val = val;
        conf._input.val('');
        var container = conf._input;
        if (conf.display) {
            var rendered = container.find('div.rendered');
            if (conf._val) {
                rendered.html(conf.display(conf._val));
            }
            else {
                rendered
                    .empty()
                    .append('<span>' + (conf.noFileText || 'No file') + '</span>');
            }
        }
        var button = container.find('div.clearValue button');
        if (val && conf.clearText) {
            button.html(conf.clearText);
            container.removeClass('noClear');
        }
        else {
            container.addClass('noClear');
        }
        conf._input.find('input').triggerHandler('upload.editor', [conf._val]);
    }
});
var uploadMany = $.extend(true, {}, baseFieldType, {
    _showHide: function (conf) {
        if (!conf.limit) {
            return;
        }
        conf._container.find('div.limitHide').css('display', conf._val.length >= conf.limit ?
            'none' :
            'block');
        // Used by the Editor.upload static function to truncate if too many
        // files are selected for upload
        conf._limitLeft = conf.limit - conf._val.length;
    },
    canReturnSubmit: function (conf, node) {
        return false;
    },
    create: function (conf) {
        var editor = this;
        var container = _commonUpload(editor, conf, function (val) {
            conf._val = conf._val.concat(val);
            uploadMany.set.call(editor, conf, conf._val);
            editor._event('postUpload', [conf.name, conf._val]);
        }, true);
        container
            .addClass('multi')
            .on('click', 'button.remove', function (e) {
            e.stopPropagation();
            if (conf._enabled) {
                var idx = $(this).data('idx');
                conf._val.splice(idx, 1);
                uploadMany.set.call(editor, conf, conf._val);
            }
        });
        conf._container = container;
        return container;
    },
    disable: function (conf) {
        conf._input.find('input').prop('disabled', true);
        conf._enabled = false;
    },
    enable: function (conf) {
        conf._input.find('input').prop('disabled', false);
        conf._enabled = true;
    },
    get: function (conf) {
        return conf._val;
    },
    set: function (conf, val) {
        // Default value for fields is an empty string, whereas we want []
        if (!val) {
            val = [];
        }
        if (!Array.isArray(val)) {
            throw new Error('Upload collections must have an array as a value');
        }
        conf._val = val;
        conf._input.val('');
        var that = this;
        var container = conf._input;
        if (conf.display) {
            var rendered = container.find('div.rendered').empty();
            if (val.length) {
                var list_1 = $('<ul></ul>').appendTo(rendered);
                $.each(val, function (i, file) {
                    var display = conf.display(file, i);
                    if (display !== null) {
                        list_1.append('<li>' +
                            display +
                            ' <button class="' + that.classes.form.button + ' remove" data-idx="' + i + '">&times;</button>' +
                            '</li>');
                    }
                });
            }
            else {
                rendered.append('<span>' + (conf.noFileText || 'No files') + '</span>');
            }
        }
        uploadMany._showHide(conf);
        conf._input.find('input').triggerHandler('upload.editor', [conf._val]);
    }
});
var datatable = $.extend(true, {}, baseFieldType, {
    _addOptions: function (conf, options, append) {
        if (append === void 0) { append = false; }
        var dt = conf.dt;
        if (!append) {
            dt.clear();
        }
        dt.rows.add(options).draw();
    },
    _jumpToFirst: function (conf) {
        // Find which page in the table the first selected row is
        var idx = conf.dt.row({ order: 'applied', selected: true }).index();
        var page = 0;
        if (typeof idx === 'number') {
            var pageLen = conf.dt.page.info().length;
            var pos = conf.dt.rows({ order: 'applied' }).indexes().indexOf(idx);
            page = pageLen > 0
                ? Math.floor(pos / pageLen)
                : 0;
        }
        conf.dt.page(page).draw(false);
    },
    create: function (conf) {
        var _this = this;
        conf.optionsPair = $.extend({
            label: 'label',
            value: 'value'
        }, conf.optionsPair);
        var table = $('<table>');
        var container = $('<div>').append(table);
        var side = $('<div class="DTE_Field_Type_datatable_info">');
        if (conf.footer) {
            $('<tfoot>')
                .append(Array.isArray(conf.footer)
                ? $('<tr>').append($.map(conf.footer, function (str) { return $('<th>').html(str); }))
                : conf.footer)
                .appendTo(table);
        }
        var dt = table
            .addClass(datatable.tableClass)
            .width('100%')
            .on('init.dt', function (e, settings) {
            var api = new DataTable$3.Api(settings);
            var containerNode = $(api.table(undefined).container());
            // Select init
            DataTable$3.select.init(api);
            // Append side button controls
            side
                .append(containerNode.find('div.dataTables_filter'))
                .append(containerNode.find('div.dt-buttons'))
                .append(containerNode.find('div.dataTables_info'));
        })
            .DataTable($.extend({
            buttons: [],
            columns: [
                {
                    data: conf.optionsPair.label,
                    title: 'Label'
                }
            ],
            deferRender: true,
            dom: 'fiBtp',
            language: {
                paginate: {
                    next: '>',
                    previous: '<',
                },
                search: '',
                searchPlaceholder: 'Search'
            },
            lengthChange: false,
            select: {
                style: conf.multiple ? 'os' : 'single'
            },
        }, conf.config));
        this.on('open', function () {
            if (dt.search()) {
                dt.search('').draw();
            }
            dt.columns.adjust();
        });
        // Change event for when the user does a select - `set` will do its own
        // triggering of the change for the api
        dt.on('user-select', function () {
            _triggerChange($(conf.dt.table().container()));
        });
        if (conf.editor) {
            conf.editor.table(dt);
            conf.editor.on('submitComplete', function (e, json, data, action) {
                if (action === 'create') {
                    var _loop_1 = function (dp) {
                        dt
                            .rows(function (idx, d) { return d === dp; })
                            .select();
                    };
                    // Automatically select the new data
                    for (var _i = 0, _a = json.data; _i < _a.length; _i++) {
                        var dp = _a[_i];
                        _loop_1(dp);
                    }
                }
                else if (action === 'edit' || action === 'remove') {
                    _this._dataSource('refresh');
                }
                datatable._jumpToFirst(conf);
            });
        }
        conf.dt = dt;
        datatable._addOptions(conf, conf.options || []);
        return {
            input: container,
            side: side,
        };
    },
    disable: function (conf) {
        conf.dt.select.style('api');
        conf.dt.buttons().container().css('display', 'none');
    },
    dt: function (conf) {
        return conf.dt;
    },
    enable: function (conf) {
        conf.dt.select.style(conf.multiple ? 'os' : 'single');
        conf.dt.buttons().container().css('display', 'block');
    },
    get: function (conf) {
        var rows = conf.dt
            .rows({ selected: true })
            .data()
            .pluck(conf.optionsPair.value)
            .toArray();
        return conf.separator || !conf.multiple
            ? rows.join(conf.separator || ',')
            : rows;
    },
    set: function (conf, val, localUpdate) {
        // Convert to an array of values - works for both single and multiple
        if (conf.multiple && conf.separator && !Array.isArray(val)) {
            val = typeof val === 'string' ?
                val.split(conf.separator) :
                [];
        }
        else if (!Array.isArray(val)) {
            val = [val];
        }
        // if ( ! localUpdate ) {
        // 	conf._lastSet = val;
        // }
        var valueFn = dataGet(conf.optionsPair.value);
        conf.dt.rows({ selected: true }).deselect();
        conf.dt.rows(function (idx, data, node) { return val.indexOf(valueFn(data)) !== -1; }).select();
        // Jump to the first page with a selected row (if there are any)
        datatable._jumpToFirst(conf);
        // Update will call change itself, otherwise multiple might be called
        if (!localUpdate) {
            _triggerChange($(conf.dt.table().container()));
        }
    },
    tableClass: '',
    update: function (conf, options, append) {
        datatable._addOptions(conf, options, append);
        // Attempt to set the last selected value (set by the API or the end
        // user, they get equal priority)
        var lastSet = conf._lastSet;
        if (lastSet !== undefined) {
            datatable.set(conf, lastSet, true);
        }
        _triggerChange($(conf.dt.table().container()));
    }
});

var defaults = {
    className: '',
    compare: null,
    data: '',
    def: '',
    entityDecode: true,
    fieldInfo: '',
    getFormatter: null,
    id: '',
    label: '',
    labelInfo: '',
    message: '',
    multiEditable: true,
    name: null,
    nullDefault: false,
    setFormatter: null,
    submit: true,
    type: 'text'
};

var DataTable$2 = $.fn.dataTable;
var Field = /** @class */ (function () {
    function Field(options, classes, host) {
        var that = this;
        var multiI18n = host.internalI18n().multi;
        var opts = $.extend(true, {}, Field.defaults, options);
        if (!Editor.fieldTypes[opts.type]) {
            throw new Error('Error adding field - unknown field type ' + opts.type);
        }
        this.s = {
            classes: classes,
            host: host,
            multiIds: [],
            multiValue: false,
            multiValues: {},
            name: opts.name,
            opts: opts,
            processing: false,
            type: Editor.fieldTypes[opts.type],
        };
        // No id, so assign one to have the label reference work
        if (!opts.id) {
            opts.id = 'DTE_Field_' + opts.name;
        }
        // If no `data` option is given, then we use the name from the field as the
        // data prop to read data for the field from DataTables
        if (opts.data === '') {
            opts.data = opts.name;
        }
        // Get and set functions in the data object for the record
        this.valFromData = function (d) {
            // wrapper to automatically pass `editor` as the type
            return dataGet(opts.data)(d, 'editor');
        };
        this.valToData = dataSet(opts.data); // set val to data
        // Field HTML structure
        var template = $('<div class="' +
            classes.wrapper + ' ' + classes.typePrefix + opts.type + ' ' + classes.namePrefix + opts.name + ' ' + opts.className +
            '">' +
            '<label data-dte-e="label" class="' + classes.label + '" for="' + Editor.safeId(opts.id) + '">' +
            opts.label +
            '<div data-dte-e="msg-label" class="' + classes['msg-label'] + '">' + opts.labelInfo + '</div>' +
            '</label>' +
            '<div data-dte-e="input" class="' + classes.input + '">' +
            // Field specific HTML is added here if there is any
            '<div data-dte-e="input-control" class="' + classes.inputControl + '"></div>' +
            '<div data-dte-e="multi-value" class="' + classes.multiValue + '">' +
            multiI18n.title +
            '<span data-dte-e="multi-info" class="' + classes.multiInfo + '">' +
            multiI18n.info +
            '</span>' +
            '</div>' +
            '<div data-dte-e="msg-multi" class="' + classes.multiRestore + '">' +
            multiI18n.restore +
            '</div>' +
            '<div data-dte-e="msg-error" class="' + classes['msg-error'] + '"></div>' +
            '<div data-dte-e="msg-message" class="' + classes['msg-message'] + '">' + opts.message + '</div>' +
            '<div data-dte-e="msg-info" class="' + classes['msg-info'] + '">' + opts.fieldInfo + '</div>' +
            '</div>' +
            '<div data-dte-e="field-processing" class="' + classes.processing + '"><span></span></div>' +
            '</div>');
        var input = this._typeFn('create', opts);
        var side = null;
        if (input && input.side) {
            side = input.side;
            input = input.input;
        }
        if (input !== null) {
            el('input-control', template).prepend(input);
        }
        else {
            template.css('display', 'none');
        }
        this.dom = {
            container: template,
            fieldError: el('msg-error', template),
            fieldInfo: el('msg-info', template),
            fieldMessage: el('msg-message', template),
            inputControl: el('input-control', template),
            label: el('label', template).append(side),
            labelInfo: el('msg-label', template),
            multi: el('multi-value', template),
            multiInfo: el('multi-info', template),
            multiReturn: el('msg-multi', template),
            processing: el('field-processing', template)
        };
        // On click - set a common value for the field
        this.dom.multi.on('click', function () {
            if (that.s.opts.multiEditable && !template.hasClass(classes.disabled) && opts.type !== 'readonly') {
                that.val('');
                that.focus();
            }
        });
        this.dom.multiReturn.on('click', function () {
            that.multiRestore();
        });
        // Field type extension methods - add a method to the field for the public
        // methods that each field type defines beyond the default ones that already
        // exist as part of this instance
        $.each(this.s.type, function (name, fn) {
            if (typeof fn === 'function' && that[name] === undefined) {
                that[name] = function () {
                    var args = Array.prototype.slice.call(arguments);
                    args.unshift(name);
                    var ret = that._typeFn.apply(that, args);
                    // Return the given value if there is one, or the field instance
                    // for chaining if there is no value
                    return ret === undefined ?
                        that :
                        ret;
                };
            }
        });
    }
    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * Public
     */
    Field.prototype.def = function (set) {
        var opts = this.s.opts;
        if (set === undefined) {
            // Backwards compat
            var def = opts['default'] !== undefined ?
                opts['default'] :
                opts.def;
            return typeof def === 'function' ?
                def() :
                def;
        }
        opts.def = set;
        return this;
    };
    Field.prototype.disable = function () {
        this.dom.container.addClass(this.s.classes.disabled);
        this._typeFn('disable');
        return this;
    };
    Field.prototype.displayed = function () {
        var container = this.dom.container;
        return container.parents('body').length && container.css('display') !== 'none' ?
            true :
            false;
    };
    Field.prototype.enable = function (toggle) {
        if (toggle === void 0) { toggle = true; }
        if (toggle === false) {
            return this.disable();
        }
        this.dom.container.removeClass(this.s.classes.disabled);
        this._typeFn('enable');
        return this;
    };
    Field.prototype.enabled = function () {
        return this.dom.container.hasClass(this.s.classes.disabled) === false;
    };
    Field.prototype.error = function (msg, fn) {
        var classes = this.s.classes;
        // Add or remove the error class
        if (msg) {
            this.dom.container.addClass(classes.error);
        }
        else {
            this.dom.container.removeClass(classes.error);
        }
        this._typeFn('errorMessage', msg);
        return this._msg(this.dom.fieldError, msg, fn);
    };
    Field.prototype.fieldInfo = function (msg) {
        return this._msg(this.dom.fieldInfo, msg);
    };
    Field.prototype.isMultiValue = function () {
        return this.s.multiValue && this.s.multiIds.length !== 1;
    };
    Field.prototype.inError = function () {
        return this.dom.container.hasClass(this.s.classes.error);
    };
    Field.prototype.input = function () {
        return this.s.type.input ?
            this._typeFn('input') :
            $('input, select, textarea', this.dom.container);
    };
    Field.prototype.focus = function () {
        if (this.s.type.focus) {
            this._typeFn('focus');
        }
        else {
            $('input, select, textarea', this.dom.container).focus();
        }
        return this;
    };
    Field.prototype.get = function () {
        // When multi-value a single get is undefined
        if (this.isMultiValue()) {
            return undefined;
        }
        return this._format(this._typeFn('get'), this.s.opts.getFormatter);
    };
    Field.prototype.hide = function (animate) {
        var el = this.dom.container;
        if (animate === undefined) {
            animate = true;
        }
        if (this.s.host.display() && animate && $.fn.slideUp) {
            el.slideUp();
        }
        else {
            el.css('display', 'none');
        }
        return this;
    };
    Field.prototype.label = function (str) {
        var label = this.dom.label;
        var labelInfo = this.dom.labelInfo.detach();
        if (str === undefined) {
            return label.html();
        }
        label.html(str);
        label.append(labelInfo);
        return this;
    };
    Field.prototype.labelInfo = function (msg) {
        return this._msg(this.dom.labelInfo, msg);
    };
    Field.prototype.message = function (msg, fn) {
        return this._msg(this.dom.fieldMessage, msg, fn);
    };
    // There is no `multiVal()` as its arguments could be ambiguous
    // id is an idSrc value _only_
    Field.prototype.multiGet = function (id) {
        var value;
        var multiValues = this.s.multiValues;
        var multiIds = this.s.multiIds;
        var isMultiValue = this.isMultiValue();
        if (id === undefined) {
            var fieldVal = this.val();
            // Get an object with the values for each item being edited
            value = {};
            for (var _i = 0, multiIds_1 = multiIds; _i < multiIds_1.length; _i++) {
                var multiId = multiIds_1[_i];
                value[multiId] = isMultiValue ?
                    multiValues[multiId] :
                    fieldVal;
            }
        }
        else if (isMultiValue) {
            // Individual value
            value = multiValues[id];
        }
        else {
            // Common value
            value = this.val();
        }
        return value;
    };
    Field.prototype.multiRestore = function () {
        this.s.multiValue = true;
        this._multiValueCheck();
    };
    Field.prototype.multiSet = function (id, val, recalc) {
        if (recalc === void 0) { recalc = true; }
        var that = this;
        var multiValues = this.s.multiValues;
        var multiIds = this.s.multiIds;
        if (val === undefined) {
            val = id;
            id = undefined;
        }
        // Set
        var set = function (idSrc, valIn) {
            // Get an individual item's value - add the id to the edit ids if
            // it isn't already in the set.
            if ($.inArray(idSrc, multiIds) === -1) {
                multiIds.push(idSrc);
            }
            multiValues[idSrc] = that._format(valIn, that.s.opts.setFormatter);
        };
        if ($.isPlainObject(val) && id === undefined) {
            // idSrc / value pairs passed in
            $.each(val, function (idSrc, innerVal) {
                set(idSrc, innerVal);
            });
        }
        else if (id === undefined) {
            // Set same value for all existing ids
            $.each(multiIds, function (i, idSrc) {
                set(idSrc, val);
            });
        }
        else {
            // Setting an individual property
            set(id, val);
        }
        this.s.multiValue = true;
        if (recalc) {
            this._multiValueCheck();
        }
        return this;
    };
    Field.prototype.name = function () {
        return this.s.opts.name;
    };
    Field.prototype.node = function () {
        return this.dom.container[0];
    };
    Field.prototype.nullDefault = function () {
        return this.s.opts.nullDefault;
    };
    Field.prototype.processing = function (set) {
        if (set === undefined) {
            return this.s.processing;
        }
        this.dom.processing.css('display', set ? 'block' : 'none');
        this.s.processing = set;
        this.s.host.internalEvent('processing-field', [set]);
        return this;
    };
    // multiCheck is not publicly documented
    Field.prototype.set = function (val, multiCheck) {
        if (multiCheck === void 0) { multiCheck = true; }
        var decodeFn = function (d) {
            return typeof d !== 'string' ?
                d :
                d
                    .replace(/&gt;/g, '>')
                    .replace(/&lt;/g, '<')
                    .replace(/&amp;/g, '&')
                    .replace(/&quot;/g, '"')
                    .replace(/&#163;/g, '£')
                    .replace(/&#39;/g, '\'')
                    .replace(/&#10;/g, '\n');
        };
        this.s.multiValue = false;
        var decode = this.s.opts.entityDecode;
        if (decode === undefined || decode === true) {
            if (Array.isArray(val)) {
                for (var i = 0, ien = val.length; i < ien; i++) {
                    val[i] = decodeFn(val[i]);
                }
            }
            else {
                val = decodeFn(val);
            }
        }
        // If triggered from multi check we don't want to do formatting or multi checking again
        if (multiCheck === true) {
            val = this._format(val, this.s.opts.setFormatter);
            this._typeFn('set', val);
            this._multiValueCheck();
        }
        else {
            this._typeFn('set', val);
        }
        return this;
    };
    Field.prototype.show = function (animate, toggle) {
        if (animate === void 0) { animate = true; }
        if (toggle === void 0) { toggle = true; }
        if (toggle === false) {
            return this.hide(animate);
        }
        var el = this.dom.container;
        if (this.s.host.display() && animate && $.fn.slideDown) {
            el.slideDown();
        }
        else {
            el.css('display', ''); // empty to restore css default (flex or block)
        }
        return this;
    };
    Field.prototype.update = function (options, append) {
        if (append === void 0) { append = false; }
        if (this.s.type.update) {
            this._typeFn('update', options, append);
        }
        return this;
    };
    Field.prototype.val = function (val) {
        return val === undefined ?
            this.get() :
            this.set(val);
    };
    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * Internal - Called from Editor only and are not publicly documented -
     * these APIs can change!
     */
    Field.prototype.compare = function (value, original) {
        var compare = this.s.opts.compare || deepCompare;
        return compare(value, original);
    };
    Field.prototype.dataSrc = function () {
        return this.s.opts.data;
    };
    Field.prototype.destroy = function () {
        // remove element
        this.dom.container.remove();
        // field's own destroy method if there is one
        this._typeFn('destroy');
        return this;
    };
    Field.prototype.multiEditable = function () {
        return this.s.opts.multiEditable;
    };
    Field.prototype.multiIds = function () {
        return this.s.multiIds;
    };
    Field.prototype.multiInfoShown = function (show) {
        this.dom.multiInfo.css({ display: show ? 'block' : 'none' });
    };
    Field.prototype.multiReset = function () {
        this.s.multiIds = [];
        this.s.multiValues = {};
    };
    Field.prototype.submittable = function () {
        return this.s.opts.submit;
    };
    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * Internal
     */
    Field.prototype._msg = function (el, msg, fn) {
        if (msg === undefined) {
            return el.html();
        }
        if (typeof msg === 'function') {
            var editor = this.s.host;
            msg = msg(editor, new DataTable$2.Api(editor.internalSettings().table));
        }
        if (el.parent().is(':visible') && $.fn.animate) {
            el.html(msg);
            if (msg) {
                el.slideDown(fn); // fn can be undefined - so jQuery won't execute it
            }
            else {
                el.slideUp(fn);
            }
        }
        else {
            // Not visible, so immediately set, or blank out the element
            el
                .html(msg || '')
                .css('display', msg ? 'block' : 'none');
            if (fn) {
                fn();
            }
        }
        return this;
    };
    Field.prototype._multiValueCheck = function () {
        var last;
        var ids = this.s.multiIds;
        var values = this.s.multiValues;
        var isMultiValue = this.s.multiValue;
        var isMultiEditable = this.s.opts.multiEditable;
        var val;
        var different = false;
        if (ids) {
            for (var i = 0; i < ids.length; i++) {
                val = values[ids[i]];
                if (i > 0 && !deepCompare(val, last)) {
                    different = true;
                    break;
                }
                last = val;
            }
        }
        if ((different && isMultiValue) || (!isMultiEditable && this.isMultiValue())) {
            // Different values or same values, but not multiple editable
            this.dom.inputControl.css({ display: 'none' });
            this.dom.multi.css({ display: 'block' });
        }
        else {
            // All the same value
            this.dom.inputControl.css({ display: 'block' });
            this.dom.multi.css({ display: 'none' });
            if (isMultiValue && !different) {
                this.set(last, false);
            }
        }
        this.dom.multiReturn.css({
            display: ids && ids.length > 1 && different && !isMultiValue ?
                'block' :
                'none'
        });
        // Update information label
        var i18n = this.s.host.internalI18n().multi;
        this.dom.multiInfo.html(isMultiEditable ? i18n.info : i18n.noMulti);
        this.dom.multi.toggleClass(this.s.classes.multiNoEdit, !isMultiEditable);
        this.s.host.internalMultiInfo();
        return true;
    };
    Field.prototype._typeFn = function (name) {
        var args = [];
        for (var _i = 1; _i < arguments.length; _i++) {
            args[_i - 1] = arguments[_i];
        }
        // Insert the options as the first parameter - all field type methods
        // take the field's configuration object as the first parameter
        args.unshift(this.s.opts);
        var fn = this.s.type[name];
        if (fn) {
            return fn.apply(this.s.host, args);
        }
    };
    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * Private
     */
    Field.prototype._errorNode = function () {
        return this.dom.fieldError;
    };
    Field.prototype._format = function (val, formatter) {
        if (formatter) {
            if (Array.isArray(formatter)) {
                var args = formatter.slice();
                var name_1 = args.shift();
                formatter = Field.formatters[name_1].apply(this, args);
            }
            return formatter.call(this.s.host, val, this);
        }
        return val;
    };
    Field.defaults = defaults;
    Field.formatters = {};
    return Field;
}());

var button = {
    action: null,
    className: null,
    tabIndex: 0,
    text: null,
};

var displayController = {
    close: function () { },
    init: function () { },
    node: function () { },
    open: function () { }
};

var DataTable$1 = $.fn.dataTable;
/*
 * DataTables 1.10 API integration. Provides the ability to control basic Editor
 * aspects from the DataTables API. Full control does of course require use of
 * the Editor API though.
 */
var apiRegister = DataTable$1.Api.register;
function _getInst(api) {
    var ctx = api.context[0];
    return ctx.oInit.editor || ctx._editor;
}
// Set sensible defaults for the editing options
function _setBasic(inst, opts, type, plural) {
    if (!opts) {
        opts = {};
    }
    if (opts.buttons === undefined) {
        opts.buttons = '_basic';
    }
    if (opts.title === undefined) {
        opts.title = inst.i18n[type].title;
    }
    if (opts.message === undefined) {
        if (type === 'remove') {
            var confirm_1 = inst.i18n[type].confirm;
            opts.message = plural !== 1 ? confirm_1._.replace(/%d/, plural) : confirm_1['1'];
        }
        else {
            opts.message = '';
        }
    }
    return opts;
}
apiRegister('editor()', function () {
    return _getInst(this);
});
// Row editing
apiRegister('row.create()', function (opts) {
    // main
    var inst = _getInst(this);
    inst.create(_setBasic(inst, opts, 'create'));
    return this;
});
apiRegister('row().edit()', function (opts) {
    // main
    var inst = _getInst(this);
    inst.edit(this[0][0], _setBasic(inst, opts, 'edit'));
    return this;
});
apiRegister('rows().edit()', function (opts) {
    // main
    var inst = _getInst(this);
    inst.edit(this[0], _setBasic(inst, opts, 'edit'));
    return this;
});
apiRegister('row().delete()', function (opts) {
    // main
    var inst = _getInst(this);
    inst.remove(this[0][0], _setBasic(inst, opts, 'remove', 1));
    return this;
});
apiRegister('rows().delete()', function (opts) {
    // main
    var inst = _getInst(this);
    inst.remove(this[0], _setBasic(inst, opts, 'remove', this[0].length));
    return this;
});
apiRegister('cell().edit()', function (type, opts) {
    // inline or bubble
    if (!type) {
        type = 'inline';
    }
    else if ($.isPlainObject(type)) {
        opts = type;
        type = 'inline';
    }
    _getInst(this)[type](this[0][0], opts);
    return this;
});
apiRegister('cells().edit()', function (opts) {
    // bubble only at the moment
    _getInst(this).bubble(this[0], opts);
    return this;
});
apiRegister('file()', file);
apiRegister('files()', files);
// Global listener for file information updates via DataTables' Ajax JSON
$(document).on('xhr.dt', function (e, ctx, json) {
    if (e.namespace !== 'dt') {
        return;
    }
    if (json && json.files) {
        $.each(json.files, function (name, filesIn) {
            if (!Editor.files[name]) {
                Editor.files[name] = {};
            }
            $.extend(Editor.files[name], filesIn);
        });
    }
});

/*
 * Add helpful buttons to make life easier
 *
 * Note that the values that require a string to make any sense (the button text
 * for example) are set by Editor when Editor is initialised through the i18n
 * options.
 */
var _buttons = $.fn.dataTable.ext.buttons;
$.extend(_buttons, {
    create: {
        action: function (e, dt, node, config) {
            var that = this;
            var editor = config.editor;
            this.processing(true);
            editor
                .one('preOpen', function () {
                that.processing(false);
            })
                .create($.extend({
                buttons: config.formButtons,
                message: config.formMessage || editor.i18n.create.message,
                nest: true,
                title: config.formTitle || editor.i18n.create.title
            }, config.formOptions));
        },
        className: 'buttons-create',
        editor: null,
        formButtons: {
            action: function (e) {
                this.submit();
            },
            text: function (editor) {
                return editor.i18n.create.submit;
            }
        },
        formMessage: null,
        formOptions: {},
        formTitle: null,
        text: function (dt, node, config) {
            return dt.i18n('buttons.create', config.editor.i18n.create.button);
        },
    },
    createInline: {
        action: function (e, dt, node, config) {
            config.editor.inlineCreate(config.position, config.formOptions);
        },
        className: 'buttons-create',
        editor: null,
        formButtons: {
            action: function (e) {
                this.submit();
            },
            text: function (editor) {
                return editor.i18n.create.submit;
            }
        },
        formOptions: {},
        position: 'start',
        text: function (dt, node, config) {
            return dt.i18n('buttons.create', config.editor.i18n.create.button);
        },
    },
    edit: {
        action: function (e, dt, node, config) {
            var that = this;
            var editor = config.editor;
            var rows = dt.rows({ selected: true }).indexes();
            var columns = dt.columns({ selected: true }).indexes();
            var cells = dt.cells({ selected: true }).indexes();
            var items = columns.length || cells.length ?
                {
                    cells: cells,
                    columns: columns,
                    rows: rows
                } :
                rows;
            this.processing(true);
            editor
                .one('preOpen', function () {
                that.processing(false);
            })
                .edit(items, $.extend({
                buttons: config.formButtons,
                message: config.formMessage || editor.i18n.edit.message,
                nest: true,
                title: config.formTitle || editor.i18n.edit.title
            }, config.formOptions));
        },
        className: 'buttons-edit',
        editor: null,
        extend: 'selected',
        formButtons: {
            action: function (e) {
                this.submit();
            },
            text: function (editor) {
                return editor.i18n.edit.submit;
            },
        },
        formMessage: null,
        formOptions: {},
        formTitle: null,
        text: function (dt, node, config) {
            return dt.i18n('buttons.edit', config.editor.i18n.edit.button);
        },
    },
    remove: {
        action: function (e, dt, node, config) {
            var that = this;
            var editor = config.editor;
            this.processing(true);
            editor
                .one('preOpen', function () {
                that.processing(false);
            })
                .remove(dt.rows({ selected: true }).indexes(), $.extend({
                buttons: config.formButtons,
                message: config.formMessage,
                nest: true,
                title: config.formTitle || editor.i18n.remove.title
            }, config.formOptions));
        },
        className: 'buttons-remove',
        editor: null,
        extend: 'selected',
        formButtons: {
            action: function (e) {
                this.submit();
            },
            text: function (editor) {
                return editor.i18n.remove.submit;
            },
        },
        formMessage: function (editor, dt) {
            var rows = dt.rows({ selected: true }).indexes();
            var i18n = editor.i18n.remove;
            var question = typeof i18n.confirm === 'string' ?
                i18n.confirm :
                i18n.confirm[rows.length] ?
                    i18n.confirm[rows.length] : i18n.confirm._;
            return question.replace(/%d/g, rows.length);
        },
        formOptions: {},
        formTitle: null,
        limitTo: ['rows'],
        text: function (dt, node, config) {
            return dt.i18n('buttons.remove', config.editor.i18n.remove.button);
        },
    }
});
// Reuse the standard edit and remove buttons for their singular equivalent,
// but set it to extend the single selected button only
_buttons.editSingle = $.extend({}, _buttons.edit);
_buttons.editSingle.extend = 'selectedSingle';
_buttons.removeSingle = $.extend({}, _buttons.remove);
_buttons.removeSingle.extend = 'selectedSingle';


if (!DataTable || !DataTable.versionCheck || !DataTable.versionCheck('1.10.20')) {
    throw new Error('Editor requires DataTables 1.10.20 or newer');
}
var Editor = /** @class */ (function () {
    function Editor(init) {
        var _this = this;
        this.add = add;
        this.ajax = ajax;
        this.background = background;
        this.blur = blur;
        this.bubble = bubble;
        this.bubblePosition = bubblePosition;
        this.buttons = buttons;
        this.clear = clear;
        this.close = close;
        this.create = create;
        this.undependent = undependent;
        this.dependent = dependent;
        this.destroy = destroy;
        this.disable = disable;
        this.display = display;
        this.displayed = displayed;
        this.displayNode = displayNode;
        this.edit = edit;
        this.enable = enable;
        this.error = error$1;
        this.field = field;
        this.fields = fields;
        this.file = file;
        this.files = files;
        this.get = get;
        this.hide = hide;
        this.ids = ids;
        this.inError = inError;
        this.inline = inline;
        this.inlineCreate = inlineCreate;
        this.message = message;
        this.mode = mode;
        this.modifier = modifier;
        this.multiGet = multiGet;
        this.multiSet = multiSet;
        this.node = node;
        this.off = off;
        this.on = on;
        this.one = one;
        this.open = open;
        this.order = order;
        this.remove = remove;
        this.set = set;
        this.show = show;
        this.submit = submit;
        this.table = table;
        this.template = template;
        this.title = title;
        this.val = val;
        this._actionClass = _actionClass;
        this._ajax = _ajax;
        this._animate = _animate;
        this._assembleMain = _assembleMain;
        this._blur = _blur;
        this._clearDynamicInfo = _clearDynamicInfo;
        this._close = _close;
        this._closeReg = _closeReg;
        this._crudArgs = _crudArgs;
        this._dataSource = _dataSource;
        this._displayReorder = _displayReorder;
        this._edit = _edit;
        this._event = _event;
        this._eventName = _eventName;
        this._fieldFromNode = _fieldFromNode;
        this._fieldNames = _fieldNames;
        this._focus = _focus;
        this._formOptions = _formOptions;
        this._inline = _inline;
        this._optionsUpdate = _optionsUpdate;
        this._message = _message;
        this._multiInfo = _multiInfo;
        this._nestedClose = _nestedClose;
        this._nestedOpen = _nestedOpen;
        this._postopen = _postopen;
        this._preopen = _preopen;
        this._processing = _processing;
        this._noProcessing = _noProcessing;
        this._submit = _submit;
        this._submitTable = _submitTable;
        this._submitSuccess = _submitSuccess;
        this._submitError = _submitError;
        this._tidy = _tidy;
        this._weakInArray = _weakInArray;
        if (!(this instanceof Editor)) {
            alert('DataTables Editor must be initialised as a \'new\' instance');
        }
        init = $.extend(true, {}, Editor.defaults, init);
        this.s = $.extend(true, {}, Editor.models.settings, {
            actionName: init.actionName,
            ajax: init.ajax,
            formOptions: init.formOptions,
            idSrc: init.idSrc,
            table: init.domTable || init.table,
            template: init.template ?
                $(init.template).detach() : null
        });
        this.classes = $.extend(true, {}, Editor.classes);
        this.i18n = init.i18n;
        // Increment the unique counter for the next instance
        Editor.models.settings.unique++;
        var that = this;
        var classes = this.classes;
        var wrapper = $('<div class="' + classes.wrapper + '">' +
            '<div data-dte-e="processing" class="' + classes.processing.indicator + '"><span></span></div>' +
            '<div data-dte-e="body" class="' + classes.body.wrapper + '">' +
            '<div data-dte-e="body_content" class="' + classes.body.content + '"></div>' +
            '</div>' +
            '<div data-dte-e="foot" class="' + classes.footer.wrapper + '">' +
            '<div class="' + classes.footer.content + '"></div>' +
            '</div>' +
            '</div>');
        var form = $('<form data-dte-e="form" class="' + classes.form.tag + '">' +
            '<div data-dte-e="form_content" class="' + classes.form.content + '"></div>' +
            '</form>');
        this.dom = {
            body: el('body', wrapper)[0],
            bodyContent: el('body_content', wrapper)[0],
            buttons: $('<div data-dte-e="form_buttons" class="' + classes.form.buttons + '"></div>')[0],
            footer: el('foot', wrapper)[0],
            form: form[0],
            formContent: el('form_content', form)[0],
            formError: $('<div data-dte-e="form_error" class="' + classes.form.error + '"></div>')[0],
            formInfo: $('<div data-dte-e="form_info" class="' + classes.form.info + '"></div>')[0],
            header: $('<div data-dte-e="head" class="' +
                classes.header.wrapper +
                '"><div class="' +
                classes.header.content +
                '"></div></div>')[0],
            processing: el('processing', wrapper)[0],
            wrapper: wrapper[0],
        };
        // Bind callback methods
        $.each(init.events, function (evt, fn) {
            that.on(evt, function () {
                var argsIn = [];
                for (var _i = 0; _i < arguments.length; _i++) {
                    argsIn[_i] = arguments[_i];
                }
                // When giving events in the constructor the event argument was not
                // given in 1.2-, so we remove it here. This is solely for
                // backwards compatibility as the events in the initialisation are
                // not documented in 1.3+.
                fn.apply(that, argsIn);
            });
        });
        // Cache the DOM nodes
        this.dom;
        var table$1 = this.s.table;
        // Add any fields which are given on initialisation
        if (init.fields) {
            this.add(init.fields);
        }
        $(document)
            .on('init.dt.dte' + this.s.unique, function (e, settings, json) {
            if (_this.s.table && settings.nTable === $(table$1)[0]) {
                // Attempt to attach to a DataTable automatically when the table is
                // initialised
                settings._editor = _this;
            }
        })
            .on('i18n.dt.dte' + this.s.unique, function (e, settings) {
            if (_this.s.table && settings.nTable === $(table$1)[0]) {
                // Use loaded language options
                if (settings.oLanguage.editor) {
                    $.extend(true, _this.i18n, settings.oLanguage.editor);
                }
            }
        })
            .on('xhr.dt.dte' + this.s.unique, function (e, settings, json) {
            if (json && _this.s.table && settings.nTable === $(table$1)[0]) {
                // Automatically update fields which have a field name defined in
                // the returned json - saves an `initComplete` for the user
                _this._optionsUpdate(json);
            }
        });
        // Prep the display controller
        if (!Editor.display[init.display]) {
            throw new Error('Cannot find display controller ' + init.display);
        }
        this.s.displayController = Editor.display[init.display].init(this);
        this._event('initComplete', []);
        $(document).trigger('initEditor', [this]);
    }
    // Expose internal methods and options for the Field class to use
    // These are not publicly documented.
    /** @internal */
    Editor.prototype.internalEvent = function (name, args) {
        this._event(name, args);
    };
    /** @internal */
    Editor.prototype.internalI18n = function () {
        return this.i18n;
    };
    /** @internal */
    Editor.prototype.internalMultiInfo = function () {
        return this._multiInfo();
    };
    /** @internal */
    Editor.prototype.internalSettings = function () {
        return this.s;
    };
    Editor.fieldTypes = {
        checkbox: checkbox,
        datatable: datatable,
        datetime: datetime,
        hidden: hidden,
        password: password,
        radio: radio,
        readonly: readonly,
        select: select,
        text: text,
        textarea: textarea,
        upload: upload,
        uploadMany: uploadMany
    };
    Editor.files = {};
    Editor.version = '2.0.9';
    Editor.classes = classNames;
    Editor.Field = Field;
    Editor.DateTime = null;
    Editor.error = error;
    Editor.pairs = pairs;
    Editor.upload = upload$1;
    Editor.defaults = defaults$1;
    Editor.models = {
        button: button,
        displayController: displayController,
        fieldType: fieldType,
        formOptions: formOptions,
        settings: settings,
    };
    Editor.dataSources = {
        dataTable: dataSource$1,
        html: dataSource,
    };
    Editor.display = {
        envelope: envelope,
        lightbox: self,
    };
    Editor.safeId = function (id) {
        return safeDomId(id, '');
    };
    return Editor;
}());
DataTable.Editor = Editor;
$.fn.dataTable.Editor = Editor;
if (DataTable.DateTime) {
    Editor.DateTime = DataTable.DateTime;
}
// If there are field types available on DataTables we copy them in (after the
// built in ones to allow overrides) and then expose the field types object.
if (DataTable.ext.editorFields) {
    $.extend(Editor.fieldTypes, DataTable.ext.editorFields);
}
DataTable.ext.editorFields = Editor.fieldTypes;



return Editor;
}));
