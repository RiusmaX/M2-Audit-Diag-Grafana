Write-Host "🔍 Test simple API Express" -ForegroundColor Yellow

# Test 1: Vérification API
Write-Host "1. Test API disponible..." -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "http://localhost:3001/health"
    Write-Host "   ✅ API OK - Uptime: $([math]::Round($health.uptime, 2))s" -ForegroundColor Green
} catch {
    Write-Host "   ❌ API non disponible" -ForegroundColor Red
    exit
}

# Test 2: Génération de trafic
Write-Host "2. Génération de trafic..." -ForegroundColor Cyan
for ($i = 1; $i -le 5; $i++) {
    Invoke-RestMethod -Uri "http://localhost:3001/" | Out-Null
    Invoke-RestMethod -Uri "http://localhost:3001/api/users" | Out-Null
    Write-Host "   Série $i/5 envoyée" -ForegroundColor White
}

# Test 3: Vérification métriques
Write-Host "3. Vérification métriques..." -ForegroundColor Cyan
try {
    $metrics = Invoke-RestMethod -Uri "http://localhost:3001/metrics"
    if ($metrics -match "http_requests_total") {
        Write-Host "   ✅ Métriques disponibles" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Métriques manquantes" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Erreur métriques" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔗 LIENS UTILES:" -ForegroundColor Yellow
Write-Host "   📊 Prometheus: http://localhost:9090/targets" -ForegroundColor White
Write-Host "   📈 Grafana: http://localhost:3000" -ForegroundColor White
Write-Host "   🚀 Dashboard: http://localhost:3000/d/express_app_monitoring" -ForegroundColor White 