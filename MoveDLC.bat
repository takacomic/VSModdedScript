@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM --- Step 1: Get Steam directory from registry ---
FOR /F "usebackq tokens=2*" %%A IN (`reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul`) DO (
    SET "STEAM_DIR=%%B"
)

IF NOT DEFINED STEAM_DIR (
    echo Steam directory not found in registry!
    pause
    exit /b
)

REM --- Detect Windows version (10 vs 11) ---
FOR /F "tokens=3" %%A IN ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild ^| find "CurrentBuild"') DO (
    SET "WIN_BUILD=%%A"
)

IF %WIN_BUILD% GEQ 22000 (
    SET "PATHSEP=\"
) ELSE (
    SET "PATHSEP=/"
)

SET "STEAM_DIR=%STEAM_DIR%%PATHSEP%steamapps%PATHSEP%common"

SET "VSMODDED=%STEAM_DIR%%PATHSEP%VSModded"
SET "VSORIGINAL=%STEAM_DIR%%PATHSEP%Vampire Survivors"
SET "VSBACKUP=%STEAM_DIR%%PATHSEP%VSDLCBackup"

REM --- Create directories if they don't exist ---
FOR %%D IN ("%VSMODDED%" "%VSORIGINAL%" "%VSBACKUP%") DO (
    IF NOT EXIST "%%D" (
        echo Creating directory %%D...
        mkdir "%%D"
    )
)

SET "FOLDERS=2230760 2313550 2690330 2887680 3210350 3451100"

REM --- Move folders from Vampire Survivors to backup ---
echo Backing up original folders from Vampire Survivors...
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSORIGINAL%\%%F" (
        robocopy "%VSORIGINAL%\%%F" "%VSBACKUP%\%%F" /MOVE /E
        rmdir /S /Q "%VSORIGINAL%\%%F"
    )
)

REM --- Move folders from VSModded to Vampire Survivors ---
echo Swapping in modded folders...
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSMODDED%\%%F" (
        robocopy "%VSMODDED%\%%F" "%VSORIGINAL%\%%F" /MOVE /E
        rmdir /S /Q "%VSMODDED%\%%F"
    )
)

REM --- Launch Vampire Survivors from VSModded and wait ---
echo Launching Vampire Survivors...
START /WAIT "" "%VSMODDED%\VampireSurvivors.exe"

REM --- Reverse the folder moves ---
echo Reverting folders to original state...

REM Move folders from Vampire Survivors back to VSModded
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSORIGINAL%\%%F" (
        robocopy "%VSORIGINAL%\%%F" "%VSMODDED%\%%F" /MOVE /E
        rmdir /S /Q "%VSORIGINAL%\%%F"
    )
)

REM Move folders from backup back to Vampire Survivors
FOR %%F IN (%FOLDERS%) DO (
    IF EXIST "%VSBACKUP%\%%F" (
        robocopy "%VSBACKUP%\%%F" "%VSORIGINAL%\%%F" /MOVE /E
        rmdir /S /Q "%VSBACKUP%\%%F"
    )
)

echo All done. Folders restored.
