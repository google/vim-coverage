let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif


" Require maktaba 1.9.0 or later for maktaba#extension support.
if !maktaba#IsAtLeastVersion('1.9.0')
  call maktaba#error#Shout('Coverage requires maktaba version 1.9.0.')
  call maktaba#error#Shout('You have maktaba version %s.', maktaba#VERSION)
  call maktaba#error#Shout('Please update your maktaba install.')
endif


""
" Makes sure the coverage {provider} is a valid provider for the plugin.
" @throws BadValue if the provider is not valid.
function! EnsureProvider(provider) abort
  let l:required_fields = ['name', 'IsAvailable', 'GetCoverage']
  " Throw BadValue if any required fields are missing.
  let l:missing_fields =
      \ filter(copy(l:required_fields), '!has_key(a:provider, v:val)')
  if !empty(l:missing_fields)
    throw maktaba#error#BadValue('a:provider is missing fields: ' .
        \ join(l:missing_fields, ', '))
  endif
endfunction

call s:plugin.GetExtensionRegistry().SetValidator('EnsureProvider')
