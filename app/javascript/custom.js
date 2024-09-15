$(document).on('change', '.btn-file :file', function() {
  var input, label, numFiles;
  input = $(this);
  numFiles = input.get(0).files ? input.get(0).files.length : 1;
  label = input.val().replace(/\\/g, '/').replace(/.*\//, '');
  input.trigger('fileselect', [numFiles, label]);
});

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
  },
  localization: {
    locale: 'en-uk',
    format: 'dd/MMM/yyyy hh:mm',
  }
}

window.default_td_date_options = {
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
    components: {
      hours: false,
      minutes: false,
      seconds: false
    }
  },
  localization: {
    locale: 'en-uk',
    format: 'dd/MMM/yyyy',
  }
}


//global initialization
$(document).ready(function(e) {
  var e;
  $(".select2").select2({
    theme: "bootstrap-5",
  });

  // init tooltips
  $('[data-bs-toggle="tooltip"]').tooltip()

  //make select2 focus on search box
  //see https://stackoverflow.com/questions/25882999/set-focus-to-search-text-field-when-we-click-on-select-2-drop-down
  $(document).on('select2:open', (e) => {
    const selectId = e.target.id

    $(".select2-search__field[aria-controls='select2-" + selectId + "-results']").each(function (
        key,
        value,
    ){
        value.focus();
    })
  })

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

});
