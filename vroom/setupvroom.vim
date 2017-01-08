" Copyright 2015 Google Inc. All rights reserved.
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

" This file is used from vroom scripts to bootstrap the coverage plugin and
" configure it to work properly under vroom.

" Coverage does not support compatible mode.
set nocompatible

" Install the coverage plugin.
let s:repo = expand('<sfile>:p:h:h')
execute 'source' s:repo . '/bootstrap.vim'

" Force plugin/ files to load since vroom installs the plugin after
" |load-plugins| time.
call maktaba#plugin#Get('coverage').Load()

" Support vroom's fake shell executable and don't try to override it to sh.
call maktaba#syscall#SetUsableShellRegex('\v<shell\.vroomfaker$')

function WriteFakeCoveragePyFile(path, lines_by_file) abort
  python <<EOF
import vim, os.path, coverage
cov = coverage.CoverageData()
path = vim.eval('a:path')
cov.add_line_data({
  os.path.join(path, filename): {int(l): None for l in lines}
  for filename, lines in vim.eval('a:lines_by_file').items()})
cov.write_file(os.path.join(path, '.coverage'))
EOF
endfunction
