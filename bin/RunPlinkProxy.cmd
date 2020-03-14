@echo on

:: ---------------------------------------------------------------------------
:: Globals
:: ---------------------------------------------------------------------------
set PATH=%PATH%;%ProgramFiles(x86)%\AutoIt3
set SCRIPT_DIR=%~dp0
set SOURCE_DIR=%SCRIPT_DIR%..\src
set APPNAME=PlinkProxy

autoit.exe "%SOURCE_DIR%\%APPNAME%.au3"
