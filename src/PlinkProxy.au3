; --------------------------------------------------------------------------------------------------------------
; Author: Urs Roesch <github@bun.ch>
; Description: Script to quickly connect via socks proxy or port forwarding to various hosts behind firewalls.
; --------------------------------------------------------------------------------------------------------------

; --------------------------------------------------------------------------------------------------------------
; Includes
; --------------------------------------------------------------------------------------------------------------
#include <Version.au3>
#include <CommandLineParser.au3>
#include <PlinkProxyGui.au3>
#include <TabConstants.au3>
#include <GUIConstantsEx.au3>
#include <ColorConstants.au3>
#include <MsgBoxConstants.au3>
#include <ButtonConstants.au3>
#include <WindowsConstants.au3>
#include <ScrollBarsConstants.au3>
#include <GuiListView.au3>
#include <GuiEdit.au3>
#include <GuiTab.au3>
#include <Array.au3>
#include <Date.au3>
#include <File.au3>

; --------------------------------------------------------------------------------------------------------------
; Global Constants
; --------------------------------------------------------------------------------------------------------------
Global Const $GuiWidth        = 200
Global Const $GuiHeight       = 300
Global Const $FlyoutFactor    = 4
Global Const $AppTitle        = 'PlinkProxy Control'
Global Const $AppVersion      = 'Version ' & StringReplace($VERSION, "-", " ")
Global Const $StatusHeader[5] = ["Name", "Type", "Port", "Status", "PID"]
Global Const $HostKeyRegExp   = '^([A-Fa-f0-9]{2}:){15}[A-Fa-f0-9]{2}$'

; --------------------------------------------------------------------------------------------------------------
; Global Constants (Colors)
; --------------------------------------------------------------------------------------------------------------
Global Const $CanvasColor      = 0x333333
Global Const $TextColor        = 0xcccccc
Global Const $DefaultButtonBg  = $COLOR_PURPLE
Global Const $DefaultButtonFg  = $COLOR_WHITE
Global Const $ButtonExitBg     = 0xFF8800
Global Const $ButtonActiveBg   = 0x66DD00
Global Const $ButtonActiveFg   = $COLOR_BLACK

; --------------------------------------------------------------------------------------------------------------
; Globals
; --------------------------------------------------------------------------------------------------------------
Global $ConfigFile      = @ScriptDir & "\PlinkProxy.ini"
Global $LogFile         = @ScriptDir & "\PlinkProxy.log"
Global $SessionLog      = []
Global $Debug           = True
Global $StatusUpdate    = False
Global $LastTimerUpdate = TimerInit()
Global $Setup           = False
Global $ActiveButton    = Null
Global $StatusTabParent = Null
Global $Tabs            = _AssocArray()
Global $Globals         = _AssocArray()
Global $TunnelPids      = _AssocArray()
Global $TunnelStatus    = _AssocArray()
Global $StatusTabs      = _AssocArray()
Global $Buttons         = _AssocArray()
Global $RefreshInterval = 5000

; --------------------------------------------------------------------------------------------------------------
; Options
; --------------------------------------------------------------------------------------------------------------
Opt("GUIResizeMode", $GUI_DOCKALL)
Opt("ExpandEnvStrings", 1)
Opt("MustDeclareVars", 1)

; --------------------------------------------------------------------------------------------------------------
; Define Autoit Environment Variables
; --------------------------------------------------------------------------------------------------------------
EnvSet('ScriptDir', @ScriptDir)

; --------------------------------------------------------------------------------------------------------------
; Functions
; --------------------------------------------------------------------------------------------------------------

; Return a default value for a field default is 'n/a'
Func DefaultValues($Field)
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

Func _AssocArray()
    Local $AssocArray = ObjCreate("Scripting.Dictionary")
    If @error Then
        Return SetError(1, 0, 0)
    EndIf
    $AssocArray.CompareMode = 1
    Return $AssocArray
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func Logger($Level, $Message)
    Switch StringLower($Level)
    Case 'debug' And Not $Debug
        Return
    EndSwitch
    $Level = StringUpper($Level)
    Local $LogMessage = @ScriptName & '[' & @ComputerName & '] - ' & $Level & ' - ' & $Message
    UpdateSessionLog($Level, $Message)
    _FileWriteLog($LogFile, $LogMessage)
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func ConfigExists()
    If Not FileExists($ConfigFile) Then
        Local $Message = "Config file '" & $ConfigFile & "' not found, giving up!"
        Logger('Fatal', $Message)
        MsgBox(-1, 'Fatal Error', $Message)
        Exit 127
    EndIf
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func ReadGlobalConfig()
    Logger('Info', 'Reading global section from ' & $ConfigFile)
    Local $Section = IniReadSection($ConfigFile, 'Globals')
    For $Index = 1 To $Section[0][0]
        $Globals($Section[$Index][0]) = $Section[$Index][1]
    Next
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func FetchTunnels()
    Local $Tunnels   = []
    Local $Sections  = IniReadSectionNames($ConfigFile)
    For $Index = 1 To $Sections[0]
    ; Filter special Sections without colons
    If StringInStr($Sections[$Index], ":") Then
       If (FetchEntry($Sections[$Index], 'enabled') == 'yes') Then
           _ArrayAdd($Tunnels, $Sections[$Index])
       EndIf
    EndIf
    Next
    _ArraySort($Tunnels)
    Return $Tunnels
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func FetchEntry($Section, $Field, $Prefix = "")
    If $Prefix <> "" Then
        $Section = $Prefix & ":" & $Section
    EndIf
    Return IniRead($ConfigFile, $Section, $Field, DefaultValues($Field))
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func UpdatePath()
    Local $Path    = $Globals('path')
    Local $EnvPath = EnvGet('PATH')
    EnvSet('PATH', $EnvPath & ';' & $Path)
    EnvUpdate()
    Logger('Debug', "Update PATH environment variable to '" & EnvGet('PATH') & "'")
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func EditConfiguration()
    Run('notepad.exe ' & $ConfigFile)
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func AssembleHost($Host)
    If StringInStr($Host, ':') Then
        Return $Host
    EndIf
    Return $Host & ':22'
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func HostKey($FingerPrint) 
    Local $HostKey = ""
    If StringRegExp($FingerPrint, $HostKeyRegExp) Then
      $HostKey = '-hostkey ' & $FingerPrint
    EndIf 
    Return $HostKey
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func AssembleProxyCommand($JumpHost, $JumpPort = 22)
    ; Only return proxy command if jump host is not the first hop
    ; to prevent loops
    Local $ProxyCommand = ""
    If $JumpHost <> $Globals('first_hop') Then
        $ProxyCommand = _
          ' -proxycmd "plink -nc ' _
          & $JumpHost & ':' & $JumpPort & ' ' _
          & HostKey($Globals('first_hop_hostkey')) & ' ' _
          & $Globals('login') & '@' & $Globals('first_hop') & '" '
    EndIf
    Return $ProxyCommand
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func AssemblePlinkOptions($TunnelId, $Options)
    Local $JumpHost    = FetchEntry($TunnelId, 'jump_host')
    Local $JumpHostKey = FetchEntry($TunnelId, 'jump_hostkey')
    Local $JumpPort    = FetchEntry($TunnelId, 'jump_port')
    Local $Login       = FetchEntry($TunnelId, 'jump_login')
    ; If the connectin is to forwarded port from another incoming ssh connection on the first hop
    ; then we need to set to connect host to the same value as the first_hop. Otherwise the connection
    ; is attempted locally.
    Local $ConnectHost = $JumpHost
    If StringRegExp($Jumphost, "^(localhost\.?|127\.0\.0\.1|::1)$") Then
        $ConnectHost = $Globals('first_hop')
    EndIf
    Local $PlinkOptions = _
      $Options & " " _
      & AssembleProxyCommand($JumpHost, $JumpPort) _
      & HostKey($JumpHostKey) & " " _
      & $Login & '@' & $ConnectHost
    Return $PlinkOptions
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func DigTunnel($TunnelId, $Options)
    Local $PlinkCommand
    Local $Enabled     = FetchEntry($TunnelId, 'enabled')
    Local $JumpPort    = FetchEntry($TunnelId, 'jump_port')
    Local $HideWindow  = @SW_HIDE
    Local $AllOptions  = $Globals('plink_options') & ' -P ' & $JumpPort & ' ' & $Options
    Local $SetupMode   = StringLower(FetchEntry($TunnelId, 'setup'))
    ; skip non enabled tunnels
    If StringLower($Enabled) == 'no' Then
        Return
    EndIf
    If Not CheckTunnel($TunnelId) Then
        If $Setup And $SetupMode == 'yes' Then
            $AllOptions   = '-A -v -P ' & $JumpPort & ' ' & $Options
            $HideWindow   = 1
            $PlinkCommand = 'plink ' & AssemblePlinkOptions($TunnelId, $AllOptions)
            RunWait($PlinkCommand, "", $HideWindow)
        ElseIf $SetupMode <> 'yes' Then
            $PlinkCommand = 'plink ' & AssemblePlinkOptions($TunnelId, $AllOptions)
            $TunnelPids($TunnelId) = Run($PlinkCommand, "", $HideWindow)
        EndIf
        Logger('Info', "Opening tunnel '" & $TunnelId & "' with command '" & $PlinkCommand & "'")
    EndIf
EndFunc
; --------------------------------------------------------------------------------------------------------------

Func DigSocksTunnel($TunnelId)
    Local $Options = "-D " & StringRegExpReplace($TunnelId, ".*:", "")
    DigTunnel($TunnelId, $Options)
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func DigLocalTunnel($TunnelId)
    Local $Options = _
      "-L " & StringRegExpReplace($TunnelId, ".*:", "") _
      & ':' & FetchEntry($TunnelId, 'target_host') _
      & ':' & FetchEntry($TunnelId, 'target_port')
    DigTunnel($TunnelId, $Options)
 EndFunc

; --------------------------------------------------------------------------------------------------------------

Func DigRemoteTunnel($TunnelId)
    Local $Options = _
      "-R " & StringRegExpReplace($TunnelId, ".*:", "") _
      & ':' & FetchEntry($TunnelId, 'target_host') _
      & ':' & FetchEntry($TunnelId, 'target_port')
    DigTunnel($TunnelId, $Options)
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func CheckTunnel($TunnelId)
    If ProcessExists($TunnelPids($TunnelId)) <> 0 Then
        Return True
    Else
        $TunnelPids($TunnelId) = Null
        Return False
    EndIf
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func DigTunnels()
    ; ensure the global config values are read each time
    ReadGlobalConfig()
    Local $Tunnels = FetchTunnels()
    For $Index = 1 To UBound($Tunnels) - 1
        Local $TunnelId = $Tunnels[$Index]
        Select
        Case StringInStr($TunnelId, 'Socks')
            DigSocksTunnel($TunnelId)
        Case StringInStr($TunnelId, 'LocalTunnel')
            DigLocalTunnel($TunnelId)
         Case StringInStr($TunnelId, 'RemoteTunnel')
            DigRemoteTunnel($TunnelId)
        Case Else
            MsgBox(1, "Tunnel Type Error", "Tunnel type " & $TunnelId & " not found!")
        EndSelect
        UpdateStatusRow($TunnelId)
    Next
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func CloseTunnels()
    Local $Tunnels = FetchTunnels()
    For $Index = 1 To UBound($Tunnels) - 1
        Local $TunnelId = $Tunnels[$Index]
        If CheckTunnel($TunnelId) Then
             ; ProcessClose is not cutting the mustard
             Run('taskkill /t /f /pid ' & $TunnelPids($TunnelId), "", @SW_HIDE)
             Logger('Info', "Shutting down tunnel '" & $TunnelId & "'")
        EndIf
    Next
    UpdateStatusList()
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func FindSshKeys()
    Local $SshKeys = _FileListToArray($Globals('ssh_keys_dir'), '*ppk')
    If Not Ubound($SshKeys) Then
        Return ""
    EndIf
    Return _ArrayToString($SshKeys, " ", 1)
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func StartPageant()
    Local $Pageant = 'Pageant.exe'
    If Not ProcessExists($Pageant) Then
        ShellExecute($Pageant, FindSshKeys(), $Globals('ssh_keys_dir'), "", @SW_HIDE)
        Logger('Info', 'Starting peageant to load ssh keys')
    EndIf
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func Main()
    Logger('Info', 'Starting ' & @ScriptName)
    ReadGlobalConfig()
    UpdatePath()
    StartPageant()
    StartProxyGui()
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func StartProxyGui()
    Local $ProxyGui = GUICreate($AppTitle, $GuiWidth, $GuiHeight)
    GuiSetBkColor($CanvasColor)

    ; reverse order of buttons
    $Buttons('Exit')   = _CreateColorButton("&Exit", 60, $DefaultButtonFg, $ButtonExitBg)
    $Buttons('Edit')   = _CreateColorButton("Edit &Config", 100)
    $Buttons('Setup')  = _CreateColorButton("Set&up Proxies", 140)
    $Buttons('Status') = _CreateColorButton("Show St&atus", 180)
    $Buttons('Stop')   = _CreateColorButton("St&op Proxies", 220)
    $Buttons('Start')  = _CreateColorButton("&Start Proxies", 260)

    $Buttons('ConnStatus') = _CreateTabButton("Connection Status", 2, 1)
    $Buttons('SessionLog') = _CreateTabButton("Session Log", 2, 2)
    InitTabs()

    GUICtrlCreateLabel($AppTitle, IndentRight(), 20)
    GUICtrlSetColor(-1, $TextColor)
    GUICtrlCreateLabel($AppVersion, IndentRight(), ($GuiHeight - 20))
    GUICtrlSetColor(-1, $TextColor)

    GUISetState(@SW_SHOW)

    While 1
        Switch GUIGetMsg()
        Case $Buttons('Start')
            $Setup = False
            DigTunnels()
            _ChangeButtonToActive($Buttons('Start'))
        Case $Buttons('Stop')
            CloseTunnels()
            _ChangeButtonToActive($Buttons('Stop'))
        Case $Buttons('Status')
            ToggleStatus($Buttons('Status'), $ProxyGui)
        Case $Buttons('Setup')
            $Setup = True
            CloseTunnels()
            _ChangeButtonToActive($Buttons('Setup'))
            DigTunnels()
        Case $Buttons('Edit')
            _ChangeButtonToActive($Buttons('Edit'))
            EditConfiguration()
        Case $Buttons('ConnStatus')
            GuiCtrlSetState($Tabs('SessionLog'), $GUI_HIDE)
            GuiCtrlSetState($Tabs('ConnStatus'), $GUI_SHOW)
        Case $Buttons('SessionLog')
            GuiCtrlSetState($Tabs('ConnStatus'), $GUI_HIDE)
            GuiCtrlSetState($Tabs('SessionLog'), $GUI_SHOW)
        Case $Buttons('Exit')
           ExitLoop
        EndSwitch

        ; Check the timer and update the Status if time is right
        If (TimerDiff($LastTimerUpdate) >= $RefreshInterval) Then
            UpdateStatusList()
        EndIf
    WEnd

    CloseTunnels()
    GUIDelete($ProxyGui)
    Logger('Info', 'Shutting down ' & @ScriptName)
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func DefineCmdLineOptions()
    ; AddOption($Short, $Long, $Message, $Default, $Type, $Validate, $Assign)
    AddOption('h', 'help', 'Display this message and exit', '', 'Help', False, False)
    AddOption('c', 'config-file', 'Path to config file', 'PlinkProxy.ini', 'Path', True, 'ConfigFile')
    AddOption('l', 'log-file', 'Path to log file', 'PlinkProxy.log', 'Path', False, 'LogFile')
EndFunc

; --------------------------------------------------------------------------------------------------------------
; Main
; --------------------------------------------------------------------------------------------------------------
DefineCmdLineOptions()
ParseCommandLine()
ConfigExists()
Main()
