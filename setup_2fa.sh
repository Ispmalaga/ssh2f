#!/bin/bash

# Verificar si se está ejecutando como root
if [ "$EUID" -ne 0 ]; then 
  echo "Por favor, ejecute como root"
  exit 1
fi

# Actualizar el sistema
echo "Actualizando el sistema..."
apt-get update -y

# Instalar libpam-google-authenticator si no está instalado
if ! dpkg -l | grep -qw libpam-google-authenticator; then
  echo "Instalando libpam-google-authenticator..."
  apt-get install libpam-google-authenticator -y
else
  echo "libpam-google-authenticator ya está instalado"
fi

# Configurar Google Authenticator para el usuario actual
echo "Configurando Google Authenticator para el usuario actual..."
su -c "google-authenticator -t -d -f -r 3 -R 30 -w 3" - $SUDO_USER

# Configurar PAM para utilizar Google Authenticator
PAM_SSHD_FILE="/etc/pam.d/sshd"
if ! grep -q "pam_google_authenticator.so" "$PAM_SSHD_FILE"; then
  echo "Configurando PAM para utilizar Google Authenticator..."
  echo "auth required pam_google_authenticator.so" | cat - "$PAM_SSHD_FILE" > temp && mv temp "$PAM_SSHD_FILE"
else
  echo "PAM ya está configurado para utilizar Google Authenticator"
fi

# Configurar el servicio SSH
SSHD_CONFIG_FILE="/etc/ssh/sshd_config"

echo "Configurando el servicio SSH..."
sed -i 's/^#\(ChallengeResponseAuthentication\) .*/\1 yes/' "$SSHD_CONFIG_FILE"
sed -i 's/^#\(UsePAM\) .*/\1 yes/' "$SSHD_CONFIG_FILE"

if grep -q "^#AuthenticationMethods" "$SSHD_CONFIG_FILE"; then
  sed -i 's/^#\(AuthenticationMethods\) .*/\1 publickey,keyboard-interactive/' "$SSHD_CONFIG_FILE"
else
  echo "AuthenticationMethods publickey,keyboard-interactive" >> "$SSHD_CONFIG_FILE"
fi

# Reiniciar el servicio SSH para aplicar los cambios
echo "Reiniciando el servicio SSH..."
systemctl restart ssh

echo "Configuración completada. Prueba iniciar sesión con SSH para verificar la autenticación de dos factores."
