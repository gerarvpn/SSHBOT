#!/bin/bash

# Este script instala SSHBOT desde GitHub de forma automática

set -e

# Mensaje de bienvenida
echo -e "\033[1;36m╔══════════════════════════════════════╗\033[0m"
echo -e "\033[1;32m        🚀 BIENVENIDO A SSHBOT         \033[0m"
echo -e "\033[1;33m          by: GERARVPN ⚙️              \033[0m"
echo -e "\033[1;36m╚══════════════════════════════════════╝\033[0m"
echo -e "\033[1;34m🔧 Preparando instalación...\033[0m"

# Actualizar repositorios e instalar dependencias necesarias
echo -e "\033[1;34m⚙️ Instalando dependencias...\033[0m"
sudo apt update -y && sudo apt install -y git curl jq dos2unix

# Clonar el repositorio de SSHBOT
echo -e "\033[1;34m📥 Clonando el repositorio SSHBOT...\033[0m"
git clone https://github.com/gerarvpn/SSHBOT.git
cd SSHBOT

# Cambiar permisos del instalador
echo -e "\033[1;34m🔧 Haciendo el script instalador ejecutable...\033[0m"
chmod +x sshbot_installer.sh

# Ejecutar el script de instalación
echo -e "\033[1;34m🚀 Ejecutando el instalador...\033[0m"
sudo ./sshbot_installer.sh

# Finalización
echo -e "\033[1;32m✅ SSHBOT instalado y configurado correctamente.\033[0m"
echo -e "\033[1;34m🚀 ¡Disfruta de SSHBOT! Usa el comando \033[1;36msshbot\033[1;34m para interactuar con el bot.\033[0m"
