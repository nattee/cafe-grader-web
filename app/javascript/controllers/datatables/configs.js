import { columns, renderers } from 'controllers/datatables/columns'

const baseConfig = {
  responsive: true,
  processing: true,
  destroy: true,
  paging: false,
  rowId: 'id',
};

// this is the default for ajax
// it is used in a config of a table that do ajax
// we also have to set the url value which is set via data-* values
// please see the connect() function in the init.js
//
// also, when using this value, always do ajax: { ...baseAjax }, so that the value is COPIED instead of references
const baseAjax = {
  type: 'POST',
  dataType: 'json',
  beforeSend: (request) => {
    request.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'));
  },
};

// we should define the config here
// however, ajax value can be set via 
export const configs = {
  default: { ...baseConfig },
  solidQueueJob: {
    ...baseConfig,
    paging: true,
    pageLength: 25,
    columns: [
      columns.id,
      columns.solidQueueJob.queue,
      columns.solidQueueJob.class,
      columns.solidQueueJob.status,
      columns.solidQueueJob.submissionId,
      columns.solidQueueJob.user,
      columns.solidQueueJob.problem,
      columns.solidQueueJob.detail,
      columns.solidQueueJob.createdAt,
    ],
    ajax: { ...baseAjax }, //use spread so that it is copied
  },
  // /contests/
  contestIndex: {
    ...baseConfig,
    ajax: {
      type: 'POST',
      headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'), },
      dataSrc: function(json) {
        window.userCount = json.userCount
        window.probCount = json.probCount
        return json.data
      }
    },
    layout: {
      topStart: 'info',
      topEnd: 'search',
    },
    columns: [ 
      columns.contest.name,
      columns.contest.description,
      columns.contest.enableToggle,
      columns.contest.finalized,
      columns.contest.userProb,
      columns.contest.start,
      columns.contest.stop,
      columns.contest.manageLink,
      columns.contest.watchLink,
      columns.contest.cloneButton,
      columns.contest.deleteButton,
    ],
    columnDefs: [ {orderable: false, targets: [2,3,7,8,9,10]} ],
    order: [[5, 'desc']], // order by starting time
    drawCallback: function (settings) {
      var api = this.api();
      api.columns.adjust()
    },
  },
  contestManageUser: {
    ...baseConfig,
    paging: false,
    order: [[0,'asc']],
    ajax: {
      type: 'POST',
      headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'), },
    },
    layout: {
      topStart: 'info',
      topEnd: 'search',
    },
    columns: [ 
      {data: 'login'},
      {data: 'full_name'},
      {data: 'role'},  // this is user role column, index 2, must be hidden and has fixed ordering
      {data: 'seat'},
      {data: 'remark'},
      {data: null, render: renderers.startStopOffsetRender},
      {data: 'user_id', render: cafe.dt.render.button(null, {element_type: 'switch', action: 'contest#postUserAction', command: 'toggle', checked_data_field: 'enabled'})},
      {data: 'user_id', render: cafe.dt.render.button(`[${cafe.msi('lock_reset','md-18')} Clear]`, {element_type: 'link', className: 'link-primary', action: 'contest#postUserAction', command: 'clear_ip'} )},
      {data: 'user_id', render: cafe.dt.render.button(`[${cafe.msi('person_remove','md-18')} Remove]`, {element_type: 'link', className: 'link-danger', action: 'contest#postUserAction', command: 'remove', confirm: 'Remove user from contest?'})},
      {data: 'user_id', render: renderers.roleActionButton},
    ],
    columnDefs: [{visible: false, targets: 2}, {orderable: false, targets: [5,6,7,8,9]} ],
    orderFixed: [2,'asc'],
    drawCallback: function (settings) {
      // we assume that the row are sorted by users' role (by 'orderFixed' and 'order' options)
      // this render a header rows when two adjacent rows has their roles differ
      var api = this.api();
      var rows = api.rows({ page: 'current' }).nodes();
      var last_role = null;
      api.column(2, { page: 'current' })
        .data()
        .each(function (role, i) {
            if (last_role !== role) {
              // set text for role row
              let role_text
              if (role == 'editor') {
                role_text = '<tr class="table-success"><td colspan="9"> Editors (Can edit the contest) </td></tr>'
              } else {
                role_text = '<tr class="table-info"><td colspan="9"> Users (Can only submit to the contest) </td></tr>'
              }

              //prepend row
              $(rows).eq(i).before(role_text);
              last_role = role;
            }
        });
      //since columns size changed, we call adjust
      //but not .draw() !!! else, infinite recursion
      api.columns.adjust()
    },
  },
  contestManageProblem: {
    ...baseConfig,
    responsive: true,
    processing: true,
    rowId: 'id',
    destroy: true,
    order: [[0,'asc']],
    ajax: {
      type: 'POST',
      headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'), },
    },
    layout: {
      topStart: 'info',
      topEnd: 'search',
    },
    columns: [ 
      {data: 'number'},
      {data: 'name'},
      {data: 'full_name'},
      {data: 'available', render: cafe.dt.render.yes_no_pill(), className: 'text-center'},
      {data: 'problem_id', render: cafe.dt.render.button(null, {element_type: 'switch', action: 'contest#postProblemAction', command: 'toggle', checked_data_field: 'enabled'})},
      {data: 'problem_id', render: cafe.dt.render.button(null, {element_type: 'switch', action: 'contest#postProblemAction', command: 'toggle_llm', checked_data_field: 'allow_llm'})},
      {data: 'problem_id', render: cafe.dt.render.button(`[${cafe.msi('delete','md-18')} Remove]`, {className: 'link-danger', action: 'contest#postProblemAction', command: 'remove', confirm: 'Remove problem from contest?', element_type: 'link'})},
      {data: 'problem_id', render: cafe.dt.render.button(`[${cafe.msi('arrow_upward','md-18')} Move Up]`, {action: 'contest#postProblemAction', command: 'moveup', element_type: 'link'})},
      {data: 'problem_id', render: cafe.dt.render.button(`[${cafe.msi('arrow_downward','md-18')} Move Down]`, {action: 'contest#postProblemAction', command: 'movedown', element_type: 'link'})},
    ],
    columnDefs: [{visible: false, targets: [0]},
                 {orderable: false, targets: [1,2,3,4,5,6,7,8]}],
    drawCallback: function (settings) {
      var api = this.api();
      api.columns.adjust()
    },
  },
  // this scoreTable is used in contest/:id/view and report/max_score
  // this must be initialized by specialized Stimulus controller datatables--init-score-table
  scoreTable: {
    ...baseConfig,
    //layout: -- defined in the datatables--init-score-table --
    //columns: -- defined in the datatables--init-score-table --
    responsive: false,  // we don't use responsive here
    buttons: [
        { text: 'Refresh', action: function(e,dt,node,config) {dt.clear().draw(); dt.ajax.reload()} },
        'copyHtml5',
        'excelHtml5',
    ],
    ajax: {
      type: 'POST',
      headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'), },
      dataSrc: function (json) {
        const processedJson = processScore(json)
        draw_graph(processedJson)
        return processedJson.data
      }
    },
    order: [[0,'asc']],
    drawCallback: function (settings) {
      var api = this.api();
      api.columns.adjust()
    },
    initComplete: function() {
      // 'this' refers to the datatable settings object.
      // 'this.api()' returns the API instance.
      const api = this.api();

      // draw the line numbering, independently of sorting
      api.on('order.dt search.dt', function (e, dt, type, index) {
        let i = 1;

        // select columns 0 of every row, as search and order is applied
        dt.api.cells(null, 0, { search: 'applied', order: 'applied' }).every(function (cell) {
          this.data(i++);
        });
      }).draw();
    }
  },
  // report -> AI report
  aiAssistReport: {
    ...baseConfig,
    paging: true,
    pageLength: 50,
    layout: {
      topStart: [ 'buttons', 'pageLength' ],
    },
    buttons: [
        { text: 'Refresh', action: function(e,dt,node,config) {dt.clear().draw(); dt.ajax.reload()} },
        'copyHtml5',
        'excelHtml5',
    ],
    columns: [
      columns.id,
      columns.solidQueueJob.status,
      columns.solidQueueJob.submissionId,
      columns.submission.points,
      columns.solidQueueJob.user,
      columns.solidQueueJob.problem,
      columns.solidQueueJob.detail,
      columns.solidQueueJob.createdAt,
    ],
    ajax: { 
      ...baseAjax, //use spread so that it is copied
      data: (data) => {
        // use the params which is set globally by the UI
        const result = $.extend({}, data, window.userFilterParams, window.problemFilterParams, window.submissionFilterParams);
        return result
      }
    },
    drawCallback: function (settings) {
      var api = this.api();
      api.columns.adjust()
    },
  },
};
