@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "RUNNER_JS=%SCRIPT_DIR%..\engine_runner.cjs"

where node >nul 2>nul
if errorlevel 1 (
    echo {"success": false, "error_code": 2, "message": "未检测到 node，无法运行 163-email-skill"}
    exit /b 1
)

node "%RUNNER_JS%" %*
exit /b %ERRORLEVEL%
