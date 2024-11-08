export const rowFieldToggle = (superclass) => class extends superclass {

  // given form target and records id
  // it changed the action url to match the id and submit the form
  // it is assumed that the placeholder id of the form's action url is -123
  submitToggleForm(form,id) {
    form.dataset.orig_action = form.action
    form.action = form.action.replace(-123,id)
    form.requestSubmit()
  }

  // reset the form back to the original action url
  resetToggleForm(event) {
    const form = event.target
    form.action = form.dataset.orig_action
  }
};
