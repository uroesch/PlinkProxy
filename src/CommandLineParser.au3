; -----------------------------------------------------------------------------
; Author: Urs Roesch <github@bun.ch>
; Description: Command line parser for PlinkProxy
; Usage:
;   #include <CommandLineParser.au3>
;   AddOption($Short, $Long, $Message, $Default, $Type, $Validate, $Assign)
; -----------------------------------------------------------------------------
#include <Array.au3>

Func ParseValidatePath($Index, $Option)
    Local $Path = $CmdLine[$Index]
    If Not FileExists($Path) Then
        Usage(1, _
          "Path for argument " & $Option & ": " & _
          "with value '" & $Path & "' does not exist!" _
        )
    EndIf
    Return $Path
EndFunc

; -----------------------------------------------------------------------------

Func EvaluateOptions($Index, ByRef $Errors)
    Local $Input = $CmdLine[$Index]
    If Not StringRegExp($Input, '^-') Then Return True
    For $Position = 1 To Ubound($Options) - 1
        Local $Ref = $Options[$Position]
        If $Input == $Ref.Item('Short') Or $Input == $Ref.Item('Long') Then
            Switch $Ref.Item('Type')
            Case 'Help'
                Usage(255)
            Case 'Path'
                If $Ref.Item('Validate') == True Then
                    Assign($Ref.Item('Assign'), _
                      ParseValidatePath($Index + 1, $Input), 2)
                Else
                    Assign($Ref.Item('Assign'), $CmdLine[$Index + 1], 2)
                EndIf
            EndSwitch
            Return True
        EndIf
    Next
    _ArrayAdd($Errors, $Input)
EndFunc

; -----------------------------------------------------------------------------

Func ParseCommandLine()
    Local $Errors = []
    If $CmdLine[0] == 0 Then
        Return
    EndIf
    For $Index = 1 To $CmdLine[0]
        EvaluateOptions($Index, $Errors)
    Next
    If UBound($Errors) > 0 Then
        Usage(0, "Unknown options: '" & _ArrayToString($Errors, ", ") & "'")
    EndIf
EndFunc

; -----------------------------------------------------------------------------

Func AddOption($Short, $Long, $Message, $Default, $Type, $Validate, $Assign)
    If Not IsDeclared('Options') Then
        Global $Options = []
        Global $OptPosition = 1
    EndIf
    Local $Definition = ObjCreate('Scripting.Dictionary')
    $Definition.Add('Short', "-" & $Short)
    $Definition.Add('Long', "--" & $Long)
    $Definition.Add('Message', $Message)
    $Definition.Add('Default', $Default)
    $Definition.Add('Type', $Type)
    $Definition.Add('Validate', $Validate)
    $Definition.Add('Assign', $Assign)
    _ArrayAdd($Options, $Definition)
EndFunc

; -----------------------------------------------------------------------------

Func Usage($ExitCode = 0, $ErrorMessage = '')
    Local $Usage = ''
    If $ErrorMessage <> '' Then
        $Usage &= @LF & "ERROR: " & $ErrorMessage & @LF
    EndIf

    $Usage &= @LF & _
      "Usage:"  & @LF & _
      @TAB & @ScriptName & " <Options>" & @LF & @LF & _
      @TAB & "Options:" & @LF
    For $Index = 1 To UBound($Options) - 1
        Local $Ref = $Options[$Index]
        $Usage &= @TAB & $Ref.Item('Short') & " | " & $Ref.Item('Long') & @LF
        $Usage &= @TAB & @TAB & $Ref.Item('Message') & @LF
        If $Ref.Item('Default') <> '' Then
            $Usage &= @TAB & @TAB & "Default: " & $Ref.Item('Default') & @LF
        EndIf
    Next
    ; ConsoleWrite($Usage)
    MsgBox(-1, "Error parsing command line options", $Usage)
    ; Only Exit if an error from validate is being issued
    If $ExitCode > 0 Then Exit $ExitCode
EndFunc
