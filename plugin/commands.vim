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

let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

""
" Show coverage report. If variable b:coverage_provider is set, the provider
" from it will be used.
command -nargs=* -complete=customlist,coverage#CompletionList CoverageShow
    \ call coverage#Show(<f-args>)

""
" Toggle coverage report.
command -nargs=0 CoverageToggle call coverage#Toggle()

""
" Show coverage report when the file changed, using vimdiff.
command -nargs=0 CoverageShowDiff call coverage#ShowDiff()

""
" Hide coverage report.
command -nargs=0 CoverageHide call coverage#Hide()

""
" Print formatted stats, e.g. Coverage 88% (22/25 lines).
command -nargs=0 CoverageStats echomsg coverage#GetFormattedStats(expand('%:p'))
