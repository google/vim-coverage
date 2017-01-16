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


let s:registry = s:plugin.GetExtensionRegistry()
call s:registry.SetValidator('coverage#EnsureProvider')

call s:registry.AddExtension(coverage#python#GetCoveragePyProvider())
