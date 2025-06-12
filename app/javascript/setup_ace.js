import ace from 'ace-builds'
window.ace = ace


// import all modes
// this is quite tedious and it everything imported here must be
// pinned in importmap.rb which have a defined list of ace's module to import
//
// It is possible do to single source of truth using the string in the importmap.rb
// but its overkill for me (see https://gemini.google.com/u/1/gem/8250e294891c/b261be05e6954791)
// so I stick with doing it by hand

// theme
import 'ace-theme-merbivore'
import 'ace-theme-merbivore_soft'
import 'ace-theme-dracula'
// mode
import 'ace-mode-c_cpp'
import 'ace-mode-pascal'
import 'ace-mode-python'
import 'ace-mode-ruby'
import 'ace-mode-haskell'
import 'ace-mode-php'
import 'ace-mode-java'
import 'ace-mode-rust'
import 'ace-mode-golang'
import 'ace-mode-xml'
import 'ace-mode-sql'
