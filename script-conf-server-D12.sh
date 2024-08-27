#!/bin/bash

# ********************************************************************* Charger les variables d'environnement à partir du fichier .env *************************************
if [ -f .env ]; then
  export $(cat .env | sed 's/#.*//g' | xargs)
else
  echo "##################### Fichier .env introuvable !"
  exit 1
fi

# Vérifier si NEW_PASSWORD et NEW_USER sont définis
if [ -z "$NEW_PASSWORD" ]; then
  echo "#################### NEW_PASSWORD n'est pas défini dans le fichier .env !"
  exit 1
fi

if [ -z "$NEW_USER" ]; then
  echo "################### NEW_USER n'est pas défini dans le fichier .env !"
  exit 1
fi

# Fonction pour créer un nouvel utilisateur
create_new_user() {
    adduser $NEW_USER
    usermod -aG sudo $NEW_USER
    echo "Nouvel utilisateur $NEW_USER créé et ajouté au groupe sudo"
}

# Fonction pour désactiver l'utilisateur par défaut
disable_default_user() {
    passwd -l $DEFAULT_USER
    echo "Utilisateur par défaut $DEFAULT_USER désactivé"
}

# Fonction pour modifier le port SSH
change_ssh_port() {
    if [ -z "$NEW_PORT_SSH" ]; then
        echo "La variable NEW_PORT_SSH n'est pas définie dans le fichier .env"
        return 1
    fi

    # Sauvegarde du fichier de configuration SSH
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    # Modification du port SSH
    sed -i "s/^#Port 22/Port $NEW_PORT_SSH/" /etc/ssh/sshd_config

    # Redémarrage du service SSH pour appliquer les changements
    systemctl restart sshd

    echo "Le port SSH a été changé pour $NEW_PORT_SSH"
}

# Fonction pour installer rsync
install_rsync() {
    echo "Installation de rsync..."
    apt update && apt upgrade -y
    apt install rsync -y
    if [ $? -eq 0 ]; then
        echo "rsync a été installé avec succès."
        # Vérification de la version installée
        rsync --version | head -n 1
    else
        echo "Erreur lors de l'installation de rsync."
        return 1
    fi
}

# Fonction pour installer et configurer Fail2ban
install_configure_fail2ban() {
    echo "Installation de Fail2ban..."
    apt update && apt upgrade -y
    apt install fail2ban -y

    if [ $? -eq 0 ]; then
        echo "Fail2ban a été installé avec succès."

        # Configuration de Fail2ban pour SSH
        cat << EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = $NEW_PORT_SSH
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 900
findtime = 600
EOF

        # Redémarrage du service Fail2ban
        systemctl restart fail2ban

        echo "Fail2ban a été configuré pour surveiller SSH sur le port $NEW_PORT_SSH."
        echo "Les intrus seront bannis après 3 tentatives échouées en 10 minutes pour une durée de 15 minutes."
    else
        echo "Erreur lors de l'installation de Fail2ban."
        return 1
    fi
}

# Fonction pour installer et configurer cron-apt
install_configure_cron_apt() {
    echo "Installation de cron-apt..."
    apt update
    apt install cron-apt -y

    if [ $? -eq 0 ]; then
        echo "cron-apt a été installé avec succès."

        # Configuration de cron-apt pour les mises à jour de sécurité
        cat << EOF > /etc/cron-apt/config
# Configuration de cron-apt
APTCOMMAND=/usr/bin/apt-get
MAILTO="root"
MAILON="upgrade"
OPTIONS="-o Acquire::http::Dl-Limit=1000 -o Dir::Etc::SourceList=/etc/apt/sources.list.d/security.list"
EOF

        # Création du fichier sources.list pour les mises à jour de sécurité
        echo "deb http://security.debian.org/ $(lsb_release -cs)/updates main" > /etc/apt/sources.list.d/security.list

        # Configuration de l'action pour télécharger et installer les mises à jour de sécurité
        echo 'upgrade -y -o APT::Get::Show-Upgraded=true' > /etc/cron-apt/action.d/5-security-upgrade

        echo "cron-apt a été configuré pour gérer uniquement les mises à jour de sécurité."
    else
        echo "Erreur lors de l'installation de cron-apt."
        return 1
    fi
}


# Exécution des fonctions
change_ssh_port
create_new_user
disable_default_user
install_rsync
install_configure_fail2ban
install_configure_cron_apt
