@echo off
setlocal
title Forja Infinita Robots Kids - Compilar y ejecutar
cd /d "%~dp0"

where godot4.exe >nul 2>nul
if %errorlevel%==0 (
  set "GODOT=godot4.exe"
) else (
  where godot.exe >nul 2>nul
  if %errorlevel%==0 (
    set "GODOT=godot.exe"
  ) else (
    echo No se encontro Godot 4.4.1 en el PATH.
    echo Abre project.godot manualmente desde Godot.
    pause
    exit /b 1
  )
)

echo Probando catalogo y montaje...
%GODOT% --headless --path "%cd%" -- --smoke-test
if errorlevel 1 (
  echo La prueba fallo. Revisa los mensajes de Godot.
  pause
  exit /b 1
)

echo Iniciando Forja Infinita Robots Kids...
%GODOT% --path "%cd%"
endlocal
