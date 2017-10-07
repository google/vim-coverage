" Copyright 2017 Google Inc. All rights reserved.
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

"{{{ Init

let s:plugin = maktaba#plugin#Get('coverage')

"}}}

"{{{ coverage.py provider

function! s:GetCoverageFile() abort
  " TODO(dbarnett): Limit upward search with some heuristics.
  return fnamemodify(findfile('.coverage', ';'), ':p')
endfunction

let s:imported_python = 0

function! coverage#python#GetCoveragePyProvider() abort
  let l:provider = {
      \ 'name': 'coverage.py'}

  function l:provider.IsAvailable(unused_filename) abort
    return &filetype is# 'python'
  endfunction

  function l:provider.GetCoverage(filename) abort
    if !s:imported_python
      try
        call maktaba#python#ImportModule(s:plugin, 'vim_coverage')
      catch /ERROR.*/
          throw maktaba#error#NotFound(
              \ "Couldn't import Python coverage module (%s). " .
              \ 'Install the coverage package and try again.', v:exception)
      endtry
      let s:imported_python = 1
    endif
    let l:cov_file = s:GetCoverageFile()
    if empty(l:cov_file)
      throw maktaba#error#NotFound(
          \ 'No .coverage file found. ' .
          \ 'Generate one by running nosetests --with-coverage')
    endif
    let l:coverage_data = maktaba#python#Eval(printf(
        \ 'vim_coverage.GetCoveragePyLines(%s, %s)',
        \ string(l:cov_file),
        \ string(a:filename)))
    let [l:covered_lines, l:uncovered_lines] = l:coverage_data
    return coverage#CreateReport(l:covered_lines, l:uncovered_lines, [])
  endfunction

  return l:provider
endfunction

"}}}
