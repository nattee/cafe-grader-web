import * as cafe from 'cafe_bundle'

export const renderers = {
  user_prob: (data,type,row,meta) => {
    let uc = window.userCount[row['id']] || '-'
    let pc = window.probCount[row['id']] || '-'
    if (type == 'display' || type == 'filter')
      return uc+' : '+pc

    return parseFloat(`${uc}.${pc}`)
  }
}

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
      return `<a href="/submissions/${data}"> #${data}</a>`
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
    cloneButton: {data: null, render: cafe.dt.render.link(`${cafe.msi('file_copy','md-18')} Clone`, {path: AppRoute.clone_contest, className: 'btn btn-sm btn-success'}), className: 'align-middle py-1'},
    deleteButton: {data: null, render: cafe.dt.render.link(`${cafe.msi('delete','md-18')} Destroy`, {path: AppRoute.contest, method: 'delete', confirm: 'Really delete this contest?', className: 'btn btn-sm btn-danger', }), className: 'align-middle py-1'},
  }
}
