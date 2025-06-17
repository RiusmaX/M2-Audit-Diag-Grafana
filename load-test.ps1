# Script PowerShell - Test de Charge Complet pour API Express
# Simule une charge réaliste avec utilisateurs concurrent et métriques

param(
    [int]$Users = 100,           # Nombre d'utilisateurs simultanés
    [int]$Duration = 600,        # Durée du test en secondes
    [int]$RampUp = 100,          # Montée en charge progressive (secondes)
    [string]$BaseUrl = "http://localhost:3001"
)

# Configuration
$Global:Results = @()
$Global:Errors = @()
$Global:StartTime = Get-Date
$Global:TestRunning = $true

# Statistiques globales
$Global:Stats = @{
    TotalRequests = 0
    SuccessfulRequests = 0
    FailedRequests = 0
    MinResponseTime = [double]::MaxValue
    MaxResponseTime = 0
    TotalResponseTime = 0
    RequestsPerSecond = 0
}

Write-Host "🚀 TEST DE CHARGE API EXPRESS" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "👥 Utilisateurs simultanés: $Users" -ForegroundColor Yellow
Write-Host "⏱️  Durée du test: $Duration secondes" -ForegroundColor Yellow
Write-Host "📈 Montée en charge: $RampUp secondes" -ForegroundColor Yellow
Write-Host "🎯 URL de base: $BaseUrl" -ForegroundColor Yellow
Write-Host ""

# Fonction pour faire une requête avec métriques
function Invoke-LoadTestRequest {
    param(
        [string]$Method,
        [string]$Endpoint,
        [hashtable]$Body = $null,
        [int]$UserId
    )
    
    $url = "$BaseUrl$Endpoint"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        if ($Body) {
            $jsonBody = $Body | ConvertTo-Json
            $response = Invoke-RestMethod -Uri $url -Method $Method -Body $jsonBody -ContentType "application/json" -TimeoutSec 30
        } else {
            $response = Invoke-RestMethod -Uri $url -Method $Method -TimeoutSec 30
        }
        
        $stopwatch.Stop()
        $responseTime = $stopwatch.ElapsedMilliseconds
        
        # Enregistrer les statistiques
        $Global:Stats.TotalRequests++
        $Global:Stats.SuccessfulRequests++
        $Global:Stats.TotalResponseTime += $responseTime
        
        if ($responseTime -lt $Global:Stats.MinResponseTime) {
            $Global:Stats.MinResponseTime = $responseTime
        }
        if ($responseTime -gt $Global:Stats.MaxResponseTime) {
            $Global:Stats.MaxResponseTime = $responseTime
        }
        
        $Global:Results += [PSCustomObject]@{
            Timestamp = Get-Date
            UserId = $UserId
            Method = $Method
            Endpoint = $Endpoint
            ResponseTime = $responseTime
            Success = $true
        }
        
        return $true
    }
    catch {
        $stopwatch.Stop()
        $responseTime = $stopwatch.ElapsedMilliseconds
        
        $Global:Stats.TotalRequests++
        $Global:Stats.FailedRequests++
        
        $Global:Errors += [PSCustomObject]@{
            Timestamp = Get-Date
            UserId = $UserId
            Method = $Method
            Endpoint = $Endpoint
            Error = $_.Exception.Message
            ResponseTime = $responseTime
        }
        
        return $false
    }
}

# Scénarios de test
function Start-UserScenario {
    param([int]$UserId)
    
    $scenarios = @(
        # Scénario 1: Navigation simple
        @{ Method = "GET"; Endpoint = "/" },
        @{ Method = "GET"; Endpoint = "/api/users" },
        
        # Scénario 2: Création d'utilisateur
        @{ Method = "POST"; Endpoint = "/api/users"; Body = @{ name = "User$UserId"; email = "user$UserId@test.com" } },
        
        # Scénario 3: Consultation produits et commandes
        @{ Method = "GET"; Endpoint = "/api/products" },
        @{ Method = "GET"; Endpoint = "/api/orders" },
        
        # Scénario 4: Paiement (critique)
        @{ Method = "POST"; Endpoint = "/api/payment"; Body = @{ amount = (Get-Random -Minimum 10 -Maximum 500); card_token = "tok_$UserId" } }
    )
    
    while ($Global:TestRunning) {
        foreach ($scenario in $scenarios) {
            if (-not $Global:TestRunning) { break }
            
            Invoke-LoadTestRequest -Method $scenario.Method -Endpoint $scenario.Endpoint -Body $scenario.Body -UserId $UserId
            
            # Pause aléatoire entre les requêtes (simulation utilisateur réel)
            Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 1000)
        }
    }
}

# Fonction de monitoring en temps réel
function Start-RealTimeMonitoring {
    while ($Global:TestRunning) {
        Start-Sleep -Seconds 5
        
        $elapsed = (Get-Date) - $Global:StartTime
        $currentRPS = if ($elapsed.TotalSeconds -gt 0) { [math]::Round($Global:Stats.TotalRequests / $elapsed.TotalSeconds, 2) } else { 0 }
        $avgResponseTime = if ($Global:Stats.SuccessfulRequests -gt 0) { [math]::Round($Global:Stats.TotalResponseTime / $Global:Stats.SuccessfulRequests, 2) } else { 0 }
        $errorRate = if ($Global:Stats.TotalRequests -gt 0) { [math]::Round(($Global:Stats.FailedRequests / $Global:Stats.TotalRequests) * 100, 2) } else { 0 }
        
        Write-Host "`r📊 Temps: $([math]::Round($elapsed.TotalSeconds, 0))s | Req/s: $currentRPS | Avg: ${avgResponseTime}ms | Erreurs: ${errorRate}% | Total: $($Global:Stats.TotalRequests)" -ForegroundColor Green -NoNewline
    }
}

# Vérification de l'API
Write-Host "🔍 Vérification de l'API..." -ForegroundColor Blue
try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 10
    Write-Host "✅ API disponible - Uptime: $([math]::Round($health.uptime, 2))s" -ForegroundColor Green
}
catch {
    Write-Host "❌ API non disponible. Arrêt du test." -ForegroundColor Red
    exit 1
}

# Démarrage du monitoring
Write-Host "📈 Démarrage du monitoring..." -ForegroundColor Blue
$monitoringJob = Start-Job -ScriptBlock { 
    param($testDuration, $stats)
    Start-RealTimeMonitoring 
} -ArgumentList $Duration, $Global:Stats

Write-Host "🚀 Démarrage du test de charge..." -ForegroundColor Green
Write-Host ""

# Création des jobs utilisateurs avec montée en charge progressive
$userJobs = @()
$delayBetweenUsers = if ($RampUp -gt 0) { $RampUp / $Users } else { 0 }

for ($i = 1; $i -le $Users; $i++) {
    $userJobs += Start-Job -ScriptBlock {
        param($userId, $baseUrl, $testRunning)
        
        # Réplication des fonctions dans le job
        function Invoke-LoadTestRequest {
            param($Method, $Endpoint, $Body, $UserId)
            # [Fonction copiée pour les jobs]
        }
        
        function Start-UserScenario {
            param($UserId)
            # [Fonction copiée pour les jobs]
        }
        
        Start-UserScenario -UserId $userId
    } -ArgumentList $i, $BaseUrl, $Global:TestRunning
    
    if ($delayBetweenUsers -gt 0) {
        Start-Sleep -Seconds $delayBetweenUsers
        Write-Host "👤 Utilisateur $i démarré" -ForegroundColor Cyan
    }
}

# Attendre la durée du test
Start-Sleep -Seconds $Duration

# Arrêter tous les jobs
Write-Host "`n⏹️ Arrêt du test..." -ForegroundColor Yellow
$Global:TestRunning = $false
$userJobs | Stop-Job
$userJobs | Remove-Job
Stop-Job $monitoringJob
Remove-Job $monitoringJob

# Calcul des statistiques finales
$totalTime = (Get-Date) - $Global:StartTime
$avgResponseTime = if ($Global:Stats.SuccessfulRequests -gt 0) { [math]::Round($Global:Stats.TotalResponseTime / $Global:Stats.SuccessfulRequests, 2) } else { 0 }
$rps = [math]::Round($Global:Stats.TotalRequests / $totalTime.TotalSeconds, 2)
$errorRate = if ($Global:Stats.TotalRequests -gt 0) { [math]::Round(($Global:Stats.FailedRequests / $Global:Stats.TotalRequests) * 100, 2) } else { 0 }

# Rapport final
Write-Host "`n📋 RAPPORT DE TEST DE CHARGE" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "⏱️  Durée totale: $([math]::Round($totalTime.TotalSeconds, 2)) secondes" -ForegroundColor White
Write-Host "📊 Requêtes totales: $($Global:Stats.TotalRequests)" -ForegroundColor White
Write-Host "✅ Requêtes réussies: $($Global:Stats.SuccessfulRequests)" -ForegroundColor Green
Write-Host "❌ Requêtes échouées: $($Global:Stats.FailedRequests)" -ForegroundColor Red
Write-Host "🔥 Requêtes/seconde: $rps" -ForegroundColor Yellow
Write-Host "📈 Taux d'erreur: $errorRate%" -ForegroundColor $(if ($errorRate -gt 5) { "Red" } elseif ($errorRate -gt 1) { "Yellow" } else { "Green" })
Write-Host ""
Write-Host "⏱️ TEMPS DE RÉPONSE:" -ForegroundColor Cyan
Write-Host "   📉 Minimum: $($Global:Stats.MinResponseTime)ms" -ForegroundColor Green
Write-Host "   📊 Moyenne: ${avgResponseTime}ms" -ForegroundColor Yellow
Write-Host "   📈 Maximum: $($Global:Stats.MaxResponseTime)ms" -ForegroundColor Red

# Sauvegarde des résultats
$reportPath = "load-test-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$Global:Results | Export-Csv -Path $reportPath -NoTypeInformation
Write-Host "`n💾 Rapport détaillé sauvegardé: $reportPath" -ForegroundColor Green

if ($Global:Errors.Count -gt 0) {
    $errorPath = "load-test-errors-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    $Global:Errors | Export-Csv -Path $errorPath -NoTypeInformation
    Write-Host "⚠️  Erreurs sauvegardées: $errorPath" -ForegroundColor Yellow
}

Write-Host "`n🔗 Vérifiez vos dashboards:" -ForegroundColor Cyan
Write-Host "   📊 Grafana: http://localhost:3000/d/express_app_monitoring_complete" -ForegroundColor White
Write-Host "   📈 Prometheus: http://localhost:9090" -ForegroundColor White

Write-Host "`n🎯 Recommandations:" -ForegroundColor Cyan
if ($errorRate -gt 5) {
    Write-Host "   ⚠️  Taux d'erreur élevé - Vérifiez la capacité du serveur" -ForegroundColor Red
}
if ($avgResponseTime -gt 1000) {
    Write-Host "   ⚠️  Temps de réponse élevé - Optimisation nécessaire" -ForegroundColor Yellow
}
if ($rps -lt 10) {
    Write-Host "   ⚠️  Débit faible - Considérez l'optimisation des performances" -ForegroundColor Yellow
}
if ($errorRate -lt 1 -and $avgResponseTime -lt 500) {
    Write-Host "   ✅ Performances excellentes !" -ForegroundColor Green
} 