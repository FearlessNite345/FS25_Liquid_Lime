@echo off
setlocal

set "MOD_NAME=FS25_Liquid_Lime"
if not "%~1"=="" set "MOD_NAME=%~1"

set "ROOT=%~dp0"
set "OUTPUT=%ROOT%%MOD_NAME%.zip"
set "STAGE=%TEMP%\%MOD_NAME%_build_%RANDOM%%RANDOM%"

pushd "%ROOT%" || exit /b 1

if not exist "modDesc.xml" (
    echo ERROR: modDesc.xml was not found. Run this script from the mod root folder.
    popd
    exit /b 1
)

if exist "%OUTPUT%" (
    echo Removing existing "%OUTPUT%"
    del /f /q "%OUTPUT%" || (
        echo ERROR: Could not remove existing zip: "%OUTPUT%"
        popd
        exit /b 1
    )
)

set "BUILD_ROOT=%ROOT%"
set "BUILD_STAGE=%STAGE%"
set "BUILD_OUTPUT=%OUTPUT%"
set "BUILD_MOD_NAME=%MOD_NAME%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop';" ^
    "$root = $env:BUILD_ROOT;" ^
    "$stage = $env:BUILD_STAGE;" ^
    "$output = $env:BUILD_OUTPUT;" ^
    "$modName = $env:BUILD_MOD_NAME;" ^
    "$excludedNames = @('.git', '.agents', '.codex', '.gitignore', '.gitattributes', 'build.bat', 'README.md', 'FS25_Liquid_Lime.zip', ($modName + '.zip'));" ^
    "if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force };" ^
    "New-Item -ItemType Directory -Path $stage | Out-Null;" ^
    "Get-ChildItem -LiteralPath $root -Force | Where-Object { $excludedNames -notcontains $_.Name -and $_.Extension -ne '.log' -and $_.Extension -ne '.zip' } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $stage -Recurse -Force };" ^
    "Push-Location -LiteralPath $stage;" ^
    "try { tar -a -c -f $output * } finally { Pop-Location };" ^
    "Remove-Item -LiteralPath $stage -Recurse -Force"
set "ZIP_EXIT=%ERRORLEVEL%"

popd

if not "%ZIP_EXIT%"=="0" (
    echo ERROR: Failed to create zip.
    exit /b %ZIP_EXIT%
)

echo Built "%OUTPUT%"
exit /b 0
