#!/bin/bash

# Script Bash - Test de Stress Intensif pour API Express
# Test avec paliers de charge croissants pour identifier les limites

# Configuration
BASE_URL=${1:-"http://localhost:3001"}
MAX_USERS=${2:-50}
STEP_DURATION=${3:-30}
STRESS_DURATION=${4:-120}

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Fichiers de résultats
STRESS_RESULTS="stress-test-results-$(date +%Y%m%d-%H%M%S).csv"
PERFORMANCE_LOG="stress-performance-$(date +%Y%m%d-%H%M%S).log"

echo -e "${MAGENTA}💥 TEST DE STRESS INTENSIF API EXPRESS${NC}"
echo -e "${MAGENTA}=====================================${NC}"
echo -e "${YELLOW}🎯 URL cible: $BASE_URL${NC}"
echo -e "${YELLOW}👥 Maximum utilisateurs: $MAX_USERS${NC}"
echo -e "${YELLOW}⏱️  Durée par palier: $STEP_DURATION secondes${NC}"
echo -e "${YELLOW}🔥 Test de stress final: $STRESS_DURATION secondes${NC}"
echo ""

# Initialisation des logs
echo "Step,Users,Duration,TotalRequests,SuccessfulRequests,FailedRequests,RPS,AvgResponseTime,MinResponseTime,MaxResponseTime,ErrorRate,CPUUsage,MemoryUsage" > "$STRESS_RESULTS"

# Fonction de monitoring système
monitor_system() {
    local step=$1
    local users=$2
    local duration=$3
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Démarrage palier $step - $users utilisateurs pour ${duration}s" >> "$PERFORMANCE_LOG"
    
    # Monitoring CPU et mémoire (si disponible)
    if command -v top &> /dev/null; then
        top -l 1 | grep "CPU usage" >> "$PERFORMANCE_LOG" 2>/dev/null || true
        top -l 1 | grep "PhysMem" >> "$PERFORMANCE_LOG" 2>/dev/null || true
    elif command -v htop &> /dev/null; then
        htop -d 1 -n 1 | head -5 >> "$PERFORMANCE_LOG" 2>/dev/null || true
    fi
}

# Test de stress par paliers
run_stress_step() {
    local step=$1
    local users=$2
    local duration=$3
    
    echo -e "${CYAN}📊 PALIER $step: $users utilisateurs pendant ${duration}s${NC}"
    
    # Créer un fichier temporaire pour les stats de ce palier
    local step_stats="/tmp/stress-step-$step.tmp"
    echo "0,0,0,0,999999,0" > "$step_stats"
    
    # Fonction de requête pour ce palier
    make_stress_request() {
        local user_id=$1
        local step_num=$2
        local endpoint_num=$((RANDOM % 6))
        
        case $endpoint_num in
            0) endpoint="/" ; method="GET" ; data="" ;;
            1) endpoint="/api/users" ; method="GET" ; data="" ;;
            2) endpoint="/api/users" ; method="POST" ; data="{\"name\":\"StressUser$user_id\",\"email\":\"stress$user_id@test.com\"}" ;;
            3) endpoint="/api/products" ; method="GET" ; data="" ;;
            4) endpoint="/api/orders" ; method="GET" ; data="" ;;
            5) endpoint="/api/payment" ; method="POST" ; data="{\"amount\":$(($RANDOM % 500 + 10)),\"card_token\":\"stress_tok_$user_id\"}" ;;
        esac
        
        local start_time=$(date +%s%3N)
        
        if [ "$method" = "POST" ] && [ -n "$data" ]; then
            local response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL$endpoint" \
                            -H "Content-Type: application/json" \
                            -d "$data" \
                            --max-time 10 2>/dev/null)
        else
            local response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$endpoint" \
                            --max-time 10 2>/dev/null)
        fi
        
        local end_time=$(date +%s%3N)
        local response_time=$((end_time - start_time))
        
        # Mise à jour atomique des stats
        (
            flock -x 200
            read total success failed total_time min_time max_time < "$step_stats"
            
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
            else
                failed=$((failed + 1))
            fi
            
            echo "$total,$success,$failed,$total_time,$min_time,$max_time" > "$step_stats"
        ) 200<"$step_stats"
    }
    
    # Démarrer les utilisateurs pour ce palier
    local user_pids=()
    local step_monitor="/tmp/stress-monitor-$step.tmp"
    touch "$step_monitor"
    
    for ((i=1; i<=users; i++)); do
        (
            while [ -f "$step_monitor" ]; do
                make_stress_request "$i" "$step"
                sleep $(echo "scale=3; $RANDOM / 10000 + 0.05" | bc -l 2>/dev/null || echo "0.1")
            done
        ) &
        user_pids+=($!)
    done
    
    # Monitoring en temps réel
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        sleep 5
        
        if [ -f "$step_stats" ]; then
            read total success failed total_time min_time max_time < "$step_stats"
            local elapsed=$(($(date +%s) - start_time))
            local rps=$(echo "scale=2; $total / $elapsed" | bc -l 2>/dev/null || echo "0")
            local avg_time=$(echo "scale=2; $total_time / $success" | bc -l 2>/dev/null || echo "0")
            local error_rate=$(echo "scale=2; $failed * 100 / $total" | bc -l 2>/dev/null || echo "0")
            
            printf "\r${GREEN}📊 Palier $step: %ds | Users: $users | Req/s: %s | Avg: %sms | Erreurs: %s%%${NC}" \
                "$elapsed" "$rps" "$avg_time" "$error_rate"
        fi
    done
    
    # Arrêter ce palier
    rm -f "$step_monitor"
    for pid in "${user_pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
    
    # Calculer les statistiques finales du palier
    if [ -f "$step_stats" ]; then
        read total success failed total_time min_time max_time < "$step_stats"
        local actual_duration=$(($(date +%s) - start_time))
        local rps=$(echo "scale=2; $total / $actual_duration" | bc -l 2>/dev/null || echo "0")
        local avg_time=$(echo "scale=2; $total_time / $success" | bc -l 2>/dev/null || echo "0")
        local error_rate=$(echo "scale=2; $failed * 100 / $total" | bc -l 2>/dev/null || echo "0")
        
        # Sauvegarde des résultats
        echo "$step,$users,$actual_duration,$total,$success,$failed,$rps,$avg_time,$min_time,$max_time,$error_rate,N/A,N/A" >> "$STRESS_RESULTS"
        
        echo -e "\n${CYAN}📋 Palier $step terminé:${NC}"
        echo -e "${WHITE}   Requêtes: $total | Succès: $success | Échecs: $failed${NC}"
        echo -e "${WHITE}   RPS: $rps | Temps moyen: ${avg_time}ms | Erreurs: ${error_rate}%${NC}"
        
        # Alertes de performance
        if (( $(echo "$error_rate > 10" | bc -l 2>/dev/null || echo "0") )); then
            echo -e "${RED}   ⚠️  ALERTE: Taux d'erreur critique!${NC}"
        fi
        if (( $(echo "$avg_time > 2000" | bc -l 2>/dev/null || echo "0") )); then
            echo -e "${RED}   ⚠️  ALERTE: Temps de réponse très élevé!${NC}"
        fi
        
        rm -f "$step_stats"
    fi
    
    echo ""
    sleep 2  # Pause entre les paliers
}

# Vérification de l'API
echo -e "${BLUE}🔍 Vérification de l'API...${NC}"
if ! curl -s "$BASE_URL/health" > /dev/null 2>&1; then
    echo -e "${RED}❌ API non disponible. Arrêt du test.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ API disponible${NC}"
echo ""

# Phase 1: Tests par paliers croissants
echo -e "${CYAN}🚀 PHASE 1: TESTS PAR PALIERS CROISSANTS${NC}"
echo -e "${CYAN}========================================${NC}"

STEP=1
for users in 5 10 20 30 $MAX_USERS; do
    monitor_system $STEP $users $STEP_DURATION
    run_stress_step $STEP $users $STEP_DURATION
    STEP=$((STEP + 1))
done

# Phase 2: Test de stress intensif final
echo -e "${CYAN}💥 PHASE 2: TEST DE STRESS INTENSIF FINAL${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "${YELLOW}👥 $MAX_USERS utilisateurs simultanés pendant ${STRESS_DURATION}s${NC}"
echo ""

monitor_system "STRESS" $MAX_USERS $STRESS_DURATION
run_stress_step "STRESS" $MAX_USERS $STRESS_DURATION

# Analyse finale
echo -e "${MAGENTA}📊 ANALYSE FINALE DU TEST DE STRESS${NC}"
echo -e "${MAGENTA}====================================${NC}"

# Lecture des résultats pour analyse
if [ -f "$STRESS_RESULTS" ]; then
    echo -e "${CYAN}📈 Résumé des paliers:${NC}"
    
    # Trouver le palier avec les meilleures performances
    local best_rps=0
    local best_step=""
    local worst_error_rate=0
    local worst_step=""
    
    while IFS=',' read -r step users duration total success failed rps avg_time min_time max_time error_rate cpu mem; do
        if [ "$step" != "Step" ] && [ -n "$rps" ]; then
            echo -e "${WHITE}   Palier $step ($users users): $rps req/s, ${avg_time}ms avg, ${error_rate}% erreurs${NC}"
            
            # Recherche des meilleurs/pires résultats
            if (( $(echo "$rps > $best_rps" | bc -l 2>/dev/null || echo "0") )); then
                best_rps=$rps
                best_step=$step
            fi
            
            if (( $(echo "$error_rate > $worst_error_rate" | bc -l 2>/dev/null || echo "0") )); then
                worst_error_rate=$error_rate
                worst_step=$step
            fi
        fi
    done < "$STRESS_RESULTS"
    
    echo ""
    echo -e "${GREEN}🏆 Meilleure performance: Palier $best_step avec $best_rps req/s${NC}"
    if [ -n "$worst_step" ] && (( $(echo "$worst_error_rate > 5" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "${RED}⚠️  Palier critique: Palier $worst_step avec ${worst_error_rate}% d'erreurs${NC}"
    fi
fi

# Recommandations finales
echo ""
echo -e "${CYAN}🎯 RECOMMANDATIONS DE CAPACITÉ:${NC}"

# Calculer la capacité recommandée (70% du meilleur palier)
if [ -n "$best_rps" ] && (( $(echo "$best_rps > 0" | bc -l 2>/dev/null || echo "0") )); then
    local recommended_rps=$(echo "scale=2; $best_rps * 0.7" | bc -l 2>/dev/null || echo "0")
    echo -e "${GREEN}   📊 Capacité recommandée: $recommended_rps req/s (70% du pic)${NC}"
fi

if (( $(echo "$worst_error_rate > 1" | bc -l 2>/dev/null || echo "0") )); then
    echo -e "${YELLOW}   ⚠️  Optimisation nécessaire pour réduire les erreurs${NC}"
fi

echo -e "${WHITE}   🔧 Zones d'amélioration potentielles:${NC}"
echo -e "${WHITE}      - Optimisation des requêtes lentes${NC}"
echo -e "${WHITE}      - Mise en cache des réponses${NC}"
echo -e "${WHITE}      - Dimensionnement des ressources${NC}"
echo -e "${WHITE}      - Configuration des pools de connexions${NC}"

echo ""
echo -e "${GREEN}💾 Résultats sauvegardés:${NC}"
echo -e "${WHITE}   📊 Données détaillées: $STRESS_RESULTS${NC}"
echo -e "${WHITE}   📝 Logs de performance: $PERFORMANCE_LOG${NC}"

echo ""
echo -e "${CYAN}🔗 Dashboards de monitoring:${NC}"
echo -e "${WHITE}   📊 Grafana: http://localhost:3000/d/express_app_monitoring_complete${NC}"
echo -e "${WHITE}   📈 Prometheus: http://localhost:9090${NC}"

echo ""
echo -e "${MAGENTA}🎯 Test de stress terminé avec succès!${NC}" 