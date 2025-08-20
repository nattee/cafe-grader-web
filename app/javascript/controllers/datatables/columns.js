import * as cafe from 'cafe_bundle'

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
  }
}
