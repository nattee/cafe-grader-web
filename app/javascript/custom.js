$(document).on('change', '.btn-file :file', function() {
  var input, label, numFiles;
  input = $(this);
  numFiles = input.get(0).files ? input.get(0).files.length : 1;
  label = input.val().replace(/\\/g, '/').replace(/.*\//, '');
  input.trigger('fileselect', [numFiles, label]);
});

$(function() {
  var e;
  $(".select2").select2({
    theme: "bootstrap-5",
  });

  $('.btn-file :file').on('fileselect', function(event, numFiles, label) {
    var input, log;
    input = $(this).parents('.input-group').find(':text');
    log = numFiles > 1 ? numFiles + ' files selected' : label;
    if (input.length) {
      input.val(log);
    } else {
      if (log) {
        alert(log);
      }
    }
  });
  $('.ajax-toggle').on('click', function(event) {
    var target;
    target = $(event.target);
    target.removeClass('btn-default');
    target.removeClass('btn-success');
    target.addClass('btn-warning');
    target.text('...');
  });
  if ($("#editor").length > 0) {
    e = ace.edit("editor");
    e.setTheme('ace/theme/merbivore');
    e.getSession().setTabSize(2);
    e.getSession().setUseSoftTabs(true);
  }

  //jQuery(".best_in_place").best_in_place();
  
  //default options for tempus dominus
  window.default_td_options = {
    display: {
      icons: {
        time: 'mi mi-td-time',
        date: 'mi mi-td-date',
        up: 'mi mi-td-up',
        down: 'mi mi-td-down',
        previous: 'mi mi-td-previous',
        next: 'mi mi-td-next',
        today: 'mi mi-td-today',
        clear: 'mi mi-td-clear',
        close: 'mi mi-td-close',
      },
      buttons: {
        today: true,
        clear: false,
        close: true
      },
      components: {
        calendar: true,
        date: true,
        month: true,
        year: true,
        decades: true,
        clock: true,
        hours: true,
        minutes: true,
        seconds: false,
        useTwentyfourHour: true,
      },
    }
  }
});
