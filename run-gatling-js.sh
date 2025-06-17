#!/bin/bash

# Script Bash pour exécuter les tests Gatling JavaScript universels
# Compatible Linux/macOS

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration par défaut
TARGET_URL="http://localhost:3001"
ENDPOINTS="/"
HTTP_METHODS="GET"
BASE_USERS=5
MAX_USERS=50
TEST_DURATION=60
RAMP_DURATION=30
THINK_TIME=1
HEADERS="{}"
REQUEST_TIMEOUT=10000
ENABLE_STRESS=false
DEBUG=false
SETUP=false
HELP=false

# Fonctions utilitaires
print_colored() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${NC}"
}

show_help() {
    print_colored "🚀 Gatling JavaScript Universal Tester" "$CYAN"
    print_colored "=======================================" "$CYAN"
    echo ""
    print_colored "UTILISATION:" "$YELLOW"
    echo "  ./run-gatling-js.sh [OPTIONS]"
    echo ""
    print_colored "OPTIONS PRINCIPALES:" "$YELLOW"
    echo "  -u, --url <url>         URL cible à tester"
    echo "  -e, --endpoints <list>  Endpoints séparés par virgules"
    echo "  -m, --methods <list>    Méthodes HTTP (GET,POST,PUT,DELETE,PATCH)"
    echo "  -b, --base-users <n>    Nombre d'utilisateurs de base"
    echo "  -M, --max-users <n>     Nombre maximum d'utilisateurs"
    echo "  -d, --duration <sec>    Durée du test en secondes"
    echo "  -s, --stress            Active le test de stress"
    echo "  -D, --debug             Active le mode debug"
    echo "  -S, --setup             Installe les dépendances"
    echo "  -h, --help              Affiche cette aide"
    echo ""
    print_colored "EXEMPLES:" "$YELLOW"
    echo "  # Test simple"
    echo "  ./run-gatling-js.sh -u 'https://api.exemple.com'"
    echo ""
    echo "  # Test multi-endpoints"
    echo "  ./run-gatling-js.sh -u 'http://localhost:3001' -e '/,/api/users,/api/products'"
    echo ""
    echo "  # Test de stress"
    echo "  ./run-gatling-js.sh -u 'http://localhost:3001' --stress -M 100"
    echo ""
    echo "  # Installation"
    echo "  ./run-gatling-js.sh --setup"
}

test_prerequisites() {
    print_colored "🔍 Vérification des prérequis..." "$BLUE"
    
    # Vérifier Node.js
    if command -v node &> /dev/null; then
        local node_version=$(node --version)
        print_colored "✅ Node.js détecté: $node_version" "$GREEN"
    else
        print_colored "❌ Node.js n'est pas installé!" "$RED"
        print_colored "Installez Node.js depuis https://nodejs.org/" "$YELLOW"
        return 1
    fi
    
    # Vérifier npm
    if command -v npm &> /dev/null; then
        local npm_version=$(npm --version)
        print_colored "✅ npm détecté: $npm_version" "$GREEN"
    else
        print_colored "❌ npm n'est pas disponible!" "$RED"
        return 1
    fi
    
    return 0
}

install_dependencies() {
    print_colored "📦 Installation des dépendances Gatling JavaScript..." "$BLUE"
    
    if [[ ! -f "package.json" ]]; then
        print_colored "❌ Fichier package.json non trouvé!" "$RED"
        return 1
    fi
    
    print_colored "Installation des packages npm..." "$YELLOW"
    if ! npm install; then
        print_colored "❌ Erreur lors de l'installation npm" "$RED"
        return 1
    fi
    
    print_colored "Installation de Gatling CLI globalement..." "$YELLOW"
    if ! npm install -g @gatling.io/cli; then
        print_colored "❌ Erreur lors de l'installation de Gatling CLI" "$RED"
        return 1
    fi
    
    print_colored "✅ Installation terminée!" "$GREEN"
    return 0
}

test_target_url() {
    local url="$1"
    print_colored "🌐 Test de connectivité vers $url..." "$BLUE"
    
    if command -v curl &> /dev/null; then
        if curl -s --head --max-time 10 "$url" > /dev/null 2>&1; then
            print_colored "✅ URL accessible" "$GREEN"
        else
            print_colored "⚠️  URL non accessible ou timeout" "$YELLOW"
            print_colored "Le test continuera quand même..." "$YELLOW"
        fi
    elif command -v wget &> /dev/null; then
        if wget --spider --timeout=10 "$url" > /dev/null 2>&1; then
            print_colored "✅ URL accessible" "$GREEN"
        else
            print_colored "⚠️  URL non accessible ou timeout" "$YELLOW"
            print_colored "Le test continuera quand même..." "$YELLOW"
        fi
    else
        print_colored "⚠️  curl/wget non disponible, impossible de tester l'URL" "$YELLOW"
    fi
}

start_gatling_test() {
    print_colored "🚀 Démarrage du test Gatling JavaScript..." "$CYAN"
    print_colored "=========================================" "$CYAN"
    
    # Configuration des variables d'environnement
    export TARGET_URL="$TARGET_URL"
    export ENDPOINTS="$ENDPOINTS"
    export HTTP_METHODS="$HTTP_METHODS"
    export BASE_USERS="$BASE_USERS"
    export MAX_USERS="$MAX_USERS"
    export TEST_DURATION="$TEST_DURATION"
    export RAMP_DURATION="$RAMP_DURATION"
    export THINK_TIME="$THINK_TIME"
    export HEADERS="$HEADERS"
    export REQUEST_TIMEOUT="$REQUEST_TIMEOUT"
    export ENABLE_STRESS="$ENABLE_STRESS"
    export DEBUG="$DEBUG"
    
    print_colored "Configuration du test:" "$YELLOW"
    echo "  URL cible: $TARGET_URL"
    echo "  Endpoints: $ENDPOINTS"
    echo "  Méthodes HTTP: $HTTP_METHODS"
    echo "  Utilisateurs base/max: $BASE_USERS/$MAX_USERS"
    echo "  Durée: $TEST_DURATION secondes"
    echo "  Test de stress: $(if [[ "$ENABLE_STRESS" == "true" ]]; then echo "Activé"; else echo "Désactivé"; fi)"
    echo "  Mode debug: $(if [[ "$DEBUG" == "true" ]]; then echo "Activé"; else echo "Désactivé"; fi)"
    echo ""
    
    local start_time=$(date)
    print_colored "⏱️  Début du test: $start_time" "$BLUE"
    
    # Exécution du test Gatling
    if gatling run --simulation gatling-js-universal-test.js; then
        local end_time=$(date)
        print_colored "✅ Test terminé avec succès!" "$GREEN"
        print_colored "⏱️  Fin du test: $end_time" "$BLUE"
        
        # Recherche du répertoire de résultats
        if [[ -d "results" ]]; then
            local latest_result=$(find results -type d -name "*" | sort | tail -1)
            if [[ -n "$latest_result" && -f "$latest_result/index.html" ]]; then
                print_colored "📊 Rapport disponible: $latest_result/index.html" "$CYAN"
                print_colored "💡 Ouvrir le rapport: open '$latest_result/index.html' (macOS) ou xdg-open '$latest_result/index.html' (Linux)" "$YELLOW"
            fi
        fi
        
        return 0
    else
        print_colored "❌ Erreur lors de l'exécution du test" "$RED"
        return 1
    fi
}

show_summary() {
    print_colored "\n📋 RÉSUMÉ DU TEST" "$CYAN"
    print_colored "=================" "$CYAN"
    echo "  URL testée: $TARGET_URL"
    echo "  Endpoints: $ENDPOINTS"
    echo "  Méthodes: $HTTP_METHODS"
    echo "  Charge: $BASE_USERS → $MAX_USERS utilisateurs"
    echo "  Durée: $TEST_DURATION secondes"
    echo "  Stress test: $(if [[ "$ENABLE_STRESS" == "true" ]]; then echo "Oui"; else echo "Non"; fi)"
    echo ""
    print_colored "💡 Conseils:" "$YELLOW"
    echo "  • Analysez le rapport HTML généré"
    echo "  • Vérifiez les temps de réponse et taux d'erreur"
    echo "  • Ajustez les paramètres selon les résultats"
    echo "  • Utilisez --debug pour plus de détails"
}

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            TARGET_URL="$2"
            shift 2
            ;;
        -e|--endpoints)
            ENDPOINTS="$2"
            shift 2
            ;;
        -m|--methods)
            HTTP_METHODS="$2"
            shift 2
            ;;
        -b|--base-users)
            BASE_USERS="$2"
            shift 2
            ;;
        -M|--max-users)
            MAX_USERS="$2"
            shift 2
            ;;
        -d|--duration)
            TEST_DURATION="$2"
            shift 2
            ;;
        -r|--ramp-duration)
            RAMP_DURATION="$2"
            shift 2
            ;;
        -t|--think-time)
            THINK_TIME="$2"
            shift 2
            ;;
        --headers)
            HEADERS="$2"
            shift 2
            ;;
        --timeout)
            REQUEST_TIMEOUT="$2"
            shift 2
            ;;
        -s|--stress)
            ENABLE_STRESS=true
            shift
            ;;
        -D|--debug)
            DEBUG=true
            shift
            ;;
        -S|--setup)
            SETUP=true
            shift
            ;;
        -h|--help)
            HELP=true
            shift
            ;;
        *)
            print_colored "❌ Option inconnue: $1" "$RED"
            show_help
            exit 1
            ;;
    esac
done

# ============================================================================
# SCRIPT PRINCIPAL
# ============================================================================

if [[ "$HELP" == "true" ]]; then
    show_help
    exit 0
fi

print_colored "🚀 Gatling JavaScript Universal Tester" "$CYAN"
print_colored "=======================================" "$CYAN"

# Vérification des prérequis
if ! test_prerequisites; then
    exit 1
fi

# Installation si demandée
if [[ "$SETUP" == "true" ]]; then
    if install_dependencies; then
        print_colored "\n✅ Installation terminée! Vous pouvez maintenant lancer des tests." "$GREEN"
        show_help
    else
        print_colored "\n❌ Échec de l'installation." "$RED"
        exit 1
    fi
    exit 0
fi

# Vérification de l'existence du script de test
if [[ ! -f "gatling-js-universal-test.js" ]]; then
    print_colored "❌ Script de test 'gatling-js-universal-test.js' non trouvé!" "$RED"
    print_colored "Assurez-vous d'être dans le bon répertoire." "$YELLOW"
    exit 1
fi

# Test de connectivité
test_target_url "$TARGET_URL"

# Démarrage du test
if start_gatling_test; then
    show_summary
    print_colored "\n🎉 Test terminé avec succès!" "$GREEN"
else
    print_colored "\n❌ Le test a échoué." "$RED"
    exit 1
fi 