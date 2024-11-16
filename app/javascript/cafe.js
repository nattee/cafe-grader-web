// main cafe-grader functionalities
// this file exports functions and constants that can be shared and used globally
// it is merged with other functions in 'cafe_bundle.js'

function msi(icon_name, className = '') {
  return `<span class="mi mi-bs ${className}">${icon_name}</span>`
}

function initSelect2() {
  $(".select2").select2({
    theme: "bootstrap-5",
  });
}

//default options for tempus dominus
const default_td_options = {
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
    format: 'dd/MMM/yyyy HH:mm',
  }
}

const default_td_date_options = {
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

const config = {
  td: {date: default_td_date_options, datetime: default_td_options}
}

export { config, msi, initSelect2 }
