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
    let l:data_files = extend(
          \ l:data_files,
          \ globpath(l:paths, l:lcov_file_pattern, 0, 1))
  endfor
  return l:data_files
endfunction

""
" @private
" Categorizes a BRDA: line in a lcov info file.
function! s:TryParseLine(line) abort
  if maktaba#string#StartsWith(a:line, 'BA:') ||
        \ maktaba#string#StartsWith(a:line, 'DA:')
    let l:hits_index = 1
  elseif maktaba#string#StartsWith(a:line, 'BRDA:')
    let l:hits_index = 3
  else
    return []
  endif

  try
    let [l:prefix, l:raw_info] = split(a:line, ':')
    let l:info = split(l:raw_info, ',')
    let l:linenum = str2nr(info[0])
    let l:hits = str2nr(info[l:hits_index])  " Will return 0 if hits is '-'
  catch
    call s:plugin.logger.Debug(
          \ 'Failed to parse lcov line (%s): %s', v:exception, a:line)
    return []
  endtry

  if hits == 0
    return ['uncovered', l:linenum]
  endif

  if hits == 1 && l:prefix == 'BA'
    return ['partial', l:linenum]
  endif

  return ['covered', l:linenum]
endfunction

""
" @private
" Adds reports for the given coverage path to the given dictionary.
"
" There is a bunch of summary information that we're not interested in.
"
" What we want are any of:
" - SF<absolute path to the source file>: Starts a coverage section for a file
" - DA:<line number>,<execution count>[,<checksum>]
" - BA:<line number>,<branch coverage (0: uncovered, 1: partial, 2: covered>
" - BRDA:<line number>,<block number>,<branch number>,<taken>
" - end_of_record: End of a coverage section for a file
"
" For BRDA, we can't get partial coverage (only '-' for uncovered, or 1+)
function! s:ExtendReportsForData(reports_by_file, data_path) abort
  let lines = readfile(a:data_path)

  let current_file = v:null
  let current_report = v:null

  for l:line in l:lines
    let l:line = trim(l:line)

    " SF:<absolute path to the source file>
    " Begins a section of coverage.
    if maktaba#string#StartsWith(l:line, 'SF:')
      let l:current_file = strcharpart(l:line, 3)

      if !has_key(a:reports_by_file, l:current_file)
        let a:reports_by_file[l:current_file] =
              \ coverage#CreateReport([], [], [])
      endif

      let l:current_report = a:reports_by_file[l:current_file]
      continue
    endif

    if l:current_file == v:null
      continue
    endif

    if l:line == 'end_of_record'
      let l:current_file = v:null
      continue
    endif

    let l:parsed_line = s:TryParseLine(l:line)

    " This means the line is a summary line or invalid - we don't care about it.
    if empty(l:parsed_line)
      continue
    endif

    let [l:coverage_type, l:linenum] = l:parsed_line
    call add(l:current_report[l:coverage_type], l:linenum)
    continue
  endfor

  return a:reports_by_file
endfunction

""
" @private
" Gets a dictionary of coverage reports based on all lcov files matching the
" plugin configuration.
function! s:GetReports() abort
  let l:reports = {}
  for l:data_path in s:GetCoverageDataPaths()
    call s:ExtendReportsForData(l:reports, l:data_path)
  endfor
  return l:reports
endfunction

""
" @public
" Produces a provider dictionary for the Lcov .
function! coverage#lcov#GetLcovProvider() abort
  let l:provider = {'name': 'lcov'}

  ""
  " Returns whether the coverage provider is available for the current file.
  "
  " An lcov-style report can be generated for any file, so we just return true.
  function l:provider.IsAvailable(unused_filename) abort
    return 1
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
