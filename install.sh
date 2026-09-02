#!/usr/bin/env bash
set -euo pipefail

echo "=== Spouštím instalaci závislostí pro AI Stack ==="

# Detekce operačního systému z /etc/os-release
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-}"
    OS_LIKE="${ID_LIKE:-}"
else
    echo "Nelze detekovat OS (/etc/os-release chybí)." >&2
    exit 1
fi

CURRENT_USER="${SUDO_USER:-$USER}"

if [[ "$OS_ID" =~ (debian|ubuntu) ]] || [[ "$OS_LIKE" =~ (debian|ubuntu) ]]; then
    echo "Detekován Debian/Ubuntu systém..."
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose-plugin make curl
    
    echo "Přidávám uživatele $CURRENT_USER do skupiny docker..."
    sudo usermod -aG docker "$CURRENT_USER"
    
elif [[ "$OS_ID" =~ (bazzite|fedora) ]] || [[ "$OS_LIKE" =~ (bazzite|fedora) ]]; then
    echo "Detekován Bazzite / Fedora / rpm-ostree systém..."
    
    # V Bazzite je Docker předinstalovaný, stačí povolit a nastartovat službu
    echo "Aktivuji a spouštím službu docker..."
    sudo systemctl enable --now docker
    
    echo "Přidávám uživatele $CURRENT_USER do skupiny docker..."
    sudo usermod -aG docker "$CURRENT_USER"
    
else
    echo "Nerozpoznaná distribuce ($OS_ID / $OS_LIKE)." >&2
    echo "Zkontroluj dostupnost Dockeru a Docker Compose ručně." >&2
    exit 1
fi

echo ""
echo "=== Instalace dokončena ==="
echo "DŮLEŽITÉ: Aby se projevilo členství ve skupině 'docker', spusť:"
echo "    newgrp docker"
echo "nebo se odhlas a znovu přihlas."