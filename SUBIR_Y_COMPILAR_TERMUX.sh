#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "FORJA INFINITA ROBOTS KIDS v1.7.0 - SUBIR Y COMPILAR"

if [ ! -f project.godot ]; then
  echo "ERROR: abre Termux dentro de la carpeta que contiene project.godot."
  exit 1
fi

pkg install git gh tar -y
gh auth status

source_dir="$(pwd)"
update_dir="$(mktemp -d)"
repo_dir="$update_dir/forja-infinita-robots"

git clone https://github.com/luis323/forja-infinita-robots.git "$repo_dir"

(
  cd "$source_dir"
  tar --exclude='.git' --exclude='build' -cf - .
) | (
  cd "$repo_dir"
  tar -xf -
)

cd "$repo_dir"
git config user.name "Leonardo"
git config user.email "leonardo@termux.local"
git add -A
git commit -m "Forja Infinita Robots Kids v1.7.0 - expresiones y combate IA" || true
git push origin main

echo
echo "SUBIDA TERMINADA. LA COMPILACION DEBE APARECER AHORA:"
gh run list --repo luis323/forja-infinita-robots --limit 5
