#!/bin/bash

# Script Bash - Exécution des Tests de Stress Gatling
# Interface simplifiée pour lancer les tests de charge avec Gatling

# Configuration par défaut
USERS=${1:-50}
RAMP_DURATION=${2:-30}
TEST_DURATION=${3:-300}
BASE_URL=${4:-"http://localhost:3001"}

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Options
REPORTS_ONLY=false
CLEAN_RESULTS=false

# Traitement des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --reports-only)
            REPORTS_ONLY=true
            shift
            ;;
        --clean-results)
            CLEAN_RESULTS=true
            shift
            ;;
        --help|-h)
            echo -e "${CYAN}🎯 GATLING STRESS TESTING SUITE${NC}"
            echo -e "${CYAN}===============================${NC}"
            echo ""
            echo "Usage: $0 [USERS] [RAMP_DURATION] [TEST_DURATION] [BASE_URL] [OPTIONS]"
            echo ""
            echo "Paramètres:"
            echo "  USERS          Nombre d'utilisateurs simultanés (défaut: 50)"
            echo "  RAMP_DURATION  Durée de montée en charge en secondes (défaut: 30)"
            echo "  TEST_DURATION  Durée totale du test en secondes (défaut: 300)"
            echo "  BASE_URL       URL de l'API à tester (défaut: http://localhost:3001)"
            echo ""
            echo "Options:"
            echo "  --reports-only   Générer seulement les rapports à partir des résultats existants"
            echo "  --clean-results  Nettoyer les résultats précédents"
            echo "  --help, -h       Afficher cette aide"
            echo ""
            echo "Exemples:"
            echo "  $0 30 60 180                    # Test avec 30 utilisateurs, 1 minute de ramp, 3 minutes de test"
            echo "  $0 --reports-only               # Générer seulement les rapports"
            echo "  $0 --clean-results              # Nettoyer les résultats"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

echo -e "${MAGENTA}🎯 GATLING STRESS TESTING SUITE${NC}"
echo -e "${MAGENTA}===============================${NC}"
echo ""

# Vérification des prérequis
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker n'est pas installé ou accessible.${NC}"
    echo -e "${YELLOW}💡 Veuillez installer Docker.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose n'est pas installé ou accessible.${NC}"
    echo -e "${YELLOW}💡 Veuillez installer Docker Compose.${NC}"
    exit 1
fi

# Création des dossiers nécessaires
directories=("gatling/results" "gatling/reports" "gatling/user-files/data")
for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}📁 Créé: $dir${NC}"
    fi
done

# Nettoyage des résultats précédents si demandé
if [ "$CLEAN_RESULTS" = true ]; then
    echo -e "${YELLOW}🧹 Nettoyage des résultats précédents...${NC}"
    rm -rf gatling/results/* gatling/reports/* 2>/dev/null || true
    echo -e "${GREEN}✅ Nettoyage terminé${NC}"
fi

# Mode rapports seulement
if [ "$REPORTS_ONLY" = true ]; then
    echo -e "${CYAN}📊 GÉNÉRATION DES RAPPORTS GATLING${NC}"
    echo -e "${CYAN}===================================${NC}"
    
    if [ ! "$(ls -A gatling/results 2>/dev/null)" ]; then
        echo -e "${RED}❌ Aucun résultat trouvé dans gatling/results/${NC}"
        echo -e "${YELLOW}💡 Exécutez d'abord des tests pour générer des données.${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📈 Génération des rapports à partir des résultats existants...${NC}"
    
    if docker-compose -f docker-compose.gatling.yml --profile reports up gatling-reports; then
        echo ""
        echo -e "${GREEN}✅ Rapports générés avec succès!${NC}"
        echo -e "${WHITE}📂 Emplacement: ./gatling/reports/${NC}"
        
        # Tenter d'ouvrir le rapport dans le navigateur (si possible)
        latest_report=$(find gatling/reports -maxdepth 1 -type d -name "*" | sort -r | head -n 1)
        if [ -n "$latest_report" ] && [ -f "$latest_report/index.html" ]; then
            echo -e "${CYAN}🌐 Rapport disponible: $latest_report/index.html${NC}"
            # Tentative d'ouverture automatique selon l'OS
            if command -v xdg-open &> /dev/null; then
                xdg-open "$latest_report/index.html" 2>/dev/null || true
            elif command -v open &> /dev/null; then
                open "$latest_report/index.html" 2>/dev/null || true
            fi
        fi
    else
        echo -e "${RED}❌ Erreur lors de la génération des rapports${NC}"
        exit 1
    fi
    
    exit 0
fi

# Vérification de l'API avant les tests
echo -e "${BLUE}🔍 Vérification de l'API cible...${NC}"
if curl -s --max-time 10 "$BASE_URL/health" >/dev/null 2>&1; then
    uptime=$(curl -s "$BASE_URL/health" | grep -o '"uptime":[0-9.]*' | cut -d':' -f2 2>/dev/null || echo "N/A")
    echo -e "${GREEN}✅ API disponible - Uptime: ${uptime}s${NC}"
else
    echo -e "${RED}❌ API non disponible sur $BASE_URL${NC}"
    echo -e "${YELLOW}💡 Assurez-vous que l'API Express est démarrée:${NC}"
    echo -e "${WHITE}   docker-compose up -d${NC}"
    exit 1
fi

# Configuration des tests
echo ""
echo -e "${CYAN}🚀 CONFIGURATION DU TEST DE STRESS${NC}"
echo -e "${CYAN}===================================${NC}"
echo -e "${YELLOW}👥 Utilisateurs simultanés: $USERS${NC}"
echo -e "${YELLOW}📈 Durée de montée en charge: $RAMP_DURATION secondes${NC}"
echo -e "${YELLOW}⏱️  Durée totale du test: $TEST_DURATION secondes${NC}"
echo -e "${YELLOW}🎯 URL cible: $BASE_URL${NC}"
echo ""

# Estimation de la durée
estimated_duration=$(echo "scale=1; ($TEST_DURATION + $RAMP_DURATION + 60) / 60" | bc -l 2>/dev/null || echo "~$((($TEST_DURATION + $RAMP_DURATION + 60) / 60))")
echo -e "${MAGENTA}⏰ Durée estimée: ${estimated_duration} minutes${NC}"

# Demande de confirmation
echo -n "Voulez-vous continuer? (o/N): "
read -r confirmation
if [[ ! $confirmation =~ ^[oOyY] ]]; then
    echo -e "${YELLOW}❌ Test annulé par l'utilisateur.${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}🚀 DÉMARRAGE DU TEST DE STRESS GATLING${NC}"
echo -e "${GREEN}=======================================${NC}"

# Configuration des variables d'environnement pour Gatling
export JAVA_OPTS="-Xmx2g -Xms1g -Dusers=$USERS -DrampDuration=$RAMP_DURATION -DtestDuration=$TEST_DURATION -DbaseUrl=$BASE_URL"

start_time=$(date +%s)

echo -e "${BLUE}📊 Lancement de Gatling...${NC}"
echo -e "${CYAN}💡 Vous pouvez suivre les métriques en temps réel sur:${NC}"
echo -e "${WHITE}   📈 Grafana: http://localhost:3000/d/express_app_monitoring_complete${NC}"
echo -e "${WHITE}   📊 Prometheus: http://localhost:9090${NC}"
echo ""

# Exécution de Gatling
if docker-compose -f docker-compose.gatling.yml up --remove-orphans gatling; then
    end_time=$(date +%s)
    duration=$(echo "scale=1; ($end_time - $start_time) / 60" | bc -l 2>/dev/null || echo "$(( ($end_time - $start_time) / 60 ))")
    
    echo ""
    echo -e "${GREEN}✅ TEST TERMINÉ AVEC SUCCÈS!${NC}"
    echo -e "${WHITE}⏱️  Durée réelle: ${duration} minutes${NC}"
    
    # Recherche du rapport généré
    latest_result=$(find gatling/results -maxdepth 1 -type d -name "*" | sort -r | head -n 1)
    
    if [ -n "$latest_result" ]; then
        echo ""
        echo -e "${CYAN}📊 RÉSULTATS DISPONIBLES${NC}"
        echo -e "${CYAN}========================${NC}"
        echo -e "${WHITE}📂 Données brutes: $latest_result${NC}"
        
        # Recherche du fichier de simulation.log pour un résumé rapide
        log_file="$latest_result/simulation.log"
        if [ -f "$log_file" ]; then
            echo -e "${YELLOW}📋 Résumé des résultats:${NC}"
            
            # Analyse basique du fichier de log
            request_count=$(grep -c "^REQUEST" "$log_file" 2>/dev/null || echo "0")
            error_count=$(grep -c "^REQUEST.*KO" "$log_file" 2>/dev/null || echo "0")
            success_count=$((request_count - error_count))
            
            if [ "$request_count" -gt 0 ]; then
                success_rate=$(echo "scale=2; $success_count * 100 / $request_count" | bc -l 2>/dev/null || echo "N/A")
                echo -e "${WHITE}   📊 Total des requêtes: $request_count${NC}"
                echo -e "${GREEN}   ✅ Succès: $success_count (${success_rate}%)${NC}"
                echo -e "${RED}   ❌ Échecs: $error_count${NC}"
            fi
        fi
        
        # Génération automatique du rapport HTML
        echo ""
        echo -e "${BLUE}📈 Génération du rapport HTML...${NC}"
        
        result_name=$(basename "$latest_result")
        if docker run --rm -v "$(pwd)/gatling:/opt/gatling" denvazh/gatling:3.9.5 ./bin/gatling.sh -ro "results/$result_name"; then
            report_path="gatling/results/$result_name/index.html"
            if [ -f "$report_path" ]; then
                echo -e "${GREEN}✅ Rapport HTML généré: $report_path${NC}"
                echo -e "${CYAN}🌐 Ouverture automatique du rapport...${NC}"
                
                # Tentative d'ouverture automatique selon l'OS
                if command -v xdg-open &> /dev/null; then
                    xdg-open "$report_path" 2>/dev/null || true
                elif command -v open &> /dev/null; then
                    open "$report_path" 2>/dev/null || true
                fi
            fi
        else
            echo -e "${YELLOW}⚠️  Impossible de générer automatiquement le rapport HTML${NC}"
            echo -e "${CYAN}💡 Utilisez: ./run-gatling.sh --reports-only${NC}"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}💡 COMMANDES UTILES:${NC}"
    echo -e "${WHITE}   📊 Générer rapports: ./run-gatling.sh --reports-only${NC}"
    echo -e "${WHITE}   🧹 Nettoyer résultats: ./run-gatling.sh --clean-results${NC}"
    echo -e "${WHITE}   🔄 Relancer test: ./run-gatling.sh $USERS $RAMP_DURATION $TEST_DURATION${NC}"
    
else
    echo ""
    echo -e "${RED}❌ ERREUR LORS DE L'EXÉCUTION${NC}"
    echo -e "${RED}=============================${NC}"
    
    echo ""
    echo -e "${YELLOW}🔧 SOLUTIONS POSSIBLES:${NC}"
    echo -e "${WHITE}   1. Vérifiez que Docker est démarré${NC}"
    echo -e "${WHITE}   2. Vérifiez que l'API Express fonctionne${NC}"
    echo -e "${WHITE}   3. Libérez de la mémoire (Gatling utilise 2GB)${NC}"
    echo -e "${WHITE}   4. Vérifiez les logs Docker: docker-compose -f docker-compose.gatling.yml logs${NC}"
    
    exit 1
fi

echo ""
echo -e "${MAGENTA}🎯 Test de stress Gatling terminé!${NC}" 