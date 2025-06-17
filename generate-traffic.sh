#!/bin/bash

# Script bash pour tester l'API Express et générer du trafic
# Compatible macOS/Linux - Équivalent du script PowerShell

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:3001"

echo -e "${YELLOW}🚀 Génération de trafic pour test...${NC}"
echo ""

# Fonction pour faire des requêtes HTTP
make_request() {
    local method=$1
    local url=$2
    local data=$3
    
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$url" \
                   -H "Content-Type: application/json" \
                   -d "$data" 2>/dev/null)
    else
        response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    fi
    
    if [ "$response" = "200" ] || [ "$response" = "201" ]; then
        echo -e "  ${GREEN}✅ $method $url - HTTP $response${NC}"
        return 0
    else
        echo -e "  ${RED}❌ $method $url - HTTP $response${NC}"
        return 1
    fi
}

# Test 1: Vérification API
echo -e "${CYAN}📊 Test de disponibilité de l'API...${NC}"
health_response=$(curl -s "$BASE_URL/health" 2>/dev/null)

if [ $? -eq 0 ]; then
    uptime=$(echo "$health_response" | grep -o '"uptime":[0-9.]*' | cut -d':' -f2)
    echo -e "${GREEN}✅ API disponible - Uptime: ${uptime}s${NC}"
else
    echo -e "${RED}❌ API non disponible sur $BASE_URL${NC}"
    echo -e "${YELLOW}   Assurez-vous que l'application Express est démarrée${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🎯 Début des tests des 6 endpoints...${NC}"
echo ""

# Boucle de test pour générer du trafic
for i in {1..20}; do
    echo -e "${MAGENTA}📡 Série de tests #$i/20${NC}"
    
    # 1. Test endpoint d'accueil
    make_request "GET" "$BASE_URL/"
    
    # 2. Test endpoint utilisateurs
    make_request "GET" "$BASE_URL/api/users"
    
    # 3. Test création utilisateur
    user_data="{\"name\":\"Utilisateur Test $i\",\"email\":\"test$i@example.com\"}"
    make_request "POST" "$BASE_URL/api/users" "$user_data"
    
    # 4. Test endpoint produits
    make_request "GET" "$BASE_URL/api/products"
    
    # 5. Test endpoint commandes
    make_request "GET" "$BASE_URL/api/orders"
    
    # 6. Test endpoint paiement
    amount=$(echo "scale=2; $RANDOM / 100" | bc -l)
    if [ -z "$amount" ]; then
        amount="99.99"
    fi
    token="tok_$(printf "%05d" $((RANDOM % 99999)))"
    payment_data="{\"amount\":$amount,\"card_token\":\"$token\"}"
    make_request "POST" "$BASE_URL/api/payment" "$payment_data"
    
    # Test d'un endpoint inexistant (génère des 404) tous les 10 tests
    if [ $((i % 10)) -eq 0 ]; then
        echo -e "${WHITE}🔍 Test endpoint inexistant...${NC}"
        make_request "GET" "$BASE_URL/api/nonexistent"
    fi
    
    # Petite pause entre les séries
    sleep_time=$(echo "scale=3; $RANDOM / 10000" | bc -l 2>/dev/null || echo "0.2")
    sleep "$sleep_time"
    
    # Affichage des liens tous les 10 tests
    if [ $((i % 10)) -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}📈 Vérifiez vos dashboards Grafana !${NC}"
        echo -e "${CYAN}   🔹 Système: http://localhost:3000/d/system_monitoring_complete${NC}"
        echo -e "${CYAN}   🔹 Express: http://localhost:3000/d/express_app_monitoring_complete${NC}"
        echo ""
    fi
done

echo ""
echo -e "${GREEN}🎉 Test terminé !${NC}"
echo ""
echo -e "${YELLOW}📊 DASHBOARDS DISPONIBLES:${NC}"
echo -e "${WHITE}   🖥️  Monitoring Système:     http://localhost:3000/d/system_monitoring_complete${NC}"
echo -e "${WHITE}   🚀 Monitoring Express App: http://localhost:3000/d/express_app_monitoring_complete${NC}"
echo -e "${WHITE}   📈 Prometheus Targets:     http://localhost:9090/targets${NC}"
echo -e "${WHITE}   🔍 API Documentation:      http://localhost:3001/${NC}"
echo ""
echo -e "${CYAN}💡 Pour plus de trafic, relancez ce script !${NC}"
echo -e "${CYAN}💡 Commande: ${WHITE}./generate-traffic.sh${NC}" 