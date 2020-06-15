; --------------------------------------------------------------------------------------------------------------
; Author: Urs Roesch <github@bun.ch>
; Description: Data Structure for Plink Proxy
; --------------------------------------------------------------------------------------------------------------

Global $_Tunnel       = _AssocArray()
Global $_TunnelFields = [ _
    'pid', _
    'status' _
]

; --------------------------------------------------------------------------------------------------------------

Func _AssocArray()
    Local $AssocArray = ObjCreate("Scripting.Dictionary")
    If @error Then
        Return SetError(1, 0, 0)
    EndIf
    $AssocArray.CompareMode = 1
    Return $AssocArray
EndFunc

; --------------------------------------------------------------------------------------------------------------

; Return a default value for a field default is 'n/a'
Func _DefaultValues($Field)
    Switch $Field
    Case 'jump_login'
        Return $Globals('login')
    Case 'jump_hostkey'
        Return ''
    Case 'jump_port'
        Return 22
    Case Else
        Return 'n/a'
    EndSwitch
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func _ReadGlobalConfig()
    Logger('Info', 'Reading global section from ' & $ConfigFile)
    Local $Section = IniReadSection($ConfigFile, 'Globals')
    For $Index = 1 To $Section[0][0]
        $Globals($Section[$Index][0]) = $Section[$Index][1]
    Next
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func _FetchTunnels()
    Local $Tunnels   = []
    Local $Sections  = IniReadSectionNames($ConfigFile)
    For $Index = 1 To $Sections[0]
    ; Filter special Sections without colons
    If StringInStr($Sections[$Index], ":") Then
       If (_FetchEntry($Sections[$Index], 'enabled') == 'yes') Then
           _ArrayAdd($Tunnels, $Sections[$Index])
       EndIf
    EndIf
    Next
    _ArraySort($Tunnels)
    Return $Tunnels
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func _FetchEntry($Section, $Field, $Prefix = "")
    If $Prefix <> "" Then
        $Section = $Prefix & ":" & $Section
    EndIf
    Return IniRead($ConfigFile, $Section, $Field, _DefaultValues($Field))
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func _TunnelInit($Id)
    If $_Tunnel.Exists($Id) Then
        Return
    EndIf
    $_Tunnel($Id) = _AssocArray()
    For $Index = 0 To Ubound($_TunnelFields) - 1
      $_Tunnel($Id).Add($_TunnelFields[$Index], Null)
    Next
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func _TunnelFetch($Id, $Field)
    _TunnelInit($Id)
    If $_Tunnel($Id).Exists($Field) Then
      Return $_Tunnel($Id).Item($Field)
    EndIf
    Return ""
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func _TunnelStore($Id, $Field, $Value)
    _TunnelInit($Id)
    If $_Tunnel($Id).Exists($Field) Then
      $_Tunnel($Id).Item($Field) = $Value
    Else
      $_Tunnel($Id).Add($Field, $Value)
    EndIf
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func _CreateTunnelId($Connection, $JumpHost, $JumpPort)
    Return $Connection & "/" & $JumpHost & ":" & $JumpPort
EndFunc


; --------------------------------------------------------------------------------------------------------------
; Sample Usage
; --------------------------------------------------------------------------------------------------------------
; $Id = _CreateTunnelID('foo', 'bar', 123)
; ConsoleWrite($Id)
; _TunnelInit($Id)
; _TunnelStore($Id, 'pid', 1234)
; ConsoleWrite(_TunnelFetch($Id, 'pid'))
; --------------------------------------------------------------------------------------------------------------
