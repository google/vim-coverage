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

"{{{ Init

let s:plugin = maktaba#plugin#Get('coverage')
let s:registry = s:plugin.GetExtensionRegistry()
if !exists('s:visible')
  " Buffer paths for which the coverage is visible.
  let s:visible = {}
endif
if !exists('s:cache')
  " Cache of retrieved coverage data per path.
  let s:cache = {}
endif
if !exists('s:coverage_states')
  let s:coverage_states = ['covered', 'uncovered', 'partial']
endif

"}}}

"{{{ coverage utility functions

""
" Places the signs at given {lines} in given {state}.
function! s:ColorSigns(lines, state) abort
  for l:num in a:lines
    execute ':sign place ' . l:num . ' line=' . l:num .
          \ ' name=sign_' . a:state . ' file=' . expand('%')
  endfor
endfunction


""
" Defines highlighting rules for coverage colors and defines text signs for each
" coverage state, as defined via plugin flags. See |coverage-config|.
function! s:DefineHighlighting() abort
  if !hlexists('coverage_covered')
    for l:state in s:coverage_states
      execute 'highlight coverage_' . l:state .
          \ ' ctermbg=' . s:plugin.Flag(l:state . '_ctermbg') .
          \ ' ctermfg=' . s:plugin.Flag(l:state . '_ctermfg') .
          \ ' guibg=' . s:plugin.Flag(l:state . '_guibg') .
          \ ' guifg=' . s:plugin.Flag(l:state . '_guifg')
      execute 'sign define sign_' . l:state . ' text=' .
          \ s:plugin.Flag(l:state . '_text') . ' texthl=coverage_' . l:state
    endfor
  endif
endfunction


""
" Renders the coverage for the required {filename}. Coverage needs to be in
" cache. This function does not get the coverage itself, only displays it.
" If [show_stats] is set, the coverage stats are shown, e.g. Coverage 70%(7/10).
" @default show_stats=1
function! s:RenderFromCache(filename, ...) abort
  let l:show_stats = maktaba#ensure#IsBool(get(a:, 1, 1))
  call s:DefineHighlighting()
  if (has_key(s:cache, a:filename))
    let l:data = s:cache[a:filename]
    for l:state in s:coverage_states
      call s:ColorSigns(l:data[l:state], l:state)
    endfor
    if l:show_stats
      echomsg coverage#GetFormattedStats(a:filename)
    endif
    let s:visible[expand('%:p')] = 1
  endif
endfunction


""
" Hides coverage layer.
function! s:CoverageHide() abort
  if has_key(s:visible, expand('%:p'))
    execute 'sign unplace * file=' . expand('%:p')
    unlet s:visible[expand('%:p')]
  endif
endfunction


""
" Toggles coverage layer.
function! s:CoverageToggle(skip_cache) abort
  if has_key(s:visible, expand('%:p'))
    call s:CoverageHide()
  else
    call s:CoverageShow(a:skip_cache)
  endif
endfunction


""
" Shows coverage layer. If [explicit_provider] is set, it will be used for
" fetching the coverage data.
function! s:CoverageShow(skip_cache, ...) abort
  let l:filename = expand('%:p')

  if has_key(s:visible, l:filename)
    if a:skip_cache
      call s:CoverageHide()
    else
      " This file is already being shown, no need to re-show.
      return
    endif
  endif

  if has_key(s:cache, l:filename) && !a:skip_cache
    call s:RenderFromCache(l:filename)
    return
  endif

  if a:0 > 0
    let l:provider = maktaba#ensure#IsString(a:1)
    call coverage#ShowCoverage(l:provider)
  else
    call coverage#ShowCoverage()
  endif

endfunction

""
" Shows coverage in vimdiff with the version coverage was known for.
function! s:CoverageShowDiff() abort
  let l:filename = expand('%:p')
  if has_key(s:cache, l:filename)
    let l:data = s:cache[l:filename]
    if has_key(l:data, 'diff_path')
      " Current file has changed, so split into diff mode with the file at the
      " point where the coverage is known, and render it there, in the split.
      execute 'vertical' 'diffsplit' l:data.diff_path
      call s:RenderFromCache(l:filename)
    else
      call maktaba#error#Warn('There is no diff.')
    endif
  endif
endfunction


""
" Calculates coverage stats from @dict(s:cache), and returns the stats for the
" requested {filename}. Does not get the coverage stats.
function! coverage#GetFormattedStats(filename) abort
  if has_key(s:cache, a:filename)
    let l:data = s:cache[a:filename]
    let l:stats = {'total': 0}
    for l:state in s:coverage_states
      let l:stats[l:state] = len(l:data[l:state])
      let l:stats['total'] += len(l:data[l:state])
    endfor
    if l:stats.total is 0
      return printf('Coverage is empty for file %s.', a:filename)
    endif
    let l:percentage = 100.0 * l:stats.covered / l:stats.total
    return printf('Coverage is %.2f%% (%d/%d lines).',
          \ l:percentage, l:stats.covered, l:stats.total)
  endif
endfunction


""
" @public
" Returns a coverage report compatible with |coverage|, for {covered},
" {uncovered} and {partial} lines. Optional param [extra_dict] can be passed in,
" which will be merged with the result.
function! coverage#CreateReport(covered, uncovered, partial, ...) abort
  let l:extra_dict = {}
  if a:0 > 0
    let l:extra_dict = maktaba#ensure#IsDict(a:1)
  endif
  call maktaba#ensure#IsList(a:covered)
  call maktaba#ensure#IsList(a:uncovered)
  call maktaba#ensure#IsList(a:partial)
  return extend(l:extra_dict,
      \ {'covered': a:covered,
      \ 'uncovered': a:uncovered,
      \ 'partial': a:partial})
endfunction


""
" Renders coverage for the current file. A name of a registered [provider] can
" be passed as a parameter. If left blank, buffer b:coverage_provider variable
" will be first checked, and if it is not set, then the first registered
" provider will be used. If the provider defines a
" @function(provider#GetCoverageAsync), it is preferred. The callback must have
" function(coverage_data) prototype.  Coverage data format is as described in
" the general help for this plugin.
" @default provider=b:coverage_provider or first registered provider
" @throws NotFound if requested provider is not found or non are registered, or
" the is not available for the current file.
function! coverage#ShowCoverage(...) abort
  let l:filename = expand('%:p')
  let l:providers = s:registry.GetExtensions()
  if a:0 >= 1
    let l:explicit_name = a:1
  elseif !empty(get(b:, 'coverage_provider'))
    let l:explicit_name = b:coverage_provider
  elseif len(l:providers) > 0
    for l:provider in l:providers
      if l:provider.IsAvailable(l:filename)
        let l:default_provider = l:provider
        break
      endif
    endfor
    if !exists('l:default_provider')
      throw maktaba#error#NotFound('No available coverage providers.')
    endif
    let l:selected_provider = l:default_provider
  else
    throw maktaba#error#NotFound('No registered coverage providers.')
  endif

  if exists('l:explicit_name')
    for l:provider in l:providers
      if l:provider.name ==# l:explicit_name
        let l:explicit_provider = l:provider
        break
      endif
    endfor
    if !exists('l:explicit_provider')
      throw maktaba#error#NotFound('Coverage provider %s not found.',
          \ l:explicit_name)
    endif
    let l:selected_provider = l:explicit_provider
  endif

  if !l:selected_provider.IsAvailable(l:filename)
    throw maktaba#error#NotFound('Provider %s is not available for file %s',
        \ l:explicit_name, l:filename)
  endif
  let l:callback = maktaba#function#Create('coverage#CacheAndShow',
      \ [l:filename])
  if has_key(l:selected_provider, 'GetCoverageAsync')
    call l:selected_provider.GetCoverageAsync(l:filename, l:callback)
  else
    call maktaba#function#Apply(l:callback,
        \ l:selected_provider.GetCoverage(l:filename))
  endif
endfunction

""
" Caches the {coverage} for the {filename} and renders it. This can be used as a
" callback entry for asynchronous calls. {coverage} format is as described in
" the general help for this plugin.
function! coverage#CacheAndShow(filename, coverage) abort
  if !maktaba#value#IsDict(a:coverage)
    return
  endif
  let s:cache[a:filename] = a:coverage
  if !has_key(a:coverage, 'diff_path')
    call s:RenderFromCache(a:filename)
  endif
endfunction

"}}}

"{{{ Misc

function! coverage#Toggle(skip_cache) abort
  call s:CoverageToggle(a:skip_cache)
endfunction

function! coverage#Show(skip_cache, ...) abort
  try
    if a:0 > 0
      call s:CoverageShow(a:skip_cache, a:1)
    else
      call s:CoverageShow(a:skip_cache)
    endif
  catch /ERROR.*/
    call maktaba#error#Shout('Error rendering coverage: %s', v:exception)
  endtry
endfunction

function! coverage#ShowDiff() abort
  try
    call s:CoverageShowDiff()
  catch /ERROR.*/
    call maktaba#error#Shout('Error rendering coverage: %s', v:exception)
  endtry
endfunction

function! coverage#Hide() abort
  try
    if has_key(s:visible, expand('%:p'))
      call s:CoverageHide()
    endif
  catch /ERROR.*/
    call maktaba#error#Shout('Error rendering coverage: %s', v:exception)
  endtry
endfunction

""
" @private
" Completions for the available providers. Returns a list of providers that
" start with {arg}.
function! coverage#CompletionList(arg, line, pos) abort
  let l:providers = []
  for l:extension in s:registry.GetExtensions()
    call add(l:providers, l:extension.name)
  endfor
  return filter(l:providers, 'maktaba#string#StartsWith(v:val, a:arg)')
endfunction

""
" Makes sure the coverage {provider} is a valid provider for the plugin.
" @throws BadValue if the provider is not valid.
function! coverage#EnsureProvider(provider) abort
  let l:required_fields = ['name', 'IsAvailable', 'GetCoverage']
  " Throw BadValue if any required fields are missing.
  let l:missing_fields =
      \ filter(copy(l:required_fields), '!has_key(a:provider, v:val)')
  if !empty(l:missing_fields)
    throw maktaba#error#BadValue(
        \ 'Provider is missing fields: %s. Got: %s',
        \ join(l:missing_fields, ', '),
        \ string(a:provider))
  endif
endfunction

"}}}
