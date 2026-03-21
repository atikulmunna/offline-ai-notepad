@echo off
setlocal

(for /l %%i in (1,1,200) do @echo y) | call "%~dp0android_sdkmanager.cmd" --licenses
