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

create_new_user
disable_default_user

