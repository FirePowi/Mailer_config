# Architecture Modulaire du Script d'Installation Mail Server

## Vue d'ensemble

Le script d'installation du serveur de messagerie a été refactorisé en une architecture modulaire pour améliorer la maintenabilité, la lisibilité et la facilité de développement.

## Structure des fichiers

```
.specify/scripts/bash/
├── install.sh                  # Script principal (orchestrateur)
├── install-mail-server.sh      # ⚠️ OBSOLÈTE - Ne plus utiliser
├── lib/                        # Librairies modulaires
│   ├── config.sh              # Variables de configuration globales
│   ├── ui.sh                  # Fonctions d'interface utilisateur (couleurs, logs)
│   ├── system.sh              # Détection du système (distribution, packages)
│   ├── packages.sh            # Gestion des packages (installation, mapping)
│   ├── dns.sh                 # Configuration et tests DNS
│   ├── input.sh               # Collection des entrées utilisateur
│   ├── progress.sh            # Suivi de progression (reprise après interruption)
│   ├── database.sh            # Configuration de la base de données MySQL/MariaDB
│   ├── postfix.sh             # Configuration de Postfix (SMTP)
│   ├── dovecot.sh             # Configuration de Dovecot (IMAP/POP3)
│   ├── ssl.sh                 # Gestion des certificats SSL/TLS (Let's Encrypt)
│   ├── autodiscover.sh        # Autoconfiguration clients email (Thunderbird, Outlook)
│   ├── webmail.sh             # Installation webmail (SnappyMail, Roundcube, SOGo)
│   └── services.sh            # Gestion des services système
└── Documentation/
    └── ...
```

## Dépendances entre modules

```
install.sh
    ├── config.sh            (variables globales)
    ├── ui.sh                (fonctions d'affichage)
    ├── system.sh            (détection système)
    │   └── ui.sh
    ├── packages.sh          (gestion packages)
    │   ├── ui.sh
    │   └── system.sh
    ├── dns.sh               (configuration DNS)
    │   └── ui.sh
    ├── input.sh             (entrées utilisateur)
    │   ├── ui.sh
    │   └── config.sh
    ├── progress.sh          (suivi progression)
    │   └── config.sh
    ├── database.sh          (setup base de données)
    │   ├── ui.sh
    │   └── config.sh
    ├── postfix.sh           (configuration Postfix)
    │   ├── ui.sh
    │   └── config.sh
    ├── dovecot.sh           (configuration Dovecot)
    │   ├── ui.sh
    │   └── config.sh
    ├── ssl.sh               (certificats SSL)
    │   ├── ui.sh
    │   ├── packages.sh
    │   └── config.sh
    ├── autodiscover.sh      (autoconfiguration)
    │   ├── ui.sh
    │   └── config.sh
    ├── webmail.sh           (installation webmail)
    │   ├── ui.sh
    │   ├── packages.sh
    │   └── config.sh
    └── services.sh          (gestion services)
        ├── ui.sh
        └── config.sh
```

## Description des modules

### Module de base

#### **config.sh**
Définit toutes les variables de configuration globales utilisées par les autres modules :
- Variables système (DISTRO, PACKAGE_MANAGER, etc.)
- Choix d'installation (DOMAINS, HOSTNAME, ADMIN_EMAIL, etc.)
- Chemins des répertoires (POSTFIX_DIR, DOVECOT_DIR, etc.)
- Mots de passe générés

#### **ui.sh**
Fonctions d'interface utilisateur :
- `print_header()` - En-tête du script
- `print_section()` - Séparateur de section
- `log_info()`, `log_success()`, `log_warning()`, `log_error()` - Logs colorés
- `ask_question()` - Poser une question avec valeur par défaut
- `ask_yes_no()` - Question oui/non
- `pause_for_user()` - Pause pour l'utilisateur

### Modules de détection et gestion

#### **system.sh**
Détection du système d'exploitation :
- `detect_distribution()` - Détecte la distribution Linux
- `check_root()` - Vérifie les privilèges root
- `get_server_ip()` - Obtient l'IP publique du serveur

#### **packages.sh**
Gestion des packages :
- `get_package_name()` - Mapping des noms de packages selon la distribution
- `update_package_cache()` - Mise à jour du cache des packages
- `install_package()` - Installation d'un package
- `check_package_available()` - Vérification de disponibilité
- `install_core_packages()` - Installation des packages obligatoires
- `install_optional_packages()` - Installation des packages optionnels
- `detect_or_choose_webserver()` - Détection/sélection du serveur web

### Modules de configuration

#### **input.sh**
Collection des informations de configuration :
- `collect_basic_info()` - Domaines, hostname, admin email
- `collect_component_choices()` - Sélection des composants à installer
- `generate_passwords()` - Génération des mots de passe sécurisés

#### **dns.sh**
Gestion DNS :
- `test_dns_records()` - Test des enregistrements DNS existants
- `interactive_dns_setup()` - Configuration interactive (demande si DNS configuré)
- `show_dns_configuration()` - Guide détaillé de configuration DNS

#### **progress.sh**
Suivi de progression (reprise après interruption) :
- `save_progress()` - Sauvegarde l'état d'une étape
- `get_progress()` - Récupère l'état sauvegardé
- `should_skip_step()` - Détermine si une étape doit être sautée
- `clear_progress()` - Nettoie les fichiers de progression
- `prompt_resume()` - Propose de reprendre une installation interrompue

### Modules d'installation

#### **database.sh**
Configuration de la base de données :
- `setup_database()` - Création de la base `mail`, tables et utilisateur
  - Table `mail_domains` - Domaines virtuels
  - Table `mail_users` - Comptes utilisateurs
  - Table `mail_aliases` - Aliases et forwards
  - Table `mail_audit_log` - Journal d'audit

#### **postfix.sh**
Configuration de Postfix (serveur SMTP) :
- `configure_postfix()` - Génération de main.cf et master.cf
- `create_mysql_configs()` - Fichiers de requêtes MySQL :
  - `mysql-virtual-domains.cf`
  - `mysql-virtual-mailbox-maps.cf`
  - `mysql-virtual-alias-maps.cf`
- `configure_postfix_master()` - Configuration des services Postfix

**Fonctionnalités configurées :**
- SMTP, Submission (587), SMTPS (465)
- TLS/SSL avec chiffrement fort
- Authentification SASL via Dovecot
- Domaines virtuels via MySQL
- Support SPF et DKIM (optionnel)
- Restrictions anti-spam et anti-relay

#### **dovecot.sh**
Configuration de Dovecot (serveur IMAP/POP3) :
- `configure_dovecot()` - Génération de dovecot.conf
- `create_dovecot_sql_config()` - Configuration SQL pour authentification

**Fonctionnalités configurées :**
- IMAP, IMAPS (993), POP3, POP3S (995)
- TLS/SSL avec chiffrement fort
- Format Maildir
- Dossiers spéciaux (Sent, Trash, Drafts, Spam, Archives)
- Authentification MySQL
- Support Sieve (filtres email)
- Quota (optionnel)

#### **ssl.sh**
Gestion des certificats SSL/TLS :
- `setup_ssl_certificates()` - Obtention et configuration Let's Encrypt
  - Certificat pour le hostname mail
  - Certificat pour le domaine webmail
  - Configuration du renouvellement automatique
  - Mise à jour des configurations Postfix et Dovecot

#### **autodiscover.sh**
Autoconfiguration des clients email :
- `setup_autodiscover()` - Configuration principale
- `create_autoconfig_xml()` - Mozilla Thunderbird (autoconfig)
- `create_autodiscover_xml()` - Microsoft Outlook (autodiscover)
- `create_autodiscover_nginx()` - Configuration Nginx
- `create_autodiscover_apache()` - Configuration Apache

**Clients supportés :**
- Mozilla Thunderbird
- Microsoft Outlook
- Apple Mail
- Autres clients modernes

#### **webmail.sh**
Installation et configuration webmail :
- `install_webmail()` - Installation principale
- `install_snappymail()` - SnappyMail (recommandé)
- `install_roundcube()` - Roundcube
- `install_sogo()` - SOGo (groupware complet)
- Fonctions de configuration Nginx/Apache pour chaque webmail

#### **services.sh**
Gestion des services système :
- `start_and_enable_services()` - Démarrage et activation automatique de tous les services
- `show_final_instructions()` - Affichage des instructions finales :
  - Résumé de la configuration
  - Mots de passe sauvegardés
  - URLs des interfaces web
  - Instructions DNS
  - Commandes de test
  - Guide de dépannage

## Flux d'exécution

Le script principal `install.sh` orchestre l'installation en appelant les fonctions des modules dans l'ordre suivant :

1. **Initialisation**
   - Chargement de tous les modules
   - Vérification des privilèges root

2. **Détection système**
   - `run_detect_system()` → `detect_distribution()`

3. **Collection d'informations**
   - `run_collect_info()` → `collect_basic_info()`, `collect_component_choices()`, `generate_passwords()`

4. **Configuration DNS**
   - `test_dns_records()`
   - `interactive_dns_setup()`
   - `show_dns_configuration()`

5. **Installation**
   - `run_update_packages()` → `update_package_cache()`
   - `run_install_core()` → `install_core_packages()`
   - `run_install_optional()` → `install_optional_packages()`

6. **Configuration des services**
   - `run_setup_database()` → `setup_database()`
   - `run_configure_postfix()` → `configure_postfix()`
   - `run_configure_dovecot()` → `configure_dovecot()`
   - `run_setup_ssl()` → `setup_ssl_certificates()`
   - `run_setup_autodiscover()` → `setup_autodiscover()`
   - `run_install_webmail()` → `install_webmail()`

7. **Finalisation**
   - `run_finalize()` → `start_and_enable_services()`, `show_final_instructions()`

Chaque étape peut être reprise individuellement grâce au système de progression.

## Avantages de l'architecture modulaire

### ✅ Maintenabilité
- Code organisé par fonctionnalité
- Facilité de localisation des bugs
- Modifications isolées (pas d'effet de bord)

### ✅ Lisibilité
- Fichiers plus courts et ciblés (~200-800 lignes vs 3700 lignes)
- Séparation claire des responsabilités
- Noms de fichiers explicites

### ✅ Testabilité
- Chaque module peut être testé indépendamment
- Facilite le débogage

### ✅ Extensibilité
- Ajout facile de nouveaux modules
- Modification d'un module sans toucher aux autres
- Réutilisabilité du code

### ✅ Collaboration
- Plusieurs développeurs peuvent travailler sur des modules différents
- Conflits Git réduits
- Revue de code plus facile

## Migration depuis l'ancienne architecture

### Ancien système (install-mail-server.sh)
```bash
# Fichier monolithique de 3711 lignes
# Toutes les fonctions dans un seul fichier
# Difficile à maintenir et à étendre
```

### Nouveau système (install.sh + lib/)
```bash
# Script principal léger (223 lignes)
# 14 modules spécialisés (~100-800 lignes chacun)
# Architecture claire et maintenable
```

## Variables globales requises

Les modules s'appuient sur des variables définies dans `config.sh` :

### Variables système
- `DISTRO` - Distribution détectée (ubuntu, debian, centos, etc.)
- `DISTRO_FAMILY` - Famille (debian, redhat, arch, suse)
- `PACKAGE_MANAGER` - Gestionnaire de packages (apt-get, yum, dnf, pacman)
- `SERVICE_MANAGER` - Gestionnaire de services (systemctl)
- `SERVER_IP` - Adresse IP publique du serveur

### Variables de configuration
- `DOMAINS[]` - Tableau des domaines configurés
- `PRIMARY_DOMAIN` - Domaine principal
- `HOSTNAME` - FQDN du serveur mail
- `ADMIN_EMAIL` - Email administrateur

### Choix d'installation
- `ENABLE_SPAMASSASSIN` - Activer SpamAssassin (true/false)
- `ENABLE_CLAMAV` - Activer ClamAV (true/false)
- `ENABLE_POLICYD_SPF` - Activer Policyd-SPF (true/false)
- `ENABLE_POSTFIXADMIN` - Activer PostfixAdmin (true/false)
- `ENABLE_RSPAMD` - Activer Rspamd (true/false)
- `ENABLE_DKIM` - Activer OpenDKIM (true/false)
- `WEBMAIL_CHOICE` - Choix webmail (snappymail, roundcube, sogo, none)
- `WEB_SERVER` - Serveur web (nginx, apache)

### Mots de passe
- `DB_PASSWORD` - Mot de passe base de données
- `POSTFIXADMIN_PASSWORD` - Mot de passe PostfixAdmin
- `WEBMAIL_PASSWORD` - Mot de passe webmail (si applicable)

### Chemins
- `POSTFIX_DIR` - /etc/postfix
- `DOVECOT_DIR` - /etc/dovecot
- `VMAIL_DIR` - /var/vmail
- `CERTBOT_DIR` - /etc/letsencrypt

### UIDs/GIDs
- `VMAIL_UID` - UID de l'utilisateur vmail (5000)
- `VMAIL_GID` - GID du groupe vmail (5000)

## Développement futur

Pour ajouter un nouveau module :

1. Créer le fichier `lib/nouveau_module.sh`
2. Ajouter l'en-tête bash et la description
3. Sourcer les dépendances nécessaires (ui.sh, config.sh, etc.)
4. Implémenter les fonctions
5. Ajouter le `source` dans `install.sh`
6. Créer la fonction wrapper `run_nouveau_module()` dans `install.sh`
7. Ajouter l'étape dans le flux d'exécution de `main()`
8. Mettre à jour cette documentation

## Support et contribution

Pour toute question ou contribution :
- Consultez d'abord les fichiers de documentation dans `Documentation/`
- Lisez les commentaires détaillés dans chaque module
- Les fichiers de configuration générés contiennent des explications complètes

---

**Date de création :** 2026-02-14  
**Version :** 2.0 (Architecture modulaire)  
**Auteur :** Refactorisation automatique depuis install-mail-server.sh
