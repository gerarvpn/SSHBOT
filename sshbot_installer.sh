#!/bin/bash
set -euo pipefail

# Función para cuenta regresiva
countdown() {
  local seconds=$1 prefix=${2:-"Reiniciando"}
  echo -e "\033[1;34m🔁 ${prefix} en:\033[0m"
  while [ $seconds -gt 0 ]; do
    echo -ne "\r\033[0;37m   $seconds...\033[0m"
    sleep 1
    ((seconds--))
  done
  echo ""
}

# Función para detectar el gestor de paquetes
detect_package_manager() {
  if command -v apt >/dev/null 2>&1; then
    echo "apt"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt-get"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  else
    echo "unknown"
  fi
}

# Función para instalar dependencias
install_dependencies() {
  local pkg_manager
  pkg_manager=$(detect_package_manager)
  echo -e "\033[1;34m⚙️ Instalando dependencias necesarias...\033[0m"
  case $pkg_manager in
    apt|apt-get)
      sudo apt update -y
      sudo apt install -y jq curl dos2unix openssh-server
      ;;
    yum)
      sudo yum install -y epel-release
      sudo yum install -y jq curl dos2unix openssh-server
      ;;
    dnf)
      sudo dnf install -y epel-release
      sudo dnf install -y jq curl dos2unix openssh-server
      ;;
    zypper)
      sudo zypper install -y jq curl dos2unix openssh-server
      ;;
    *)
      echo -e "\033[1;31m❌ No se pudo detectar el gestor de paquetes. Instala jq, curl y dos2unix manualmente.\033[0m"
      exit 1
      ;;
  esac
}

# Función para detectar el servicio SSH
detect_ssh_service() {
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-units --type=service | grep -qE 'ssh\.service$'; then
      echo "ssh"
    elif systemctl list-units --type=service | grep -qE 'sshd\.service$'; then
      echo "sshd"
    else
      echo "unknown"
    fi
  else
    echo "sysvinit"
  fi
}

# Función para reiniciar el servicio SSH
restart_ssh_service() {
  local service_type
  service_type=$(detect_ssh_service)
  case $service_type in
    ssh)
      sudo systemctl restart ssh
      ;;
    sshd)
      sudo systemctl restart sshd
      ;;
    sysvinit)
      sudo service ssh restart
      ;;
    *)
      echo -e "\033[1;31m❌ No se pudo detectar el servicio SSH. Por favor, reinicia el servicio manualmente.\033[0m"
      exit 1
      ;;
  esac
}

# Limpieza de versiones anteriores
echo -e "\033[1;34m🔄 Eliminando versiones anteriores de SSHBOT...\033[0m"
rm -f /usr/local/bin/sshbot /usr/local/bin/notify_telegram_login.sh
rm -f /etc/motd
sed -i '/notify_telegram_login.sh success/d' /etc/profile || true
sed -i '/notify_telegram_login.sh failure/d' /etc/pam.d/sshd || true

# Instalar dependencias
install_dependencies

# ————————————————————————————————
# MENSAJE DE BIENVENIDA (antes de pedir TOKEN e ID)
# ————————————————————————————————
clear
echo -e "\033[1;34m╔══════════════════════════════════════╗\033[0m"
echo -e "\033[0;37m        🚀 BIENVENIDO A SSHBOT v1.2    \033[0m"
echo -e "\033[0;37m          by: GERARVPN ⚙️              \033[0m"
echo -e "\033[1;34m╚══════════════════════════════════════╝\033[0m"
echo ""

# Configuración del Bot de Telegram
echo -e "\033[1;34m========== 📲 CONFIGURACIÓN DEL BOT ==========\033[0m"
read -rp $'\033[0;37m🔐 TOKEN: \033[0m' BOT_TOKEN
while [[ -z "$BOT_TOKEN" ]]; do
  echo -e "\033[1;31m⚠️ El TOKEN no puede estar vacío.\033[0m"
  read -rp $'\033[0;37m🔐 TOKEN: \033[0m' BOT_TOKEN
done
echo -e "\033[0;37m✅ TOKEN guardado correctamente.\033[0m"

read -rp $'\033[0;37m🆔 ID de Usuario de Telegram (para alertas): \033[0m' USER_ID
while ! [[ "$USER_ID" =~ ^[0-9]+$ ]]; do
  echo -e "\033[1;31m⚠️ El ID debe ser numérico.\033[0m"
  read -rp $'\033[0;37m🆔 ID de Usuario: \033[0m' USER_ID
done
echo -e "\033[0;37m✅ ID guardado correctamente.\033[0m"

# Detectar puerto SSH actual
echo -e "\033[1;34m🔐 Comprobando puerto SSH actual...\033[0m"
CURRENT_PORT=$(grep -Ei '^[[:space:]]*#?[[:space:]]*Port[[:space:]]+' /etc/ssh/sshd_config | awk '{print $2}' | tail -n1 || true)
if [[ -z "$CURRENT_PORT" ]]; then
  CURRENT_PORT=22
fi
SSH_PORT="$CURRENT_PORT"

# Advertencia si el puerto SSH es 22
if [[ "$SSH_PORT" == "22" ]]; then
  echo -e "\033[1;31m⚠️  ¡Atención! Estás usando el puerto SSH 22.\033[0m"
  echo -e "\033[1;31mEl puerto 22 es el predeterminado y primer objetivo de ataques automatizados.\033[0m"
  echo -e "\033[1;31mRecomiendo cambiarlo a otro (ej. 2222, 2022, 50022) para mayor seguridad.\033[0m"
  echo ""
  read -rp $'\033[0;37m¿Deseas cambiar el puerto SSH ahora? (s/n): \033[0m' change_port
  if [[ "$change_port" =~ ^[sS]$ ]]; then
    while true; do
      read -rp $'\033[0;37m🔢 Ingresa el nuevo puerto SSH (1025–65535): \033[0m' new_port
      if [[ "$new_port" =~ ^[0-9]+$ ]] && (( new_port>=1025 && new_port<=65535 )); then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true
        sed -i "s/^[[:space:]]*#\?[[:space:]]*Port.*$/Port $new_port/" /etc/ssh/sshd_config
        SSH_PORT="$new_port"
        echo -e "\033[0;37m✅ Puerto SSH cambiado a $SSH_PORT correctamente en config.\033[0m"
        restart_ssh_service
        break
      else
        echo -e "\033[1;31m❌ Puerto inválido. Debe ser un número entre 1025 y 65535.\033[0m"
      fi
    done
  fi
fi

# Crear script de notificación con marcadores de posición
echo -e "\033[1;34m🛠️ Creando script de notificación...\033[0m"
cat << 'EOF' > /usr/local/bin/notify_telegram_login.sh
#!/bin/bash
set -euo pipefail

# Rutas absolutas
CURL=$(command -v curl)
JQ=$(command -v jq)

BOT_TOKEN="PLACEHOLDER_BOT_TOKEN"
USER_ID="PLACEHOLDER_USER_ID"
TYPE="${1:-success}"
USER="${PAM_USER:-$(whoami)}"

# Obtener IP
IP="Desconocida"
if [[ "$TYPE" == "failure" ]]; then
  IP="${PAM_RHOST:-Desconocida}"
else
  RAW_IP=$(who | awk '{print $5}' | tr -d '()' | head -n1)
  if [[ -n "$RAW_IP" && ! "$RAW_IP" =~ ^(0\.0\.0\.0|127\.0\.0\.1|::1)$ ]]; then
    IP="$RAW_IP"
  fi
fi

# Geolocalización
LOCATION="Desconocida"
if [[ "$IP" != "Desconocida" ]]; then
  RESP=$($CURL -s --max-time 5 "http://ip-api.com/json/$IP" || echo "{}")
  if echo "$RESP" | $JQ -e '.status=="success"' >/dev/null 2>&1; then
    COUNTRY=$($JQ -r '.country' <<<"$RESP")
    REGION=$($JQ -r '.regionName' <<<"$RESP")
    CITY=$($JQ -r '.city' <<<"$RESP")
    LOCATION="${COUNTRY}, ${REGION}, ${CITY}"
  fi
fi

DATE=$($CURL -s http://worldtimeapi.org/api/ip | $JQ -r '.datetime' 2>/dev/null || date +"%A %d/%m/%Y ⏰ %H:%M:%S")

case "$TYPE" in
  success) ICON="✅"; TITLE="Nuevo acceso SSH exitoso" ;;
  failure) ICON="❌"; TITLE="Intento fallido de SSH" ;;
  *) ICON="❔"; TITLE="Evento SSH desconocido" ;;
esac

MESSAGE="${ICON} *${TITLE}*
• Usuario: \`${USER}\`
• IP: \`${IP}\`
• Ubicación: \`${LOCATION}\`
• Fecha: ${DATE}"

# Reintentos
for i in {1..3}; do
  if $CURL -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
       -d chat_id="${USER_ID}" \
       -d parse_mode="Markdown" \
       -d text="${MESSAGE}" >/dev/null 2>&1; then
    exit 0
  else
    echo "Intento $i fallido, reintentando..."
    sleep 2
  fi
done

echo "Error: No se pudo enviar la notificación después de 3 intentos" >&2
exit 1
EOF

# Sustituir marcadores
sed -i "s@PLACEHOLDER_BOT_TOKEN@${BOT_TOKEN}@g" /usr/local/bin/notify_telegram_login.sh
sed -i "s@PLACEHOLDER_USER_ID@${USER_ID}@g" /usr/local/bin/notify_telegram_login.sh
chmod +x /usr/local/bin/notify_telegram_login.sh

# Configurar PAM y profile
echo -e "\033[1;34m🔐 Configurando autenticación SSH...\033[0m"
cp /etc/pam.d/sshd /etc/pam.d/sshd.bak 2>/dev/null || true
grep -q "notify_telegram_login.sh failure" /etc/pam.d/sshd || \
  sed -i '1i auth optional pam_exec.so seteuid /usr/local/bin/notify_telegram_login.sh failure' /etc/pam.d/sshd
grep -q "notify_telegram_login.sh success" /etc/profile || \
  echo "/usr/local/bin/notify_telegram_login.sh success" >> /etc/profile

# Banner personalizado MOTD
echo -e "\033[1;34m📢 Agregando mensaje de bienvenida (MOTD)...\033[0m"
{
  echo -e "\033[1;34m==============================================\033[0m"
  echo -e "\033[0;37m      SSHBOT v1.2 - ACTIVADO (SSH port: \033[1;34m${SSH_PORT}\033[0;37m)  \033[0m"
  echo -e "\033[0;37m        by: GERARVPN - Seguridad           \033[0m"
  echo -e "\033[1;34m==============================================\033[0m"
  echo -e "\033[1;34mUsa el comando \033[0;37msshbot\033[1;34m para abrir el menú 📲\033[0m"
} > /etc/motd

# Crear menú interactivo
echo -e "\033[1;34m🧭 Creando menú interactivo (/usr/local/bin/sshbot)... \033[0m"
cat << 'EOF' > /usr/local/bin/sshbot
#!/bin/bash
set -euo pipefail

# Funciones reutilizables
countdown() {
  local seconds=$1 prefix=${2:-"Reiniciando"}
  echo -e "\033[1;34m🔁 ${prefix} en:\033[0m"
  while [ $seconds -gt 0 ]; do
    echo -ne "\r\033[0;37m   $seconds...\033[0m"
    sleep 1
    ((seconds--))
  done
  echo ""
}

header() {
  echo -e "\033[1;34m╔════════════════════════════════════════════╗\033[0m"
  echo -e "\033[0;37m             SSHBOT v1.2 - MENÚ             \033[0m"
  echo -e "\033[0;37m         Seguridad y estilo por GERARVPN     \033[0m"
  echo -e "\033[1;34m╚════════════════════════════════════════════╝\033[0m"
}

# Detectar servicio y reiniciar
detect_ssh_service() {
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-units --type=service | grep -qE 'ssh\.service$'; then
      echo "ssh"
    elif systemctl list-units --type=service | grep -qE 'sshd\.service$'; then
      echo "sshd"
    else
      echo "unknown"
    fi
  else
    echo "sysvinit"
  fi
}
restart_ssh_service() {
  local svc
  svc=$(detect_ssh_service)
  case $svc in
    ssh)    sudo systemctl restart ssh   ;;
    sshd)   sudo systemctl.restart sshd  ;;
    sysvinit) sudo service ssh restart  ;;
    *) echo -e "\033[1;31m❌ No se pudo reiniciar SSH automáticamente.\033[0m"; return 1 ;;
  esac
}

# Opción 1: Cambiar TOKEN
change_token() {
  read -rp $'\033[0;37m¿Cambiar TOKEN? (s/n): \033[0m' yn
  if [[ "$yn" =~ ^[sS]$ ]]; then
    read -rp $'\033[0;37m🔐 Nuevo TOKEN: \033[0m' newt
    sed -i "s|^BOT_TOKEN=.*|BOT_TOKEN=\"${newt}\"|" /usr/local/bin/notify_telegram_login.sh
    echo -e "\033[0;37m✅ TOKEN actualizado.\033[0m"
  else
    echo -e "\033[0;37m✋ Cambio de TOKEN cancelado.\033[0m"
  fi
}

# Opción 2: Cambiar ID de usuario
change_userid() {
  read -rp $'\033[0;37m¿Cambiar ID de usuario? (s/n): \033[0m' yn
  if [[ "$yn" =~ ^[sS]$ ]]; then
    read -rp $'\033[0;37m🆔 Nuevo ID: \033[0m' newu
    sed -i "s|^USER_ID=.*|USER_ID=\"${newu}\"|" /usr/local/bin/notify_telegram_login.sh
    echo -e "\033[0;37m✅ ID de usuario actualizado.\033[0m"
  else
    echo -e "\033[0;37m✋ Cambio de ID cancelado.\033[0m"
  fi
}

# Opción 3: Desinstalar SSHBOT
uninstall_ssbot() {
  read -rp $'\033[1;31m¿Desinstalar SSHBOT? (s/n): \033[0m' yn
  if [[ "$yn" =~ ^[sS]$ ]]; then
    sudo rm -f /usr/local/bin/sshbot /usr/local/bin/notify_telegram_login.sh
    sudo rm -f /etc/motd
    sudo sed -i '/notify_telegram_login.sh success/d' /etc/profile
    sudo sed -i '/notify_telegram_login.sh failure/d' /etc/pam.d/sshd
    echo -e "\033[0;37m🗑️ SSHBOT desinstalado completamente.\033[0m"
    exit 0
  else
    echo -e "\033[0;37m✋ Desinstalación cancelada.\033[0m"
  fi
}

# Opción 4: Cambiar puerto SSH
change_port_menu() {
  read -rp $'\033[0;37m¿Cambiar puerto SSH actual? (s/n): \033[0m' yn
  if [[ "$yn" =~ ^[sS]$ ]]; then
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    read -rp $'\033[0;37m🔢 Ingresa el nuevo puerto SSH (1025–65535): \033[0m' newp
    if [[ "$newp" =~ ^[0-9]+$ ]] && (( newp>=1025 && newp<=65535 )); then
      sudo sed -i "s/^[[:space:]]*#\?[[:space:]]*Port.*$/Port $newp/" /etc/ssh/sshd_config
      echo -e "\033[0;37m✅ Puerto SSH cambiado a $newp correctamente en config.\033[0m"
      echo ""
      read -rp $'\033[0;37m⚠️ Reiniciar ahora? (s/n): \033[0m' reboot_choice
      if [[ "$reboot_choice" =~ ^[sS]$ ]]; then
        echo -e "\033[1;34m🔄 Reiniciando ahora...\033[0m"
        sudo reboot
      else
        echo -e "\033[0;37m✋ Reinicio cancelado. Recuerda reiniciar más tarde.\033[0m"
      fi
    else
      echo -e "\033[1;31m❌ Puerto inválido. Debe ser un número entre 1025 y 65535.\033[0m"
    fi
  else
    echo -e "\033[0;37m✋ No se cambió el puerto SSH.\033[0m"
  fi
}

# Opción 5: Actualizar SSHBOT
update_ssbot() {
  read -rp $'\033[0;37m¿Descargar e instalar la última versión? (s/n): \033[0m' yn
  if [[ "$yn" =~ ^[sS]$ ]]; then
    echo -e "\033[1;34m🔄 Actualizando SSHBOT...\033[0m"
    bash <(curl -Ls https://raw.githubusercontent.com/gerarvpn/SSHBOT/main/sshbot_installer.sh)
    echo -e "\033[0;37m✅ SSHBOT actualizado.\033[0m"
  else
    echo -e "\033[0;37m✋ Actualización cancelada.\033[0m"
  fi
}

# … (todo igual hasta el bucle del menú)

while true; do
  clear; header
  echo -e "\033[0;37m[1] Cambiar TOKEN del bot\033[0m"
  echo -e "\033[0;37m[2] Cambiar ID de usuario\033[0m"
  echo -e "\033[0;37m[3] Cambiar puerto SSH\033[0m"
  echo -e "\033[0;37m[4] Actualizar SSHBOT\033[0m"
  echo -e "\033[1;31m[5] Desinstalar SSHBOT\033[0m"
  echo -e "\033[0;37m[0] Salir 👋\033[0m"
  echo ""
  read -r -p $'\033[0;37m👉 Elige una opción: \033[0m' opt
  case "${opt//[[:space:]]/}" in
    1) change_token ;;
    2) change_userid ;;
    3) change_port_menu ;;
    4) update_ssbot ;;
    5) uninstall_ssbot ;;
    0) echo -e "\033[0;37m👋 ¡Hasta luego!\033[0m"; exit 0 ;;
    *) echo -e "\033[1;31m❌ Opción inválida. Intenta de nuevo.\033[0m"; sleep 1 ;;
  esac
  read -rp $'\nPresiona ENTER para continuar...\n' _
done
EOF

# Asegurar permisos y formato correcto
dos2unix /usr/local/bin/sshbot >/dev/null 2>&1 || true
chmod +x /usr/local/bin/sshbot

echo ""
echo -e "\033[0;37m✅ INSTALACIÓN COMPLETA\033[0m"
echo -e "\033[1;34m🔑 SSH configurado en el puerto: \033[0;37m$SSH_PORT\033[0m"
echo -e "\033[1;34m📲 Usa \033[0;37msshbot\033[1;34m para abrir el menú y gestionar tu VPS.\033[0m"