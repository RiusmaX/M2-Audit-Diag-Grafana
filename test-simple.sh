#!/bin/bash

# Script bash simple pour tester l'API Express rapidement
# Compatible macOS/Linux

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔍 Test simple API Express${NC}"
echo ""

# Test 1: Vérification API
echo -e "${CYAN}1. Test API disponible...${NC}"
if curl -s http://localhost:3001/health > /dev/null; then
    uptime=$(curl -s http://localhost:3001/health | grep -o '"uptime":[0-9.]*' | cut -d':' -f2)
    echo -e "   ${GREEN}✅ API OK - Uptime: ${uptime}s${NC}"
else
    echo -e "   ${RED}❌ API non disponible${NC}"
    exit 1
fi

# Test 2: Génération de trafic
echo -e "${CYAN}2. Génération de trafic...${NC}"
for i in {1..5}; do
    curl -s http://localhost:3001/ > /dev/null
    curl -s http://localhost:3001/api/users > /dev/null
    echo -e "   Série $i/5 envoyée"
done

# Test 3: Vérification métriques
echo -e "${CYAN}3. Vérification métriques...${NC}"
if curl -s http://localhost:3001/metrics | grep -q "http_requests_total"; then
    echo -e "   ${GREEN}✅ Métriques disponibles${NC}"
else
    echo -e "   ${RED}❌ Métriques manquantes${NC}"
fi

echo ""
echo -e "${YELLOW}🔗 LIENS UTILES:${NC}"
echo -e "${WHITE}   📊 Prometheus: http://localhost:9090/targets${NC}"
echo -e "${WHITE}   📈 Grafana: http://localhost:3000${NC}"
echo -e "${WHITE}   🚀 Dashboard: http://localhost:3000/d/express_app_monitoring_complete${NC}" 