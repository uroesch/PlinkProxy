; --------------------------------------------------------------------------------------------------------------
; Script to quickly connect via socks proxy to various firewalled Windows hosts
; --------------------------------------------------------------------------------------------------------------
#include <Version.au3>
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
; Globals
; --------------------------------------------------------------------------------------------------------------
Global $GuiWidth         = 200
Global $GuiHeight        = 300
Global $ConfigFile       = @ScriptDir & "\PlinkProxy.ini"
Global $LogFile          = @ScriptDir & "\PlinkProxy.log"
Global $SessionLog       = []
Global $Tabs             = _AssocArray()
Global $Setup            = False
Global $Globals          = _AssocArray()
Global $TunnelPids       = _AssocArray()
Global $StatusTabs       = _AssocArray()
Global $Buttons          = _AssocArray()
Global $AppTitle         = 'PlinkProxy Control'
Global $AppVersion       = 'Version ' & StringReplace($VERSION, "-", " ")
Global $CanvasColor      = 0x333333
Global $TextColor        = 0xcccccc
Global $DefaultButtonBg  = $COLOR_PURPLE
Global $DefaultButtonFg  = $COLOR_WHITE
Global $ButtonExitBg     = 0xFF8800
Global $ButtonActiveBg   = 0x66DD00
Global $ButtonActiveFg   = $COLOR_BLACK
Global $ActiveButton     = Null
Global $Debug            = True
Global $RefreshInterval  = 5000
Global $StatusUpdate     = False
Global $LastTimerUpdate  = TimerInit()
Global $StatusTabParent  = Null
Global $FlyoutFactor     = 4

; --------------------------------------------------------------------------------------------------------------
; Options
; --------------------------------------------------------------------------------------------------------------
Opt("GUIResizeMode", $GUI_DOCKALL)
; --------------------------------------------------------------------------------------------------------------
; Functions
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
    Return IniRead($ConfigFile, $Section, $Field, "n/a")
EndFunc

; --------------------------------------------------------------------------------------------------------------

 Func EvaluatePath($Path)
    If Not StringInStr($Path, '%') Then
       Return $Path
    EndIf
    Local $Variables = StringRegExp($Path, "%.[^%]*%", 1)
    For $Index = 0 To $Variables[0]
        Local $EnvName  = $Variables[$Index]
        Local $EnvValue = EnvGet(StringReplace($EnvName, "%", ""))
        $ModifiedPath   = StringReplace($Path, $EnvName, $EnvValue)
    Next
    Logger('Debug', "Replacing '" & $Path & "' with '" & $ModifiedPath & "'")
    Return $ModifiedPath
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func UpdatePath()
    Local $Path    = EvaluatePath($Globals('path'))
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

Func AssembleProxyCommand($Host)
    ; Only return proxy command if jump host is not the first hop
    ; to prevent loops
    Local $ProxyCommand = ""
    If $Host <> $Globals('first_hop') Then
        $ProxyCommand = _
          ' -proxycmd "plink -nc ' & $Host & ':22 ' & $Globals('login') & '@' & $Globals('first_hop') & '" '
    EndIf
    Return $ProxyCommand
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func AssemblePlinkOptions($Host, $Options)
    Local $PlinkOptions = _
      $Options & " " _
      & AssembleProxyCommand($Host) _
      & $Globals('login') & '@' & $Host
    Return $PlinkOptions
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func DigTunnel($TunnelId, $Host, $Options)
    Local $PlinkCommand
    Local $HideWindow = @SW_HIDE
    Local $AllOptions = $Globals('plink_options') & ' ' & $Options
    Local $SetupMode  = StringLower(FetchEntry($TunnelId, 'setup'))
    If Not CheckTunnel($TunnelId) Then
        If $Setup And $SetupMode == 'yes' Then
            $AllOptions   = "-A -v " & $Options
            $HideWindow   = 1
            $PlinkCommand = 'plink ' & AssemblePlinkOptions($Host, $AllOptions)
            RunWait($PlinkCommand, "", $HideWindow)
        ElseIf $SetupMode <> 'yes' Then
            $PlinkCommand = 'plink ' & AssemblePlinkOptions($Host, $AllOptions)
            $TunnelPids($TunnelId) = Run($PlinkCommand, "", $HideWindow)
        EndIf
        Logger('Info', "Opening tunnel '" & $TunnelId & "' with command '" & $PlinkCommand & "'")
    EndIf
EndFunc
; --------------------------------------------------------------------------------------------------------------

Func DigSocksTunnel($TunnelId)
    Local $Enabled = FetchEntry($TunnelId, 'enabled')
    Local $Host    = FetchEntry($TunnelId, 'jump_host')
    Local $Options = "-D " & StringRegExpReplace($TunnelId, ".*:", "")
    If StringLower($Enabled) == 'no' Then
        Return
    EndIf
    DigTunnel($TunnelId, $Host, $Options)
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func DigLocalTunnel($TunnelId)
    Local $Enabled = FetchEntry($TunnelId, 'enabled')
    Local $Host    = FetchEntry($TunnelId, 'jump_host')
    Local $Options = _
      "-L " & StringRegExpReplace($TunnelId, ".*:", "") _
      & ':' & FetchEntry($TunnelId, 'target_host') _
      & ':' & FetchEntry($TunnelId, 'target_port')

    If StringLower($Enabled) == 'no' Then
        Return
    EndIf
    DigTunnel($TunnelId, $Host, $Options)
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
        Case Else
            MsgBox(1, "Tunnel Type Error", "Tunnel type " & $TunnelId & " not found!")
        EndSelect
    Next
    UpdateStatusList()
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

Func SshKeysDir()
    If IsDeclared('SshKeysDir') Then
        Return $SshKeysDir
    EndIf
    Global $SshKeysDir = EvaluatePath($Globals('ssh_keys_dir'))
    Return $SshKeysDir
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func FindSshKeys()
    Local $SshKeys = _FileListToArray(SshKeysDir(), '*ppk')
    If Not Ubound($SshKeys) Then
        Return ""
    EndIf
    Return _ArrayToString($SshKeys, " ", 1)
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func StartPageant()
    $Pageant = 'Pageant.exe'
    If Not ProcessExists($Pageant) Then
        ShellExecute($Pageant, FindSshKeys(), SshKeysDir(), "", @SW_HIDE)
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

Func IndentRight()
    Return (($GuiWidth / 2) - ($GuiWidth / 4 ))
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func _CreateTabButton($Label, $SizePart, $Position, _
    $ColorForeground = $DefaultButtonFg, $ColorBackground = $DefaultButtonBg)
    Local $Length         = ($GuiWidth * ($FlyoutFactor - 1)) / $SizePart
    Local $VerticalOffset = $GuiWidth + $Length * ($Position - 1)
    Local $Button = _
      GUICtrlCreateButton($Label, $VerticalOffset , ($GuiHeight - 20), $Length, -1, $BS_DEFPUSHBUTTON)
    ; MsgBox(-1, $Label, "1: " & $verticaloffset & "; 2: " & ($GuiHeight - 20) & "; 3: " & $length)
    _ColorButton($Button, $ColorForeground, $ColorBackground)
    Return $Button
EndFunc
; --------------------------------------------------------------------------------------------------------------

Func _ColorButton($Button, $ColorForeground, $ColorBackground)
    GUICtrlSetBkColor($Button, $ColorBackground)
    GUICtrlSetColor($Button, $ColorForeground)
EndFunc

Func _CreateColorButton($Label, $HeightFromBottom, _
    $ColorForeground = $DefaultButtonFg, $ColorBackground = $DefaultButtonBg)
    Local $Length = ($GuiWidth  - ($GuiWidth / 2))
    Local $Button = _
      GUICtrlCreateButton($Label, IndentRight(), ($GuiHeight - $HeightFromBottom), $Length, -1, $BS_DEFPUSHBUTTON)
        _ColorButton($Button, $ColorForeground, $ColorBackground)
    $ActiveButton = $Button
    Return $Button
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func _ChangeButtonToActive($Button)
    If $ActiveButton <> Null Then
        GUICtrlSetBkColor($ActiveButton, $DefaultButtonBg)
        GUICtrlSetColor($ActiveButton, $DefaultButtonFg)
    EndIf
    GUICtrlSetBkColor($Button, $ButtonActiveBg)
    GUICtrlSetColor($Button, $ButtonActiveFg)
    $ActiveButton = $Button
EndFunc

; --------------------------------------------------------------------------------------------------------------
Func UpdateSessionLog($Level, $Message)
    Local $LogEntry =  _Now() & " - " & $Level & " - " & $Message
    _ArrayAdd($SessionLog, $LogEntry)
    If ($Tabs('SessionLog')) Then
        _GUICtrlEdit_AppendText($Tabs('SessionLog'), $LogEntry & @CRLF)
        _GUICtrlEdit_Scroll($Tabs('SessionLog'), $SB_SCROLLCARET)
    EndIf
EndFunc

; -----------------------------------------------------------------------------------------     -------------------
Func CreateLogView()
    If Not ($Tabs('SessionLog')) Then
        Local $LogContent = _ArrayToString($SessionLog, @CRLF)
        $Tabs('SessionLog') = GuiCtrlCreateEdit($LogContent, $GuiWidth, 0, _
          ($GuiWidth * ($FlyoutFactor - 1)) - 5, $GuiHeight - 25, _
          Bitor($ES_WANTRETURN, $WS_VSCROLL, $ES_AUTOVSCROLL))
        GuiCtrlSendMsg($Tabs('Log'), 0xCF, 1, 0);read-only
        _GUICtrlEdit_Scroll($Tabs('Log'), $SB_SCROLLCARET)
        GuiCtrlSetBkColor($Tabs('SessionLog'), $CanvasColor)
        GuiCtrlSetColor($Tabs('SessionLog'), $COLOR_WHITE)
    EndIf
EndFunc

; --------------------------------------------------------------------------------------------------------------
Func ToggleStatus($Button, $Gui)
    Switch GuiCtrlRead($Button)
    Case 'Hide St&atus'
        GuiCtrlSetData($Button, "Show St&atus")
        GuiCtrlSetBkColor($Button, $DefaultButtonBg)
        WinMove($Gui, "", Default, Default, $GuiWidth)
        $StatusUpdate = False
    Case 'Show St&atus'
        GuiCtrlSetData($Button, "Hide St&atus")
        GuiCtrlSetBkColor($Button, $ButtonExitBg)
        WinMove($Gui, "", Default, Default, $GuiWidth * $FlyoutFactor)
        $StatusUpdate = True
        UpdateStatusList()
    EndSwitch
EndFunc

; --------------------------------------------------------------------------------------------------------------
Func CreateStatusList()
    If Not ($Tabs('ConnStatus')) Then
        $Tabs('ConnStatus') = GUICtrlCreateListView("Name|Type|Port|Status|PID", _
          $GuiWidth, 0, ($GuiWidth * ($FlyoutFactor - 1)) - 5, $GuiHeight - 25)
        _GUICtrlListView_SetExtendedListViewStyle($Tabs('ConnStatus'), $LVS_EX_DOUBLEBUFFER)
    EndIf
EndFunc

; --------------------------------------------------------------------------------------------------------------
Func UpdateStatusList()
    If Not ($StatusUpdate) Then
        Return
    EndIf
    CreateStatusList()
    GuiCtrlSetBkColor($Tabs('ConnStatus'), $CanvasColor)
    GuiCtrlSetColor($Tabs('ConnStatus'), $TextColor)
    _GuiCtrlListView_DeleteAllItems($Tabs('ConnStatus'))
    Local $Tunnels = FetchTunnels()
    For $Index = 1 To UBound($Tunnels) - 1
        Local $TunnelId  = $Tunnels[$Index]
        Local $Name      = FetchEntry($TunnelId, 'name')
        Local $Type      = (StringSplit($TunnelId, ':'))[1]
        Local $Port      = (StringSplit($TunnelId, ':'))[2]
        Local $Status    = CheckTunnel($TunnelId) ? 'Up' : 'Down'
        Local $RowValues = [$Name, $Type, $Port, $Status, $TunnelPids($TunnelId)]
        Local $Row = GUICtrlCreateListViewItem(_ArrayToString($RowValues, '|'), $Tabs('ConnStatus'))
        If ($Status == 'Up') Then
            GuiCtrlSetBkColor($Row, $ButtonActiveBg)
            GUICtrlSetColor($Row, $ButtonActiveFg)
        Else
            GuiCtrlSetBkColor($Row, $COLOR_PURPLE)
            GUICtrlSetColor($Row, $TextColor)
        EndIf
    Next
    $LastTimerUpdate = TimerInit()
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func InitTabs()
    CreateLogView()
    CreateStatusList()
    GuiCtrlSetState($Tabs('SessionLog'), $GUI_HIDE)
    GuiCtrlSetState($Tabs('ConnStatus'), $GUI_SHOW)
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
; Main
; --------------------------------------------------------------------------------------------------------------
Main()
