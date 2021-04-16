" Copyright 2021 Google Inc. All rights reserved.
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

"{{{ [lcov](https://github.com/linux-test-project/lcov) coverage provider.

""
" @private
" Gets a list of files matching the plugin settings.
function! s:GetCoverageDataPaths() abort
  let l:paths = join(s:plugin.Flag('lcov_search_paths'), ',')
  let l:data_files = []
  for l:lcov_file_pattern in s:plugin.Flag('lcov_file_patterns')
    call extend(
          \ l:data_files,
          \ globpath(l:paths, l:lcov_file_pattern, 0, 1))
  endfor
  return l:data_files
endfunction

""
" @private
" Gets a dictionary of coverage reports based on all lcov files matching the
" plugin configuration.
function! s:GetReports() abort
  let l:reports = {}
  for l:data_path in s:GetCoverageDataPaths()
    call coverage#lcov#parsing#ExtendReportsForData(l:reports, l:data_path)
  endfor
  for l:report in values(l:reports)
    call s:CleanReport(l:report)
  endfor
  return l:reports
endfunction

""
" @private
" Removes duplicates from the given report, and deals with conflicting coverage
" files that may say a line is partially covered/uncovered, where another report
" shows it as covered.
function! s:CleanReport(report) abort
  call uniq(a:report.covered)
  call uniq(a:report.partial)
  call uniq(a:report.uncovered)
  " Only keep 'partial' lines that are not in 'covered'
  call filter(a:report.partial, 'index(a:report.covered, v:val) < 0')
  " Only keep 'uncovered' lines that are not in 'partial' or 'covered'
  call filter(a:report.uncovered,
        \ 'index(a:report.partial, v:val) < 0 ' .
        \ '&& index(a:report.covered, v:val) < 0')
endfunction

""
" @public
" Produces a provider dictionary for the Lcov plugin.
function! coverage#lcov#GetLcovProvider() abort
  let l:provider = {'name': 'lcov'}

  ""
  " Returns whether the coverage provider is available for the current file.
  "
  " This checks if there are any lcov-like files in the configured set of files.
  " We can't check specifically for this filename unless we read each of those
  " files, too.
  function l:provider.IsAvailable(unused_filename) abort
    call maktaba#ensure#IsList(s:plugin.Flag('lcov_search_paths'))
    call maktaba#ensure#IsList(s:plugin.Flag('lcov_file_patterns'))
    return !empty(s:GetCoverageDataPaths())
  endfunction

  function l:provider.GetCoverage(filename) abort
    let l:reports = s:GetReports()
    for [l:covered_file, l:report] in items(l:reports)
      if maktaba#string#EndsWith(a:filename, l:covered_file)
        return l:report
      endif
    endfor
  endfunction

  return l:provider
endfunction

"}}}
