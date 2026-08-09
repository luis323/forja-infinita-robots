#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "FORJA INFINITA - SUBIR Y COMPILAR"
echo "Ejecuta este archivo dentro de la carpeta del proyecto."

if [ ! -f project.godot ]; then
  echo "ERROR: project.godot no esta en esta carpeta."
  exit 1
fi

git add .
git commit -m "Actualizar Forja Infinita" || true
git push

echo "Proyecto subido. GitHub Actions comenzara la compilacion."
echo "Descarga ForjaInfinita-Android-debug cuando la tarea termine en verde."
