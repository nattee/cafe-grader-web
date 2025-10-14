import * as cafe from 'cafe_bundle'

export const renderers = {
  user_prob: (data,type,row,meta) => {
    let uc = window.userCount[row['id']] || '-'
    let pc = window.probCount[row['id']] || '-'
    if (type == 'display' || type == 'filter')
      return uc+' : '+pc

    return parseFloat(`${uc}.${pc}`)
  },
  // -------- contests render -------------
  startStopOffsetRender: (data,type,row,meta) => {
    const start_offset = row['start_offset_second']
    const extra_time = row['extra_time_second']
    return `${start_offset} : ${extra_time} ` +
      `<a href='#' data-row-id="${row['id']}" data-login="${row['login']}" data-start-offset="${start_offset}" data-extra-time="${extra_time}" data-action="click->contest#showExtraTimeDialog"><span class="mi mi-bs md-18">edit</span></a>`
  },
  roleActionButton: (data,type,row,meta) => {
    let result = ''
    if (row['role'] != 'editor') 
      result += cafe.dt.render.button('as editor',{element_type: 'link', className: 'link-success', action: 'contest#postUserAction', command: 'make_editor'})(row['user_id'],type,row,meta)
    if (row['role'] != 'user') {
      if (result != '') result += ' | '
      result += cafe.dt.render.button('as user',{element_type: 'link', className: 'link-info', action: 'contest#postUserAction', command: 'make_user'})(row['user_id'],type,row,meta)
    }
    return result
  },
  humanizeTimeRender: (data,type,row,meta) => {
    if (!data) return ''
    if (type == 'display' || type == 'filter')
      return humanizeTime(data)

    //for sort, we just return the data which is supposed to be iso8601
    return data
  }
}

// columns for each tables
// reuse this if available
export const columns = {
  // generic columns
  id: { data: 'id', title: 'ID'},
  // model specific columns
  solidQueueJob: {
    queue: { data: 'queue_name', title: 'Queue'},
    class: { data: 'class_name', title: 'Job Type'},
    problem: { data: 'problem_name', title: 'Problem'},
    user: { data: 'user_name', title: 'User'},
    status: { data: 'status', title: 'Status'},
    submissionId: { data: 'submission_id', title: 'Submission', render: function(data,type,row,meta) {
      if (data === null) return ''
      if (type == 'display' || type == 'filter')
        return `<a href="/submissions/${data}"> #${data}</a>`
      return data
    } },
    detail: { data: 'detail_html', title: 'Detail'},
    createdAt: { data: 'created_at', title: 'Created At' }
  },
  // --- contest (index, user, problem) ---
  contest: {
    name: {data: 'name'},
    description: {data: 'description'},
    userProb: { data: null, render: renderers.user_prob},
    finalized: {data: 'finalized', render: cafe.dt.render.yes_no_pill(), className: 'text-center'},
    enableToggle: {data: 'id', render: cafe.dt.render.button(null, {element_type: 'switch', action: 'contest#postContestAction', command: 'toggle', checked_data_field: 'enabled'})},
    start: {data: 'start', render: cafe.dt.render.datetime()},
    stop: {data: 'stop', render: cafe.dt.render.datetime()},
    manageLink: {data: null, render: cafe.dt.render.link(`${cafe.msi('settings','md-18')} Manage`, {path: AppRoute.contest})},
    watchLink: {data: null, render: cafe.dt.render.link(`${cafe.msi('summarize','md-18')} Watch`, {path: AppRoute.view_contest})},
    cloneButton: {data: null, render: cafe.dt.render.link(`${cafe.msi('file_copy','md-18')} Clone`, 
      {path: AppRoute.clone_contest, className: 'btn btn-sm btn-success', prefetch: false, turboStream: true}), className: 'align-middle py-1'},
    deleteButton: {data: null, render: cafe.dt.render.link(`${cafe.msi('delete','md-18')} Destroy`, {path: AppRoute.contest, method: 'delete', confirm: 'Really delete this contest?', className: 'btn btn-sm btn-danger', }), className: 'align-middle py-1'},
  },
  // --- submission ---
  submission: {
    points: {data: 'points', title: 'Raw Points'},
  },
}
