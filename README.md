vim-coverage is a utility for visualizing test coverage results in vim.
vim-coverage relies on [maktaba](https://github.com/google/vim-maktaba) for
registration and management of coverage providing plugins.

For details, see the helpfiles in the `doc/` directory. The helpfiles are also
available via `:help vim-coverage` if vim-coverage is installed (and helptags
have been generated).

# Commands

Use `:CoverageShow` to show file coverage for the current buffer. Use
`:CoverageToggle` to toggle coverage visibility for the current file.

# Installation

This example uses [Vundle](https://github.com/gmarik/Vundle.vim), whose
plugin-adding command is `Plugin`.

```vim
" Add maktaba and coverage to the runtimepath.
" (The latter must be installed before it can be used.)
Plugin 'google/vim-maktaba'
Plugin 'google/vim-coverage'
" Also add Glaive, which is used to configure coverage's maktaba flags. See
" `:help :Glaive` for usage.
Plugin 'google/vim-glaive'
call glaive#Install()
" Optional: Enable coverage's default mappings on the <Leader>C prefix.
Glaive coverage plugin[mappings]
```

Make sure you have updated maktaba recently. Older versions had an issue
detecting installed libraries.

# Using coverage providers

The easiest way to see the list of available providers is via tab completion:
Type `:CoverageShow <TAB>` in vim.

To use a particular provider, type `:CoverageShow PROVIDER-NAME`. This will
either show coverage in the current buffer using the selected provider or show
an error message if provider is not available. Normally you will trigger
providers via key mappings and/or autocommand hooks.

vim-coverage currently defines several coverage providers:
1. A [coverage.py](https://coverage.readthedocs.io/) provider for python.
2. A [covimerage](https://github.com/Vimjas/covimerage) provider for vimscript.
3. A gcov provider for [gcov](https://gcc.gnu.org/onlinedocs/gcc/Gcov.html), which handles [lcov tracefiles](http://ltp.sourceforge.net/coverage/lcov/geninfo.1.php).

See https://github.com/google/vim-coverage/issues for other planned
integrations.

Coverage offers a lot of customization on colors and signs rendered for covered
and uncovered lines. You can get a quick view of all coverage flags by executing
`:Glaive coverage`, or start typing flag names and use tab completion.  See
`:help Glaive` for usage details.

# Defining custom providers

Any plugin wishing to be a coverage provider needs only to register itself using
Maktaba's registry feature, passing a dictionary of following format:

  - `IsAvailable(filename)` - return `1` if plugin can handle the current file,
    otherwise `0`.
  - `GetCoverage(filename)` - returns the coverage dict created by
    `coverage#CreateReport` that contains all coverage data.
  - `name` - the name of the provider.
  - optional: `GetCoverageAsync(filename, callback)` - gets the coverage and
    once done, invokes the provided callback with the coverage dict created by
    `coverage#CreateReport` that contains all coverage data.

Example:

```vim
let s:registry = maktaba#extension#GetRegistry('coverage')
call s:registry.AddExtension({
    \ 'name': 'my_provider',
    \ 'GetCoverage': function('myplugin#GetCoverage'),
    \ 'GetCoverageAsync': function('myplugin#GetCoverageAsync'),
    \ 'IsAvailable': function('myplugin#IsAvailable')})
```
