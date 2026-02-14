#!/usr/bin/env bash
#
# Script de débogage pour l'installation
# Affiche les informations détaillées sur l'exécution
#
# Usage: sudo ./debug-install.sh
#

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        Script de Débogage - Installation Mail Server         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Vérifier si root
if [[ $EUID -ne 0 ]]; then
    echo "❌ ERREUR: Ce script doit être exécuté en tant que root"
    echo "Utilisez: sudo $0"
    exit 1
fi

echo "✓ Exécution en tant que root"
echo ""

# Vérifier le fichier de progress
PROGRESS_FILE="/var/tmp/mail-server-install-progress.state"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 État du fichier de progression"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$PROGRESS_FILE" ]]; then
    echo "✓ Fichier de progression trouvé: $PROGRESS_FILE"
    echo ""
    echo "Contenu:"
    cat "$PROGRESS_FILE"
    echo ""
    echo "Actions disponibles:"
    echo "  1) Supprimer le fichier de progression : sudo rm $PROGRESS_FILE"
    echo "  2) Continuer avec le fichier existant"
else
    echo "✓ Aucun fichier de progression (installation fraîche)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Vérification des modules"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

required_modules=(
    "config.sh"
    "ui.sh"
    "system.sh"
    "packages.sh"
    "dns.sh"
    "input.sh"
    "progress.sh"
    "database.sh"
    "postfix.sh"
    "dovecot.sh"
    "ssl.sh"
    "autodiscover.sh"
    "webmail.sh"
    "services.sh"
)

all_modules_ok=true
for module in "${required_modules[@]}"; do
    if [[ -f "$LIB_DIR/$module" ]]; then
        echo "✓ $module"
    else
        echo "❌ $module - MANQUANT"
        all_modules_ok=false
    fi
done

echo ""
if [[ "$all_modules_ok" == true ]]; then
    echo "✓ Tous les modules sont présents"
else
    echo "❌ Certains modules sont manquants"
    echo "   Vérifiez que vous êtes dans le bon répertoire"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Lancement avec debug activé"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Le script va maintenant s'exécuter avec le mode debug activé."
echo "Toutes les commandes seront affichées avant leur exécution."
echo "Les logs seront sauvegardés dans: install-debug.log"
echo ""
read -p "Appuyez sur Entrée pour continuer (ou Ctrl+C pour annuler)..."

echo ""
echo "Lancement..."
echo ""

# Lancer avec debug
set -x
bash -x ./install.sh 2>&1 | tee install-debug.log
