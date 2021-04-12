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

" @private
" Concatenates coverage data from 'from' into 'into'.
function! s:ExtendReport(into, from)
  call extend(a:reports_by_file[l:current_file].covered,
        \ l:current_report.covered)
  call extend(a:reports_by_file[l:current_file].partial,
        \ l:current_report.partial)
  call extend(a:reports_by_file[l:current_file].uncovered,
        \ l:current_report.uncovered)
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
      let l:current_report = coverage#CreateReport([], [], [])
      continue
    endif

    if l:current_file == v:null
      continue
    endif

    if l:line == 'end_of_record'
      " Individual reports may have multiple rows for one line.
      " They may indicate that a line is covered (DA), but may also provide
      " branch information in a separate line (BA).
      "
      " In that case, within the report, we want to go with the partial data
      " over the covered data.
      call filter(l:current_report.covered,
            \ 'index(l:current_report.partial, v:val) < 0')

      if !has_key(a:reports_by_file, l:current_file)
        let a:reports_by_file[l:current_file] = l:current_report
      else
        call ExtendReport(a:reports_by_file[l:current_file], l:current_report)
      endif

      let l:current_file = v:null
      let l:current_report = v:null
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
" @private
" Removes duplicates from the given report, and deals with conflicting coverage
" files that may say a line is partially covered/uncovered, where another report
" shows it as covered.
function! s:CleanReport(report) abort
  call uniq(a:report.covered)
  call uniq(a:report.partial)
  call uniq(a:report.uncovered)
  call filter(a:report.partial, 'index(a:report.covered, v:val) < 0')
  call filter(a:report.uncovered, 'index(a:report.partial, v:val) < 0')
  call filter(a:report.uncovered, 'index(a:report.covered, v:val) < 0')
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
  " We can't check specificlaly for this filename unless we read each of those
  " files, too.
  function l:provider.IsAvailable(unused_filename) abort
    return !empty(s:GetCoverageDataPaths())
  endfunction

  function l:provider.GetCoverage(filename) abort
    let l:reports = s:GetReports()
    for [l:covered_file, l:report] in items(l:reports)
      if maktaba#string#EndsWith(a:filename, l:covered_file)
        call s:CleanReport(l:report)
        return l:report
      endif
    endfor
  endfunction

  return l:provider
endfunction

"}}}
