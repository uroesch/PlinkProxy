; ---------------------------------------------------------------------------------
; Version file used by the make, packaging and compile tools
; ---------------------------------------------------------------------------------
Global Const $VERSION       = "0.0.10-alpha"
Global Const $VERSION_MAJOR = (StringSplit($VERSION, '.-'))[1]
Global Const $VERSION_MINOR = (StringSplit($VERSION, '.-'))[2]
Global Const $VERSION_PATCH = (StringSplit($VERSION, '.-'))[3]
Global Const $VERSION_STATE = StringRight($VERSION, StringInStr($VERSION, '-') - 1)
