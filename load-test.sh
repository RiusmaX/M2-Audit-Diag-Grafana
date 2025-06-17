#!/bin/bash

# Script Bash - Test de Charge Complet pour API Express
# Simule une charge réaliste avec utilisateurs concurrents et métriques détaillées

# Configuration par défaut (modifiable via paramètres)
USERS=${1:-10}              # Nombre d'utilisateurs simultanés
DURATION=${2:-60}           # Durée du test en secondes
RAMP_UP=${3:-10}            # Montée en charge progressive (secondes)
BASE_URL=${4:-"http://localhost:3001"}

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Fichiers de résultats
RESULTS_FILE="load-test-results-$(date +%Y%m%d-%H%M%S).csv"
ERRORS_FILE="load-test-errors-$(date +%Y%m%d-%H%M%S).csv"
STATS_FILE="/tmp/load-test-stats.tmp"
MONITOR_FILE="/tmp/load-test-monitor.tmp"

# Variables globales
START_TIME=$(date +%s)
TEST_RUNNING=true
TOTAL_REQUESTS=0
SUCCESSFUL_REQUESTS=0
FAILED_REQUESTS=0
TOTAL_RESPONSE_TIME=0
MIN_RESPONSE_TIME=999999
MAX_RESPONSE_TIME=0

# Initialisation des fichiers
echo "Timestamp,UserId,Method,Endpoint,ResponseTime,Success,Error" > "$RESULTS_FILE"
echo "Timestamp,UserId,Method,Endpoint,Error,ResponseTime" > "$ERRORS_FILE"
echo "0,0,0,0,999999,0" > "$STATS_FILE"

echo -e "${CYAN}🚀 TEST DE CHARGE API EXPRESS${NC}"
echo -e "${CYAN}================================${NC}"
echo -e "${YELLOW}👥 Utilisateurs simultanés: $USERS${NC}"
echo -e "${YELLOW}⏱️  Durée du test: $DURATION secondes${NC}"
echo -e "${YELLOW}📈 Montée en charge: $RAMP_UP secondes${NC}"
echo -e "${YELLOW}🎯 URL de base: $BASE_URL${NC}"
echo ""

# Fonction pour faire une requête avec métriques
make_load_test_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local user_id=$4
    local url="$BASE_URL$endpoint"
    
    # Mesure du temps de réponse
    local start_time=$(date +%s%3N)
    
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        local response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$url" \
                        -H "Content-Type: application/json" \
                        -d "$data" \
                        --max-time 30 2>/dev/null)
    else
        local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" \
                        --max-time 30 2>/dev/null)
    fi
    
    local end_time=$(date +%s%3N)
    local response_time=$((end_time - start_time))
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Mise à jour des statistiques atomique
    (
        flock -x 200
        read total success failed total_time min_time max_time < "$STATS_FILE"
        
        total=$((total + 1))
        total_time=$((total_time + response_time))
        
        if [ "$response_time" -lt "$min_time" ]; then
            min_time=$response_time
        fi
        if [ "$response_time" -gt "$max_time" ]; then
            max_time=$response_time
        fi
        
        if [ "$response" = "200" ] || [ "$response" = "201" ]; then
            success=$((success + 1))
            echo "$timestamp,$user_id,$method,$endpoint,$response_time,true," >> "$RESULTS_FILE"
        else
            failed=$((failed + 1))
            echo "$timestamp,$user_id,$method,$endpoint,HTTP $response,$response_time" >> "$ERRORS_FILE"
            echo "$timestamp,$user_id,$method,$endpoint,$response_time,false,HTTP $response" >> "$RESULTS_FILE"
        fi
        
        echo "$total,$success,$failed,$total_time,$min_time,$max_time" > "$STATS_FILE"
    ) 200<"$STATS_FILE"
    
    return 0
}

# Scénarios utilisateur
run_user_scenario() {
    local user_id=$1
    local request_count=0
    
    while [ -f "$MONITOR_FILE" ]; do
        # Scénario 1: Navigation simple
        make_load_test_request "GET" "/" "" "$user_id"
        [ ! -f "$MONITOR_FILE" ] && break
        
        make_load_test_request "GET" "/api/users" "" "$user_id"
        [ ! -f "$MONITOR_FILE" ] && break
        
        # Scénario 2: Création d'utilisateur
        local user_data="{\"name\":\"User$user_id-$request_count\",\"email\":\"user$user_id-$request_count@test.com\"}"
        make_load_test_request "POST" "/api/users" "$user_data" "$user_id"
        [ ! -f "$MONITOR_FILE" ] && break
        
        # Scénario 3: Consultation produits et commandes
        make_load_test_request "GET" "/api/products" "" "$user_id"
        [ ! -f "$MONITOR_FILE" ] && break
        
        make_load_test_request "GET" "/api/orders" "" "$user_id"
        [ ! -f "$MONITOR_FILE" ] && break
        
        # Scénario 4: Paiement (critique)
        local amount=$(echo "scale=2; $RANDOM / 100" | bc -l 2>/dev/null || echo "99.99")
        local token="tok_${user_id}_${request_count}"
        local payment_data="{\"amount\":$amount,\"card_token\":\"$token\"}"
        make_load_test_request "POST" "/api/payment" "$payment_data" "$user_id"
        [ ! -f "$MONITOR_FILE" ] && break
        
        # Pause aléatoire entre les cycles (simulation utilisateur réel)
        sleep $(echo "scale=3; $RANDOM / 10000 + 0.1" | bc -l 2>/dev/null || echo "0.5")
        
        request_count=$((request_count + 1))
    done
}

# Monitoring en temps réel
start_monitoring() {
    while [ -f "$MONITOR_FILE" ]; do
        sleep 5
        
        if [ -f "$STATS_FILE" ]; then
            read total success failed total_time min_time max_time < "$STATS_FILE"
            
            local current_time=$(date +%s)
            local elapsed=$((current_time - START_TIME))
            
            local rps=0
            local avg_time=0
            local error_rate=0
            
            if [ "$elapsed" -gt 0 ]; then
                rps=$(echo "scale=2; $total / $elapsed" | bc -l 2>/dev/null || echo "0")
            fi
            
            if [ "$success" -gt 0 ]; then
                avg_time=$(echo "scale=2; $total_time / $success" | bc -l 2>/dev/null || echo "0")
            fi
            
            if [ "$total" -gt 0 ]; then
                error_rate=$(echo "scale=2; $failed * 100 / $total" | bc -l 2>/dev/null || echo "0")
            fi
            
            printf "\r${GREEN}📊 Temps: %ds | Req/s: %s | Avg: %sms | Erreurs: %s%% | Total: %d${NC}" \
                "$elapsed" "$rps" "$avg_time" "$error_rate" "$total"
        fi
    done
}

# Vérification de l'API
echo -e "${BLUE}🔍 Vérification de l'API...${NC}"
if curl -s "$BASE_URL/health" > /dev/null 2>&1; then
    uptime=$(curl -s "$BASE_URL/health" | grep -o '"uptime":[0-9.]*' | cut -d':' -f2)
    echo -e "${GREEN}✅ API disponible - Uptime: ${uptime}s${NC}"
else
    echo -e "${RED}❌ API non disponible. Arrêt du test.${NC}"
    exit 1
fi

# Vérification des dépendances
if ! command -v bc &> /dev/null; then
    echo -e "${YELLOW}⚠️  'bc' non installé. Installation recommandée pour de meilleures métriques.${NC}"
fi

# Démarrage du monitoring
echo -e "${BLUE}📈 Démarrage du monitoring...${NC}"
touch "$MONITOR_FILE"
start_monitoring &
MONITOR_PID=$!

echo -e "${GREEN}🚀 Démarrage du test de charge...${NC}"
echo ""

# Création des processus utilisateurs avec montée en charge progressive
USER_PIDS=()
DELAY_BETWEEN_USERS=0

if [ "$RAMP_UP" -gt 0 ]; then
    DELAY_BETWEEN_USERS=$(echo "scale=2; $RAMP_UP / $USERS" | bc -l 2>/dev/null || echo "1")
fi

for ((i=1; i<=USERS; i++)); do
    run_user_scenario "$i" &
    USER_PIDS+=($!)
    
    if [ "$(echo "$DELAY_BETWEEN_USERS > 0" | bc -l 2>/dev/null)" = "1" ]; then
        sleep "$DELAY_BETWEEN_USERS"
        echo -e "${CYAN}👤 Utilisateur $i démarré${NC}"
    fi
done

# Attendre la durée du test
sleep "$DURATION"

# Arrêter tous les processus
echo -e "\n${YELLOW}⏹️ Arrêt du test...${NC}"
rm -f "$MONITOR_FILE"

# Arrêter les processus utilisateurs
for pid in "${USER_PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
done

# Arrêter le monitoring
kill "$MONITOR_PID" 2>/dev/null || true
wait 2>/dev/null || true

# Calcul des statistiques finales
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

if [ -f "$STATS_FILE" ]; then
    read TOTAL_REQUESTS SUCCESSFUL_REQUESTS FAILED_REQUESTS TOTAL_RESPONSE_TIME MIN_RESPONSE_TIME MAX_RESPONSE_TIME < "$STATS_FILE"
fi

# Calculs
RPS=0
AVG_RESPONSE_TIME=0
ERROR_RATE=0

if [ "$TOTAL_TIME" -gt 0 ]; then
    RPS=$(echo "scale=2; $TOTAL_REQUESTS / $TOTAL_TIME" | bc -l 2>/dev/null || echo "0")
fi

if [ "$SUCCESSFUL_REQUESTS" -gt 0 ]; then
    AVG_RESPONSE_TIME=$(echo "scale=2; $TOTAL_RESPONSE_TIME / $SUCCESSFUL_REQUESTS" | bc -l 2>/dev/null || echo "0")
fi

if [ "$TOTAL_REQUESTS" -gt 0 ]; then
    ERROR_RATE=$(echo "scale=2; $FAILED_REQUESTS * 100 / $TOTAL_REQUESTS" | bc -l 2>/dev/null || echo "0")
fi

# Rapport final
echo -e "\n${CYAN}📋 RAPPORT DE TEST DE CHARGE${NC}"
echo -e "${CYAN}==============================${NC}"
echo -e "${WHITE}⏱️  Durée totale: $TOTAL_TIME secondes${NC}"
echo -e "${WHITE}📊 Requêtes totales: $TOTAL_REQUESTS${NC}"
echo -e "${GREEN}✅ Requêtes réussies: $SUCCESSFUL_REQUESTS${NC}"
echo -e "${RED}❌ Requêtes échouées: $FAILED_REQUESTS${NC}"
echo -e "${YELLOW}🔥 Requêtes/seconde: $RPS${NC}"

# Couleur pour le taux d'erreur
if (( $(echo "$ERROR_RATE > 5" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${RED}📈 Taux d'erreur: $ERROR_RATE%${NC}"
elif (( $(echo "$ERROR_RATE > 1" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${YELLOW}📈 Taux d'erreur: $ERROR_RATE%${NC}"
else
    echo -e "${GREEN}📈 Taux d'erreur: $ERROR_RATE%${NC}"
fi

echo ""
echo -e "${CYAN}⏱️ TEMPS DE RÉPONSE:${NC}"
echo -e "${GREEN}   📉 Minimum: ${MIN_RESPONSE_TIME}ms${NC}"
echo -e "${YELLOW}   📊 Moyenne: ${AVG_RESPONSE_TIME}ms${NC}"
echo -e "${RED}   📈 Maximum: ${MAX_RESPONSE_TIME}ms${NC}"

# Sauvegarde des résultats
echo -e "\n${GREEN}💾 Rapport détaillé sauvegardé: $RESULTS_FILE${NC}"

if [ "$FAILED_REQUESTS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Erreurs sauvegardées: $ERRORS_FILE${NC}"
fi

echo -e "\n${CYAN}🔗 Vérifiez vos dashboards:${NC}"
echo -e "${WHITE}   📊 Grafana: http://localhost:3000/d/express_app_monitoring_complete${NC}"
echo -e "${WHITE}   📈 Prometheus: http://localhost:9090${NC}"

# Recommandations
echo -e "\n${CYAN}🎯 Recommandations:${NC}"
if (( $(echo "$ERROR_RATE > 5" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${RED}   ⚠️  Taux d'erreur élevé - Vérifiez la capacité du serveur${NC}"
fi
if (( $(echo "$AVG_RESPONSE_TIME > 1000" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${YELLOW}   ⚠️  Temps de réponse élevé - Optimisation nécessaire${NC}"
fi
if (( $(echo "$RPS < 10" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${YELLOW}   ⚠️  Débit faible - Considérez l'optimisation des performances${NC}"
fi
if (( $(echo "$ERROR_RATE < 1" | bc -l 2>/dev/null || echo "0") )) && (( $(echo "$AVG_RESPONSE_TIME < 500" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${GREEN}   ✅ Performances excellentes !${NC}"
fi

# Nettoyage
rm -f "$STATS_FILE" "$MONITOR_FILE" 2>/dev/null || true

echo -e "\n${CYAN}💡 Commandes pour relancer:${NC}"
echo -e "${WHITE}   PowerShell: ./load-test.ps1 -Users $USERS -Duration $DURATION${NC}"
echo -e "${WHITE}   Bash: ./load-test.sh $USERS $DURATION $RAMP_UP${NC}" 