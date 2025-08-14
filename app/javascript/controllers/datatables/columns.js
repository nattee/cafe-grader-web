export const columns = {
  // generic columns
  id: { data: 'id', title: 'ID'},
  // model specific columns
  solidQueueJob: {
    queue: { data: 'queue_name'},
    class: { data: 'class_name'},
    status: { data: 'status', title: 'Status'},
    createdAt: { data: 'created_at', title: 'Created At' }
  }
}
