@echo off
setlocal

set "ZIP=%LOCALAPPDATA%\Temp\commandlinetools-win-latest.zip"
set "SDK=%LOCALAPPDATA%\Android\Sdk"
set "LATEST=%SDK%\cmdline-tools\latest"

if exist "%LATEST%" rmdir /s /q "%LATEST%"
mkdir "%LATEST%"

tar -xf "%ZIP%" -C "%LATEST%"
xcopy "%LATEST%\cmdline-tools\*" "%LATEST%\" /E /I /Y >nul
rmdir /s /q "%LATEST%\cmdline-tools"

dir "%LATEST%"
