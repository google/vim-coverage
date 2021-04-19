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

"{{{ Utility functions for parsing lcov files.

""
" @private
" Categorizes a line potentially containing coverage information in a coverage
" file.  Recognized coverage information is be formatted as:
" - DA:<line number>,<execution count>[,<checksum>]
" - BA:<line number>,<branch coverage (0: uncovered, 1: partial, 2: covered>
" - BRDA:<line number>,<block number>,<branch number>,<taken>
"
" Note that for BRDA lines, we can't check for partial coverage (only '-' for
" uncovered, or 1+ for the number of times the line was run).
"
" For additional details on lcov's tracefile format, see FILES under on
" geninfo's man page, or view the man page at:
" http://ltp.sourceforge.net/coverage/lcov/geninfo.1.php
function! s:TryParseLine(line) abort
  let [l:prefix, l:raw_info] = split(a:line, ':', 1)
  let l:prefix = maktaba#string#Strip(l:prefix)

  if l:prefix ==? 'BA' || l:prefix ==? 'DA'
    let l:hits_index = 1
  elseif l:prefix ==? 'BRDA'
    let l:hits_index = 3
  else
    return []
  endif

  try
    let l:info = split(l:raw_info, ',', 1)
    let l:linenum = str2nr(info[0])
    " Note that For BRDA lines, '-' is used instead of '0' for uncovered, which
    " str2nr will safely convert to 0.
    let l:hits = str2nr(info[l:hits_index])
  catch
    call s:plugin.logger.Debug(
          \ 'Failed to parse lcov line (%s): %s', v:exception, a:line)
    return []
  endtry

  if hits == 0
    return ['uncovered', l:linenum]
  endif

  if hits == 1 && l:prefix ==? 'BA'
    return ['partial', l:linenum]
  endif

  return ['covered', l:linenum]
endfunction

""
" @private
" Gets a list of covered filenames and reports for a given lcov info file.
"
" Each coverage info file may contain multiple reports for different source
" files.
"
" Data may be formatted as:
" - SF<absolute path to the source file>: Starts a coverage section for a file
" - Coverage data (see s:TryParseLine)
" - end_of_record: End of a coverage section for a file
function! coverage#lcov#parsing#ParseLcovFile(info_file)
      \ abort
  let l:reports = []
  let l:lines = readfile(a:info_file)

  let l:current_file = -1
  let l:current_report = -1

  for l:line in l:lines
    let l:line = maktaba#string#Strip(l:line)

    " SF:<absolute path to the source file>
    " Begins a section of coverage.
    if maktaba#string#StartsWith(l:line, 'SF:')
      let l:current_file = maktaba#string#Strip(l:line[3:])
      let l:current_report = coverage#CreateReport([], [], [])
      continue
    endif

    if l:current_file is -1
      continue
    endif

    if l:line ==? 'end_of_record'
      " Individual reports may have multiple rows for one line.
      " They may indicate that a line is covered (DA), but may also provide
      " branch information in a separate line (BA).
      "
      " In that case, within the report, we want to go with the partial data
      " over the covered data.
      call filter(l:current_report.covered,
            \ 'index(l:current_report.partial, v:val) < 0')

      call add(l:reports, [l:current_file, l:current_report])

      let l:current_file = -1
      let l:current_report = -1
      continue
    endif

    let l:parsed_line = s:TryParseLine(l:line)
    if !empty(l:parsed_line)
      let [l:coverage_type, l:linenum] = l:parsed_line
      call add(l:current_report[l:coverage_type], l:linenum)
    endif
  endfor

  return l:reports
endfunction

"}}}
