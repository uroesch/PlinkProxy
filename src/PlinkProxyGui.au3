; --------------------------------------------------------------------------------------------------------------
; Author: Urs Roesch <github@bun.ch>
; Description: Gui Functions for PlinkProxy
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

; --------------------------------------------------------------------------------------------------------------

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

; --------------------------------------------------------------------------------------------------------------

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
        Local $ListWidth    = ($GuiWidth * ($FlyoutFactor - 1)) - 5
        Local $ColumnWidth  = ($ListWidth / UBound($StatusHeader)) - Ubound($StatusHeader)
        $Tabs('ConnStatus') = GUICtrlCreateListView("", $GuiWidth, 0, $ListWidth, $GuiHeight - 25)
        _GUICtrlListView_SetExtendedListViewStyle( _
          $Tabs('ConnStatus'), _
          BitOR($LVS_EX_DOUBLEBUFFER, $LVS_EX_FULLROWSELECT, $LVS_EX_SUBITEMIMAGES) _
        )
        For $Index = 0 To UBound($StatusHeader) - 1
            _GUICtrlListView_InsertColumn($Tabs('ConnStatus'), $Index, $StatusHeader[$Index], $ColumnWidth)
        Next
        GUISetState(@SW_SHOW)
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
    Local $Tunnels = FetchTunnels()
    For $Index = 1 To UBound($Tunnels) - 1
      Local $TunnelId = $Tunnels[$Index]
      UpdateStatusRow($TunnelId)
    Next
    $LastTimerUpdate = TimerInit()
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func UpdateStatusRow($TunnelId)
    CreateStatusList()
    Local $Name      = FetchEntry($TunnelId, 'name')
    Local $Type      = (StringSplit($TunnelId, ':'))[1]
    Local $Port      = (StringSplit($TunnelId, ':'))[2]
    Local $Status    = CheckTunnel($TunnelId) ? 'Up' : 'Down'
    Local $RowValues = [$Name, $Type, $Port, $Status, $TunnelPids($TunnelId)]
    CreateStatusRow($TunnelId, $RowValues)
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func FindStatusRow($Name)
    Return _GUICtrlListView_FindText($Tabs('ConnStatus'), $Name, -1, False)
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func CreateStatusRow($TunnelId, $RowValues)
    Local $Position = FindStatusRow($RowValues[0])
    _GUICtrlListView_BeginUpdate($Tabs('ConnStatus'))
    If $Position == -1 Then
        ;MsgBox(-1, 'tunnelid', $Tunnelid)
        ; I could not figure out a way to color each row without the following construct. It works but I think
        ; I have to seriously look at DLLStructCreate() to have everything in one Handy location.
        Local $Handle = GUICtrlCreateListViewItem(_ArrayToString($RowValues, '|'), $Tabs('ConnStatus'))
        $TunnelStatus($TunnelId) = $Handle
        ColorStatusRow($Handle, $RowValues[3])
    Else
        ; Only Update Stautus and PID
        For $Index = 3 To UBound($RowValues) - 1
            _GUICtrlListView_SetItem($Tabs('ConnStatus'), $RowValues[$Index], $Position, $Index)
        Next
        ColorStatusRow($TunnelStatus($TunnelId), $RowValues[3])
    EndIf
    _GUICtrlListView_EndUpdate($Tabs('ConnStatus'))
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func ColorStatusRow($Handle, $Status)
    ; MsgBox(-1, $Handle, "Status: " & $Status)
    If ($Status == 'Up') Then
        GuiCtrlSetBkColor($Handle, $ButtonActiveBg)
        GUICtrlSetColor($Handle, $ButtonActiveFg)
    Else
        GuiCtrlSetBkColor($Handle, $COLOR_PURPLE)
        GUICtrlSetColor($Handle, $TextColor)
    EndIf
EndFunc

; --------------------------------------------------------------------------------------------------------------

Func InitTabs()
    CreateLogView()
    CreateStatusList()
    GuiCtrlSetState($Tabs('SessionLog'), $GUI_HIDE)
    GuiCtrlSetState($Tabs('ConnStatus'), $GUI_SHOW)
EndFunc
