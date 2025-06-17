# Script PowerShell pour tester l'API Express et générer du trafic
# Utile pour la démo Grafana

Write-Host "🚀 Script de test de l'API Express" -ForegroundColor Cyan
Write-Host "Génération de trafic pour la démo monitoring" -ForegroundColor Yellow
Write-Host ""

$baseUrl = "http://localhost:3001"

# Fonction pour faire des requêtes HTTP
function Invoke-ApiRequest {
    param(
        [string]$Method,
        [string]$Url,
        [hashtable]$Body = $null
    )
    
    try {
        if ($Body) {
            $jsonBody = $Body | ConvertTo-Json
            $response = Invoke-RestMethod -Uri $Url -Method $Method -Body $jsonBody -ContentType "application/json" -ErrorAction Stop
        } else {
            $response = Invoke-RestMethod -Uri $Url -Method $Method -ErrorAction Stop
        }
        
        Write-Host "✅ $Method $Url - " -NoNewline -ForegroundColor Green
        if ($response.message) {
            Write-Host $response.message -ForegroundColor White
        } else {
            Write-Host "Success" -ForegroundColor White
        }
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "❌ $Method $Url - HTTP $statusCode" -ForegroundColor Red
        return $false
    }
}

Write-Host "📊 Test de disponibilité de l'API..." -ForegroundColor Blue
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method GET
    Write-Host "✅ API disponible - Uptime: $([math]::Round($health.uptime, 2))s" -ForegroundColor Green
} catch {
    Write-Host "❌ API non disponible sur $baseUrl" -ForegroundColor Red
    Write-Host "   Assurez-vous que l'application Express est démarrée" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "🎯 Début des tests des 6 endpoints..." -ForegroundColor Blue
Write-Host ""

# Boucle de test pour générer du trafic
for ($i = 1; $i -le 50; $i++) {
    Write-Host "📡 Série de tests #$i/50" -ForegroundColor Magenta
    
    # 1. Test endpoint d'accueil
    Invoke-ApiRequest -Method "GET" -Url "$baseUrl/"
    
    # 2. Test endpoint utilisateurs
    Invoke-ApiRequest -Method "GET" -Url "$baseUrl/api/users"
    
    # 3. Test création utilisateur
    $userData = @{
        name = "Utilisateur Test $i"
        email = "test$i@example.com"
    }
    Invoke-ApiRequest -Method "POST" -Url "$baseUrl/api/users" -Body $userData
    
    # 4. Test endpoint produits
    Invoke-ApiRequest -Method "GET" -Url "$baseUrl/api/products"
    
    # 5. Test endpoint commandes
    Invoke-ApiRequest -Method "GET" -Url "$baseUrl/api/orders"
    
    # 6. Test endpoint paiement
    $paymentData = @{
        amount = [math]::Round((Get-Random -Minimum 10 -Maximum 500), 2)
        card_token = "tok_" + (Get-Random -Maximum 99999).ToString("00000")
    }
    Invoke-ApiRequest -Method "POST" -Url "$baseUrl/api/payment" -Body $paymentData
    
    # Test d'un endpoint inexistant (génère des 404)
    if ($i % 10 -eq 0) {
        Write-Host "🔍 Test endpoint inexistant..." -ForegroundColor Gray
        Invoke-ApiRequest -Method "GET" -Url "$baseUrl/api/nonexistent"
    }
    
    # Petite pause entre les séries
    Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 500)
    
    if ($i % 10 -eq 0) {
        Write-Host ""
        Write-Host "📈 Vérifiez vos dashboards Grafana !" -ForegroundColor Yellow
        Write-Host "   🔹 Système: http://localhost:3000/d/system_monitoring_complete" -ForegroundColor Cyan
        Write-Host "   🔹 Express: http://localhost:3000/d/express_app_monitoring" -ForegroundColor Cyan
        Write-Host ""
    }
}

Write-Host ""
Write-Host "🎉 Test terminé !" -ForegroundColor Green
Write-Host ""
Write-Host "📊 DASHBOARDS DISPONIBLES:" -ForegroundColor Yellow
Write-Host "   🖥️  Monitoring Système:     http://localhost:3000/d/system_monitoring_complete" -ForegroundColor White
Write-Host "   🚀 Monitoring Express App: http://localhost:3000/d/express_app_monitoring" -ForegroundColor White
Write-Host "   📈 Prometheus Targets:     http://localhost:9090/targets" -ForegroundColor White
Write-Host "   🔍 API Documentation:      http://localhost:3001/" -ForegroundColor White
Write-Host ""
Write-Host "💡 Pour plus de trafic, relancez ce script !" -ForegroundColor Cyan 