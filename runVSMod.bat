@echo off

SET "PS_SCRIPT=.\VSModdedInstall.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
