@echo off
title NeuraLearn Server
cd /d "%~dp0"

REM If the server is already running, just open the app.
powershell -NoProfile -Command "try { Invoke-RestMethod -Uri 'http://127.0.0.1:4173/api/health' -TimeoutSec 3 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>nul
if not errorlevel 1 (
  echo [NeuraLearn] Server is already running. Opening the app...
  start "" "http://127.0.0.1:4173/app/"
  exit /b 0
)

where node >nul 2>nul
if errorlevel 1 (
  echo [NeuraLearn] Node.js was not found. Install Node.js 20 or newer from https://nodejs.org , then double-click this file again.
  pause
  exit /b 1
)

if not exist ".env" (
  echo [NeuraLearn] No .env file found. Copy .env.example to .env and put your GEMINI_API_KEY inside it, then double-click this file again.
  pause
  exit /b 1
)

echo [NeuraLearn] Starting server... keep this window open while you learn.
echo [NeuraLearn] App: http://127.0.0.1:4173/app/
start "" "http://127.0.0.1:4173/app/"
node server.mjs
echo.
echo [NeuraLearn] Server stopped. You can close this window.
pause
