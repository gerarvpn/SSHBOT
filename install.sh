#!/bin/bash
set -e

# Eliminar archivos de la versión anterior
echo -e "\033[1;34m🔄 Eliminando versiones anteriores de SSHBOT...\033[0m"
rm -f /usr/local/bin/sshbot /usr/local/bin/notify_telegram_login.sh
rm -f /etc/motd
sed -i '/notify_telegram_login.sh success/d' /etc/profile
sed -i '/notify_telegram_login.sh failure/d' /etc/pam.d/sshd

# Continuar con la instalación
clear
echo -e "\033[1;36m╔══════════════════════════════════════╗\033[0m"
echo -e "\033[1;32m        🚀 BIENVENIDO A SSHBOT v1.1     \033[0m"
echo -e "\033[1;33m          by: GERARVPN ⚙️              \033[0m"
echo -e "\033[1;36m╚══════════════════════════════════════╝\033[0m"
echo -e "\033[1;34m🔧 Configura tu bot de Telegram para empezar...\033[0m"
echo ""

# Validar Token
echo -e "\033[1;35m========== 📲 CONFIGURACIÓN DEL BOT ==========\033[0m"
read -p $'\033[1;33m🔐 TOKEN: \033[0m' BOT_TOKEN
while [[ -z "$BOT_TOKEN" ]]; do
  echo -e "\033[1;31m⚠️ El TOKEN no puede estar vacío.\033[0m"
  read -p $'\033[1;33m🔐 TOKEN: \033[0m' BOT_TOKEN
done
echo -e "\033[1;32m✅ TOKEN guardado correctamente.\033[0m"

# Validar ID
read -p $'\033[1;33m🆔 ID de Usuario de Telegram: \033[0m' USER_ID
while ! [[ "$USER_ID" =~ ^[0-9]+$ ]]; do
  echo -e "\033[1;31m⚠️ El ID debe ser numérico.\033[0m"
  read -p $'\033[1;33m🆔 ID de Usuario: \033[0m' USER_ID
done
echo -e "\033[1;32m✅ ID guardado correctamente.\033[0m"

# Instalar dependencias
echo -e "\033[1;34m⚙️ Instalando dependencias necesarias...\033[0m"
apt update -y && apt install -y jq curl dos2unix

# Crear script de notificación
echo -e "\033[1;34m🛠️ Creando script de notificación...\033[0m"
cat << EOF > /usr/local/bin/notify_telegram_login.sh
#!/bin/bash
set -euo pipefail
BOT_TOKEN="${BOT_TOKEN}"
USER_ID="${USER_ID}"
TYPE="\${1:-success}"
USER="\${PAM_USER:-\$(whoami)}"

if [[ "\$TYPE" == "failure" ]]; then
  IP="\${PAM_RHOST:-Desconocida}"
else
  IP=\$(who | awk '{print \$5}' | tr -d '()' | head -n1)
fi

[[ -z "\$IP" || "\$IP" =~ ^(0\\.0\\.0\\.0|127\\.0\\.0\\.1|\:\:1)\$ ]] && IP="Desconocida"

LOCATION="N/D"
if [[ "\$IP" != "Desconocida" ]]; then
  RESP=\$(curl -s --max-time 5 "http://ip-api.com/json/\$IP")
  if jq -e . <<<"\$RESP" >/dev/null; then
    COUNTRY=\$(jq -r '.country // "?"' <<<"\$RESP")
    REGION=\$(jq -r '.regionName // "?"' <<<"\$RESP")
    CITY=\$(jq -r '.city // "?"' <<<"\$RESP")
    LOCATION="\$COUNTRY, \$REGION, \$CITY"
  fi
fi

DATE=\$(date +"%Y-%m-%d %H:%M:%S")

case "\$TYPE" in
  success) ICON="✅"; TITLE="Nuevo acceso SSH exitoso" ;;
  failure) ICON="❌"; TITLE="Intento fallido de SSH" ;;
  *) ICON="❔"; TITLE="Evento SSH desconocido" ;;
esac

MESSAGE="\
\${ICON} *\${TITLE}*

• Usuario: \\\`\${USER}\\\`
• IP: \\\`\${IP}\\\`
• Ubicación: \\\`\${LOCATION}\\\`
• Fecha: \\\`\${DATE}\\\`"

curl -s -X POST "https://api.telegram.org/bot\${BOT_TOKEN}/sendMessage" \\
     -d chat_id="\${USER_ID}" -d parse_mode="Markdown" -d text="\${MESSAGE}" >/dev/null || true
EOF

chmod +x /usr/local/bin/notify_telegram_login.sh

# Configuración SSH
echo -e "\033[1;34m🔐 Configurando autenticación SSH...\033[0m"
cp /etc/pam.d/sshd /etc/pam.d/sshd.bak 2>/dev/null || true
grep -q "notify_telegram_login.sh failure" /etc/pam.d/sshd || sed -i '1i auth optional pam_exec.so seteuid /usr/local/bin/notify_telegram_login.sh failure' /etc/pam.d/sshd
grep -q "notify_telegram_login.sh success" /etc/profile || echo "/usr/local/bin/notify_telegram_login.sh success" >> /etc/profile

# Banner MOTD
echo -e "\033[1;34m📢 Agregando mensaje de bienvenida...\033[0m"
echo -e "\033[1;32m==============================================\033[0m" > /etc/motd
echo -e "\033[1;36m             SSHBOT v1.1 - ACTIVADO           \033[0m" >> /etc/motd
echo -e "\033[1;33m           by: GERARVPN - Seguridad           \033[0m" >> /etc/motd
echo -e "\033[1;32m==============================================\033[0m" >> /etc/motd
echo -e "\033[1;34m Usa el comando \033[1;36msshbot\033[1;34m para abrir el menú 📲 \033[0m" >> /etc/motd

# Crear menú interactivo
echo -e "\033[1;34m🧭 Creando menú interactivo...\033[0m"
cat << 'EOF' > /usr/local/bin/sshbot
#!/bin/bash

function header() {
  echo -e "\033[1;35m╔════════════════════════════════════════════╗\033[0m"
  echo -e "\033[1;36m             SSHBOT v1.1 - MENÚ             \033[0m"
  echo -e "\033[1;33m         Seguridad y estilo por GERARVPN     \033[0m"
  echo -e "\033[1;35m╚════════════════════════════════════════════╝\033[0m"
}

function menu() {
  clear
  header
  echo -e "\033[1;32m[1] Cambiar TOKEN del bot\033[0m"
  echo -e "\033[1;32m[2] Cambiar ID de usuario\033[0m"
  echo -e "\033[1;34m[3] Actualizar SSHBOT a la última versión\033[0m"
  echo -e "\033[1;31m[4] Desinstalar SSHBOT\033[0m"
  echo -e "\033[1;37m[0] Salir\033[0m"
  echo ""
  read -p $'\033[1;34m👉 Elige una opción: \033[0m' op
  case "$op" in
    1)
      read -p $'\033[1;33m¿Deseas cambiar el TOKEN del bot? (s/n): \033[0m' confirm_token
      if [[ "$confirm_token" =~ ^[sS]$ ]]; then
        read -p $'\033[1;36m🔐 Ingresa el nuevo TOKEN del bot: \033[0m' token
        sed -i "s|^BOT_TOKEN=.*|BOT_TOKEN='$token'|" /usr/local/bin/notify_telegram_login.sh
        echo -e "\033[1;32m✅ TOKEN actualizado correctamente.\033[0m"
      else
        echo -e "\033[1;33m✋ Cambio de TOKEN cancelado.\033[0m"
      fi
      ;;
    2)
      read -p $'\033[1;33m¿Deseas cambiar el ID de usuario? (s/n): \033[0m' confirm_id
      if [[ "$confirm_id" =~ ^[sS]$ ]]; then
        read -p $'\033[1;36m🆔 Ingresa el nuevo ID de usuario: \033[0m' id
        sed -i "s|^USER_ID=.*|USER_ID='$id'|" /usr/local/bin/notify_telegram_login.sh
        echo -e "\033[1;32m✅ ID de usuario actualizado correctamente.\033[0m"
      else
        echo -e "\033[1;33m✋ Cambio de ID cancelado.\033[0m"
      fi
      ;;
    3)
      read -p $'\033[1;31m⚠️ ¿Estás seguro de que deseas desinstalar SSHBOT? (s/n): \033[0m' confirm
      if [[ "$confirm" =~ ^[sS]$ ]]; then
        rm -f /usr/local/bin/sshbot /usr/local/bin/notify_telegram_login.sh
        sed -i '/notify_telegram_login.sh success/d' /etc/profile
        sed -i '/notify_telegram_login.sh failure/d' /etc/pam.d/sshd
        rm -f /etc/motd
        echo -e "\033[1;31m🗑️ SSHBOT desinstalado completamente.\033[0m"
        exit 0
      else
        echo -e "\033[1;33m✋ Cancelado. SSHBOT sigue instalado.\033[0m"
      fi
      ;;
    4)
      read -p $'\033[1;33m🔄 ¿Deseas actualizar SSHBOT a la última versión? (s/n): \033[0m' confirm_update
      if [[ "$confirm_update" =~ ^[sS]$ ]]; then
        echo -e "\033[1;34m⬇️ Descargando e instalando la nueva versión...\033[0m"
        bash <(curl -Ls https://raw.githubusercontent.com/gerarvpn/SSHBOT/main/sshbot_installer.sh)
        exit 0
      else
        echo -e "\033[1;33m✋ Actualización cancelada.\033[0m"
      fi
      ;;
    0) exit 0 ;;
    *) echo -e "\033[1;31m❌ Opción inválida. Intenta de nuevo.\033[0m" ;;
  esac
  read -p $'\033[1;34m🔁 Presiona ENTER para volver al menú... \033[0m' _
  menu
}

menu
EOF

chmod +x /usr/local/bin/sshbot

# Final
echo ""
echo -e "\033[1;32m✅ INSTALACIÓN COMPLETA\033[0m"
echo -e "\033[1;34m📲 Usa el comando \033[1;36msshbot\033[1;34m para abrir el menú.\033[0m"
echo -e "\033[1;32mGracias por usar SSHBOT v1.1 - by GERARVPN\033[0m"
