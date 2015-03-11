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
" @section Commands, commands
" For toggling coverage view, the <PREFIX>t mapping is set. To automatically
" render coverage for available file types, create an autocmd, e.g.: >
"   augroup coverage
"     autocmd!
"     autocmd BufReadPost *.py,*.c,*.cc,*.h,*.java,*.go,*.js :CoverageShow
"   augroup END
" <
"
" This will render coverage for all mentioned filetypes, if available.

let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

let s:prefix = s:plugin.MapPrefix('C')
execute 'nnoremap <unique> <script> <silent>' s:prefix . 't :CoverageToggle<cr>'
