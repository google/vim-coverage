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

" Polyfill for vim's pyeval().
" TODO(google/vim-maktaba#70): Use maktaba's implementation when available.
function! s:PyEval(expr) abort
  if exists('*pyeval')
    return pyeval(a:expr)
  endif
  python import json, vim
  python vim.command('return ' + json.dumps(eval(vim.eval('a:expr'))))
endfunction

function! coverage#python#GetCoveragePyProvider() abort
  let l:provider = {
      \ 'name': 'coverage.py'}

  function l:provider.IsAvailable(unused_filename) abort
    return &filetype is# 'python'
  endfunction

  function l:provider.GetCoverage(filename) abort
    " Check coverage is importable and show a clear error otherwise.
    try
      python import coverage
    catch /Vim(python):/
      throw maktaba#error#NotFound(
          \ "Couldn't import python coverage module. " .
          \ 'Install coverage and try again.')
    endtry
    let l:cov_file = s:GetCoverageFile()
    if empty(l:cov_file)
      throw maktaba#error#NotFound(
          \ 'No .coverage file found. ' .
          \ 'Generate one by running nosetests --with-coverage')
    endif
    call maktaba#python#ImportModule(s:plugin, 'vim_coverage')
    let l:coverage_data = s:PyEval(printf(
        \ 'vim_coverage.GetCoveragePyLines(%s, %s)',
        \ string(l:cov_file),
        \ string(a:filename)))
    let [l:covered_lines, l:uncovered_lines] = l:coverage_data
    return coverage#CreateReport(l:covered_lines, l:uncovered_lines, [])
  endfunction

  return l:provider
endfunction

"}}}
