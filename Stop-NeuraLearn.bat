@echo off
title Stop NeuraLearn
echo [NeuraLearn] Stopping server on port 4173 (if running)...
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":4173" ^| findstr "LISTENING"') do (
  echo [NeuraLearn] Stopping process %%p
  taskkill /PID %%p /F >nul 2>nul
)
echo [NeuraLearn] Done.
pause
