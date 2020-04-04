@echo off

:: ----------------------------------------------------------------------------
:: Globals
:: ----------------------------------------------------------------------------
set SCRIPT_DIR=%~dp0
set PATH=%PATH%;%ProgramFiles(x86)%\AutoIt3\Aut2Exe
set PATH=%PATH%;%SCRIPT_DIR%\..\install\Aut2Exe
set BASE_DIR=%SCRIPT_DIR%..\
set SOURCE_DIR=%BASE_DIR%src
set RELEASE_DIR=%BASE_DIR%releases
set VERSION_FILE=%SOURCE_DIR%\Version.au3
set APPNAME=PlinkProxy
set DELIMITER=.........................................
set RELEASE_PATH


:: ----------------------------------------------------------------------------
:: Main
:: ----------------------------------------------------------------------------
call :EXTRACT_VERSION
call :COMPILE
call :CREATE_RELEASE
call :ZIP_RELEASE
exit /b

:: ----------------------------------------------------------------------------
:: Subs
:: ----------------------------------------------------------------------------
:EXTRACT_VERSION
  set FIND_CMD=findstr /r /c:"VERSION .*=" %VERSION_FILE%
  echo --- Fetching release number ---
  for /f "delims== tokens=2 usebackq" %%f in (`%FIND_CMD%`) DO (
    set VERSION=%%f
  )
  :: remove spaces and quotes
  set VERSION=%VERSION: =%
  set VERSION=%VERSION:"=%
  set VERSION=v%VERSION%
  echo Release number is %VERSION%
  echo %DELIMITER%
goto :EOF

:: ----------------------------------------------------------------------------
:COMPILE
  echo --- Compile %APPNAME% version %VERSION% ---
  set BINARY="%SCRIPT_DIR%\%APPNAME%_%VERSION%.exe"
  aut2exe ^
    /in "%SOURCE_DIR%\%APPNAME%.au3" ^
    /out "%BINARY%" ^
    /icon "%SOURCE_DIR%\%APPNAME%.ico"
  echo Saved to %BINARY%
  echo %DELIMITER%
goto :EOF

:: ----------------------------------------------------------------------------
:CREATE_RELEASE
  echo --- Creating release for %VERSION% ---
  set RELEASE_PATH=%RELEASE_DIR%\%APPNAME%_%VERSION%
  mkdir "%RELEASE_PATH%" 2> nul
  copy /y "%BINARY%" "%RELEASE_PATH%\%APPNAME%.exe" 1>nul
  copy /y "%BASE_DIR%\README.md" "%RELEASE_PATH%" 1>nul
  copy /y "%SOURCE_DIR%\%APPNAME%.ini-sample" "%RELEASE_PATH%" 1>nul 
  echo Release ist under %RELEASE_PATH%
  echo %DELIMITER%
goto :EOF

:: ----------------------------------------------------------------------------
:ZIP_RELEASE
  echo --- Creating zip file for release %VERSION% ---
  where 7z.exe 1>nul 2>nul
  IF %ERRORLEVEL% NEQ 0 (
    echo Could not find 7z.exe -- Not creating release zip.
    echo %DELIMITER%
    goto :eof
  )
  7z.exe a -r "%RELEASE_PATH%.zip" "%RELEASE_PATH%" 1>nul
  echo "Created zip file %RELEASE_PATH%.zip
  echo %DELIMITER%
goto :EOF