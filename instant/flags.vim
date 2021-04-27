" Copyright 2014 Google Inc. All rights reserved.
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"     http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.

""
" @section Introduction, intro
" @stylized Coverage
" @order intro usage sources plugins packages config commands functions about
" Coverage is a generic vim coverage layer plugin. It depends upon |Maktaba|.
"
" Everybody knows test coverage is important. It is not paramount and you
" should not strive to cover every line, rather to cover sensible usecases,
" but it is still important to spot untested branches and code paths.
"
" Coverage report uses three colors:
"
"     * red - line not covered
"     * partial - branch taken, but not in all paths
"     * green - fully covered
"
" See more about branch coverage on http://en.wikipedia.org/wiki/Code_coverage

" This plugin offers generic support for rendering code coverage. Coverage
" providers can be registered by other plugins that integrate with |coverage|,
" using |maktaba| for the registration.

""
" @section Usage, usage
"
" To use this plugin, you need at least one coverage provider registered with
" it. This plugin provides a generic way to show coverage report line-by-line,
" but it requires a source of the information. Any plugin wishing to be a
" coverage provider needs only to register itself using
" @function(coverage#AddProvider), and pass a |Dictionary| with the following
" |Dictionary-function| defined:
"   - IsAvailable(filename) - return 1 if plugin can handle the current file,
"     otherwise 0.
"   - GetCoverage(filename) - returns the coverage dict created by
"     @function(coverage#CreateReport) that contains all coverage data.
"   - Name() - returns the name of the plugin.
"   - optional: GetCoverageAsync(filename, callback) - gets the coverage and
"     once done, invokes the provided callback with the coverage dict created by
"     @function(coverage#CreateReport) that contains all coverage data.
"
" You can define a mapping to toggle showing coverage report. To use the default
" mapping of "<Leader>Ct", add the following to your vimrc:
" >
"   Glaive coverage plugin[mappings]
" <

scriptencoding utf-8

let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

""
" Text shown on the sign of a partially-covered line (e.g. unexplored branch).
call s:plugin.Flag('partial_text', '◊◊')

""
" Text shown on the sign of a noncovered line (left of the line, in the corner).
call s:plugin.Flag('uncovered_text', '▵▵')

""
" Text shown on the sign of a covered line (left of the line, in the corner).
call s:plugin.Flag('covered_text', '▴▴')

""
" Background color for the partially covered lines when in cterm mode (non-GUI).
call s:plugin.Flag('partial_ctermbg', 'yellow')

""
" Text color for the partially covered lines when in cterm mode (non-GUI).
call s:plugin.Flag('partial_ctermfg', 'black')

""
" Background color for the partially covered lines when in GUI mode (e.g. gvim).
call s:plugin.Flag('partial_guibg', 'yellow')

""
" Text color for the partially covered lines when in GUI mode (e.g. gvim).
call s:plugin.Flag('partial_guifg', 'black')

""
" Background color for the covered lines when in cterm mode (non-GUI).
call s:plugin.Flag('covered_ctermbg', 'lightgreen')

""
" Text color for the covered lines when in cterm mode (non-GUI).
call s:plugin.Flag('covered_ctermfg', 'black')

""
" Background color for the covered lines when in GUI mode (e.g. gvim).
call s:plugin.Flag('covered_guibg', 'green')

""
" Text color for the covered lines when in GUI mode (e.g. gvim).
call s:plugin.Flag('covered_guifg', 'black')

""
" Background color for the uncovered lines when in cterm mode (non-GUI).
call s:plugin.Flag('uncovered_ctermbg', 'red')

""
" Text color for the uncovered lines when in cterm mode (non-GUI).
call s:plugin.Flag('uncovered_ctermfg', 'white')

""
" Background color for the uncovered lines when in GUI mode (e.g. gvim).
call s:plugin.Flag('uncovered_guibg', 'red')

""
" Text color for the uncovered lines when in GUI mode (e.g. gvim).
call s:plugin.Flag('uncovered_guifg', 'white')
