import { columns } from 'controllers/datatables/columns'

const baseConfig = {
  responsive: true,
  processing: true,
  destroy: true
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
  }
};
