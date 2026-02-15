#!/usr/bin/env bash
#
# Internationalization (i18n) Library
# Provides multi-language support for the mail server installation
#

# ============================================================================
# LANGUAGE CONFIGURATION
# ============================================================================

# Default language (can be overridden by LANG_CODE environment variable)
: "${LANG_CODE:=en}"

# Detect system language if not explicitly set
if [[ -z "${LANG_CODE_EXPLICIT:-}" ]]; then
    case "${LANG:-}" in
        fr_*|FR_*) LANG_CODE="fr" ;;
        en_*|EN_*) LANG_CODE="en" ;;
    esac
fi

# ============================================================================
# TRANSLATION STRINGS
# ============================================================================

declare -gA I18N_STRINGS

# English translations
I18N_STRINGS["en.header.title"]="Interactive Mail Server Installation Script"
I18N_STRINGS["en.header.subtitle"]="Postfix + Dovecot + SpamAssassin + Policyd-SPF + More"

I18N_STRINGS["en.progress.checking"]="Checking for previous installation progress..."
I18N_STRINGS["en.progress.no_previous"]="No previous installation found"
I18N_STRINGS["en.progress.title"]="Previous Installation Progress"
I18N_STRINGS["en.progress.completed_steps"]="Completed steps:"
I18N_STRINGS["en.progress.interrupted"]="Previous installation was interrupted at step:"
I18N_STRINGS["en.progress.resume_question"]="Resume from where you left off?"
I18N_STRINGS["en.progress.resuming"]="Resuming from step:"
I18N_STRINGS["en.progress.fresh_question"]="Start a fresh installation?"
I18N_STRINGS["en.progress.starting_fresh"]="Starting fresh installation"
I18N_STRINGS["en.progress.cancelled"]="Installation cancelled by user"
I18N_STRINGS["en.progress.completed"]="Previous installation was completed!"

I18N_STRINGS["en.install.warning"]="The installation will now begin"
I18N_STRINGS["en.install.duration"]="This may take several minutes depending on your internet speed"
I18N_STRINGS["en.install.interruptible"]="You can safely interrupt (Ctrl+C) and resume later"
I18N_STRINGS["en.install.continue"]="Do you want to continue?"
I18N_STRINGS["en.install.completed"]="Installation completed successfully!"

I18N_STRINGS["en.step.detect_system"]="System detection"
I18N_STRINGS["en.step.collect_info"]="User configuration"
I18N_STRINGS["en.step.update_packages"]="Package cache update"
I18N_STRINGS["en.step.install_core"]="Core packages installation"
I18N_STRINGS["en.step.install_optional"]="Optional packages installation"
I18N_STRINGS["en.step.setup_database"]="Database setup"
I18N_STRINGS["en.step.configure_postfix"]="Postfix configuration"
I18N_STRINGS["en.step.configure_dovecot"]="Dovecot configuration"
I18N_STRINGS["en.step.setup_ssl"]="SSL certificate setup"
I18N_STRINGS["en.step.setup_autodiscover"]="Autodiscover setup"
I18N_STRINGS["en.step.install_webmail"]="Webmail installation"
I18N_STRINGS["en.step.finalize"]="Finalization"

I18N_STRINGS["en.skip.already_completed"]="Skipping: %s (already completed)"

I18N_STRINGS["en.prompt.press_enter"]="Press Enter to continue..."

# French translations
I18N_STRINGS["fr.header.title"]="Script d'installation interactif du serveur mail"
I18N_STRINGS["fr.header.subtitle"]="Postfix + Dovecot + SpamAssassin + Policyd-SPF + Plus"

I18N_STRINGS["fr.progress.checking"]="Vérification de la progression d'installation précédente..."
I18N_STRINGS["fr.progress.no_previous"]="Aucune installation précédente trouvée"
I18N_STRINGS["fr.progress.title"]="Progression de l'installation précédente"
I18N_STRINGS["fr.progress.completed_steps"]="Étapes complétées :"
I18N_STRINGS["fr.progress.interrupted"]="L'installation précédente a été interrompue à l'étape :"
I18N_STRINGS["fr.progress.resume_question"]="Reprendre où vous vous êtes arrêtée ?"
I18N_STRINGS["fr.progress.resuming"]="Reprise à l'étape :"
I18N_STRINGS["fr.progress.fresh_question"]="Démarrer une nouvelle installation ?"
I18N_STRINGS["fr.progress.starting_fresh"]="Démarrage d'une nouvelle installation"
I18N_STRINGS["fr.progress.cancelled"]="Installation annulée par l'utilisatrice"
I18N_STRINGS["fr.progress.completed"]="L'installation précédente était complète !"

I18N_STRINGS["fr.install.warning"]="L'installation va maintenant commencer"
I18N_STRINGS["fr.install.duration"]="Cela peut prendre plusieurs minutes selon votre connexion internet"
I18N_STRINGS["fr.install.interruptible"]="Vous pouvez interrompre (Ctrl+C) et reprendre plus tard en toute sécurité"
I18N_STRINGS["fr.install.continue"]="Voulez-vous continuer ?"
I18N_STRINGS["fr.install.completed"]="Installation terminée avec succès !"

I18N_STRINGS["fr.step.detect_system"]="Détection du système"
I18N_STRINGS["fr.step.collect_info"]="Configuration utilisatrice"
I18N_STRINGS["fr.step.update_packages"]="Mise à jour du cache des paquets"
I18N_STRINGS["fr.step.install_core"]="Installation des paquets essentiels"
I18N_STRINGS["fr.step.install_optional"]="Installation des paquets optionnels"
I18N_STRINGS["fr.step.setup_database"]="Configuration de la base de données"
I18N_STRINGS["fr.step.configure_postfix"]="Configuration de Postfix"
I18N_STRINGS["fr.step.configure_dovecot"]="Configuration de Dovecot"
I18N_STRINGS["fr.step.setup_ssl"]="Configuration des certificats SSL"
I18N_STRINGS["fr.step.setup_autodiscover"]="Configuration de l'autodécouverte"
I18N_STRINGS["fr.step.install_webmail"]="Installation du webmail"
I18N_STRINGS["fr.step.finalize"]="Finalisation"

I18N_STRINGS["fr.skip.already_completed"]="Étape ignorée : %s (déjà complétée)"

I18N_STRINGS["fr.prompt.press_enter"]="Appuyez sur Entrée pour continuer..."

# ============================================================================
# TRANSLATION FUNCTIONS
# ============================================================================

# Get translated string
# Usage: t "key" [arg1] [arg2] ...
# Example: t "skip.already_completed" "System detection"
t() {
    local key="$1"
    shift
    
    local full_key="${LANG_CODE}.${key}"
    local string="${I18N_STRINGS[$full_key]:-}"
    
    # Fallback to English if translation not found
    if [[ -z "$string" ]]; then
        full_key="en.${key}"
        string="${I18N_STRINGS[$full_key]:-$key}"
    fi
    
    # Handle printf-style formatting if arguments provided
    if [[ $# -gt 0 ]]; then
        # shellcheck disable=SC2059
        printf "$string" "$@"
    else
        echo "$string"
    fi
}

# Set language explicitly
# Usage: set_language "fr" or set_language "en"
set_language() {
    LANG_CODE="$1"
    LANG_CODE_EXPLICIT=1
}

# Get current language code
get_language() {
    echo "$LANG_CODE"
}
