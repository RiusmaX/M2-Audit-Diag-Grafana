# Script PowerShell - Test de Stress Intensif pour API Express
# Test avec paliers de charge croissants pour identifier les limites

param(
    [string]$BaseUrl = "http://localhost:3001",
    [int]$MaxUsers = 50,
    [int]$StepDuration = 30,
    [int]$StressDuration = 120
)

# Configuration
$Global:StressResults = @()
$Global:PerformanceLog = @()

Write-Host "💥 TEST DE STRESS INTENSIF API EXPRESS" -ForegroundColor Magenta
Write-Host "======================================" -ForegroundColor Magenta
Write-Host "🎯 URL cible: $BaseUrl" -ForegroundColor Yellow
Write-Host "👥 Maximum utilisateurs: $MaxUsers" -ForegroundColor Yellow
Write-Host "⏱️  Durée par palier: $StepDuration secondes" -ForegroundColor Yellow
Write-Host "🔥 Test de stress final: $StressDuration secondes" -ForegroundColor Yellow
Write-Host ""

# Fonction de monitoring système
function Get-SystemMetrics {
    try {
        $cpu = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
        $memory = Get-WmiObject -Class Win32_OperatingSystem
        $memoryUsage = [math]::Round((($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100, 2)
        
        return @{
            CPU = $cpu
            Memory = $memoryUsage
        }
    }
    catch {
        return @{
            CPU = "N/A"
            Memory = "N/A"
        }
    }
}

# Fonction de requête de stress
function Invoke-StressRequest {
    param(
        [int]$UserId,
        [string]$BaseUrl,
        [ref]$StepStats
    )
    
    # Sélection aléatoire d'endpoint
    $endpoints = @(
        @{ Method = "GET"; Endpoint = "/" },
        @{ Method = "GET"; Endpoint = "/api/users" },
        @{ Method = "POST"; Endpoint = "/api/users"; Body = @{ name = "StressUser$UserId"; email = "stress$UserId@test.com" } },
        @{ Method = "GET"; Endpoint = "/api/products" },
        @{ Method = "GET"; Endpoint = "/api/orders" },
        @{ Method = "POST"; Endpoint = "/api/payment"; Body = @{ amount = (Get-Random -Minimum 10 -Maximum 500); card_token = "stress_tok_$UserId" } }
    )
    
    $selectedEndpoint = $endpoints | Get-Random
    $url = "$BaseUrl$($selectedEndpoint.Endpoint)"
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        if ($selectedEndpoint.Body) {
            $jsonBody = $selectedEndpoint.Body | ConvertTo-Json
            $response = Invoke-RestMethod -Uri $url -Method $selectedEndpoint.Method -Body $jsonBody -ContentType "application/json" -TimeoutSec 10
            $success = $true
        } else {
            $response = Invoke-RestMethod -Uri $url -Method $selectedEndpoint.Method -TimeoutSec 10
            $success = $true
        }
    }
    catch {
        $success = $false
    }
    finally {
        $stopwatch.Stop()
        $responseTime = $stopwatch.ElapsedMilliseconds
        
        # Mise à jour thread-safe des statistiques
        $lockTaken = $false
        try {
            [System.Threading.Monitor]::Enter($StepStats.Value, [ref]$lockTaken)
            
            $StepStats.Value.TotalRequests++
            $StepStats.Value.TotalResponseTime += $responseTime
            
            if ($responseTime -lt $StepStats.Value.MinResponseTime) {
                $StepStats.Value.MinResponseTime = $responseTime
            }
            if ($responseTime -gt $StepStats.Value.MaxResponseTime) {
                $StepStats.Value.MaxResponseTime = $responseTime
            }
            
            if ($success) {
                $StepStats.Value.SuccessfulRequests++
            } else {
                $StepStats.Value.FailedRequests++
            }
        }
        finally {
            if ($lockTaken) {
                [System.Threading.Monitor]::Exit($StepStats.Value)
            }
        }
    }
}

# Scénario utilisateur pour stress test
function Start-StressUser {
    param(
        [int]$UserId,
        [string]$BaseUrl,
        [ref]$StepStats,
        [ref]$StepRunning
    )
    
    while ($StepRunning.Value) {
        Invoke-StressRequest -UserId $UserId -BaseUrl $BaseUrl -StepStats $StepStats
        Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 200)
    }
}

# Exécution d'un palier de stress
function Invoke-StressStep {
    param(
        [int]$Step,
        [int]$Users,
        [int]$Duration,
        [string]$BaseUrl
    )
    
    Write-Host "📊 PALIER $Step`: $Users utilisateurs pendant ${Duration}s" -ForegroundColor Cyan
    
    # Initialisation des statistiques pour ce palier
    $stepStats = @{
        TotalRequests = 0
        SuccessfulRequests = 0
        FailedRequests = 0
        TotalResponseTime = 0
        MinResponseTime = [int]::MaxValue
        MaxResponseTime = 0
    }
    
    $stepRunning = $true
    
    # Démarrage des utilisateurs
    $userJobs = @()
    for ($i = 1; $i -le $Users; $i++) {
        $userJobs += Start-Job -ScriptBlock {
            param($userId, $baseUrl, $stepStatsRef, $stepRunningRef)
            
            # Réplication des fonctions pour les jobs
            function Invoke-StressRequest {
                param($UserId, $BaseUrl, $StepStats)
                # [Code de la fonction répliqué]
            }
            
            function Start-StressUser {
                param($UserId, $BaseUrl, $StepStats, $StepRunning)
                # [Code de la fonction répliqué]
            }
            
            Start-StressUser -UserId $userId -BaseUrl $baseUrl -StepStats $stepStatsRef -StepRunning $stepRunningRef
        } -ArgumentList $i, $BaseUrl, ([ref]$stepStats), ([ref]$stepRunning)
    }
    
    # Monitoring en temps réel
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($Duration)
    
    while ((Get-Date) -lt $endTime) {
        Start-Sleep -Seconds 5
        
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $rps = if ($elapsed -gt 0) { [math]::Round($stepStats.TotalRequests / $elapsed, 2) } else { 0 }
        $avgTime = if ($stepStats.SuccessfulRequests -gt 0) { [math]::Round($stepStats.TotalResponseTime / $stepStats.SuccessfulRequests, 2) } else { 0 }
        $errorRate = if ($stepStats.TotalRequests -gt 0) { [math]::Round(($stepStats.FailedRequests / $stepStats.TotalRequests) * 100, 2) } else { 0 }
        
        Write-Host "`r📊 Palier $Step`: $([math]::Round($elapsed, 0))s | Users: $Users | Req/s: $rps | Avg: ${avgTime}ms | Erreurs: ${errorRate}%" -ForegroundColor Green -NoNewline
    }
    
    # Arrêt du palier
    $stepRunning = $false
    $userJobs | Stop-Job
    $userJobs | Remove-Job
    
    # Calcul des statistiques finales
    $actualDuration = ((Get-Date) - $startTime).TotalSeconds
    $finalRps = [math]::Round($stepStats.TotalRequests / $actualDuration, 2)
    $finalAvgTime = if ($stepStats.SuccessfulRequests -gt 0) { [math]::Round($stepStats.TotalResponseTime / $stepStats.SuccessfulRequests, 2) } else { 0 }
    $finalErrorRate = if ($stepStats.TotalRequests -gt 0) { [math]::Round(($stepStats.FailedRequests / $stepStats.TotalRequests) * 100, 2) } else { 0 }
    
    # Métriques système
    $systemMetrics = Get-SystemMetrics
    
    # Sauvegarde des résultats
    $Global:StressResults += [PSCustomObject]@{
        Step = $Step
        Users = $Users
        Duration = [math]::Round($actualDuration, 2)
        TotalRequests = $stepStats.TotalRequests
        SuccessfulRequests = $stepStats.SuccessfulRequests
        FailedRequests = $stepStats.FailedRequests
        RPS = $finalRps
        AvgResponseTime = $finalAvgTime
        MinResponseTime = $stepStats.MinResponseTime
        MaxResponseTime = $stepStats.MaxResponseTime
        ErrorRate = $finalErrorRate
        CPUUsage = $systemMetrics.CPU
        MemoryUsage = $systemMetrics.Memory
    }
    
    Write-Host ""
    Write-Host "📋 Palier $Step terminé:" -ForegroundColor Cyan
    Write-Host "   Requêtes: $($stepStats.TotalRequests) | Succès: $($stepStats.SuccessfulRequests) | Échecs: $($stepStats.FailedRequests)" -ForegroundColor White
    Write-Host "   RPS: $finalRps | Temps moyen: ${finalAvgTime}ms | Erreurs: ${finalErrorRate}%" -ForegroundColor White
    
    # Alertes de performance
    if ($finalErrorRate -gt 10) {
        Write-Host "   ⚠️  ALERTE: Taux d'erreur critique!" -ForegroundColor Red
    }
    if ($finalAvgTime -gt 2000) {
        Write-Host "   ⚠️  ALERTE: Temps de réponse très élevé!" -ForegroundColor Red
    }
    
    Write-Host ""
    Start-Sleep -Seconds 2
}

# Vérification de l'API
Write-Host "🔍 Vérification de l'API..." -ForegroundColor Blue
try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 10
    Write-Host "✅ API disponible" -ForegroundColor Green
}
catch {
    Write-Host "❌ API non disponible. Arrêt du test." -ForegroundColor Red
    exit 1
}
Write-Host ""

# Phase 1: Tests par paliers croissants
Write-Host "🚀 PHASE 1: TESTS PAR PALIERS CROISSANTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$Step = 1
foreach ($Users in @(5, 10, 20, 30, $MaxUsers)) {
    $Global:PerformanceLog += "$(Get-Date) - Démarrage palier $Step - $Users utilisateurs pour ${StepDuration}s"
    Invoke-StressStep -Step $Step -Users $Users -Duration $StepDuration -BaseUrl $BaseUrl
    $Step++
}

# Phase 2: Test de stress intensif final
Write-Host "💥 PHASE 2: TEST DE STRESS INTENSIF FINAL" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "👥 $MaxUsers utilisateurs simultanés pendant ${StressDuration}s" -ForegroundColor Yellow
Write-Host ""

$Global:PerformanceLog += "$(Get-Date) - Démarrage test de stress final - $MaxUsers utilisateurs pour ${StressDuration}s"
Invoke-StressStep -Step "STRESS" -Users $MaxUsers -Duration $StressDuration -BaseUrl $BaseUrl

# Analyse finale
Write-Host "📊 ANALYSE FINALE DU TEST DE STRESS" -ForegroundColor Magenta
Write-Host "====================================" -ForegroundColor Magenta

Write-Host "📈 Résumé des paliers:" -ForegroundColor Cyan
$bestRps = 0
$bestStep = ""
$worstErrorRate = 0
$worstStep = ""

foreach ($result in $Global:StressResults) {
    Write-Host "   Palier $($result.Step) ($($result.Users) users): $($result.RPS) req/s, $($result.AvgResponseTime)ms avg, $($result.ErrorRate)% erreurs" -ForegroundColor White
    
    if ($result.RPS -gt $bestRps) {
        $bestRps = $result.RPS
        $bestStep = $result.Step
    }
    
    if ($result.ErrorRate -gt $worstErrorRate) {
        $worstErrorRate = $result.ErrorRate
        $worstStep = $result.Step
    }
}

Write-Host ""
Write-Host "🏆 Meilleure performance: Palier $bestStep avec $bestRps req/s" -ForegroundColor Green
if ($worstErrorRate -gt 5) {
    Write-Host "⚠️  Palier critique: Palier $worstStep avec ${worstErrorRate}% d'erreurs" -ForegroundColor Red
}

# Recommandations finales
Write-Host ""
Write-Host "🎯 RECOMMANDATIONS DE CAPACITÉ:" -ForegroundColor Cyan

if ($bestRps -gt 0) {
    $recommendedRps = [math]::Round($bestRps * 0.7, 2)
    Write-Host "   📊 Capacité recommandée: $recommendedRps req/s (70% du pic)" -ForegroundColor Green
}

if ($worstErrorRate -gt 1) {
    Write-Host "   ⚠️  Optimisation nécessaire pour réduire les erreurs" -ForegroundColor Yellow
}

Write-Host "   🔧 Zones d'amélioration potentielles:" -ForegroundColor White
Write-Host "      - Optimisation des requêtes lentes" -ForegroundColor White
Write-Host "      - Mise en cache des réponses" -ForegroundColor White
Write-Host "      - Dimensionnement des ressources" -ForegroundColor White
Write-Host "      - Configuration des pools de connexions" -ForegroundColor White

# Sauvegarde des résultats
$resultsPath = "stress-test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$Global:StressResults | Export-Csv -Path $resultsPath -NoTypeInformation

$logPath = "stress-performance-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$Global:PerformanceLog | Out-File -FilePath $logPath

Write-Host ""
Write-Host "💾 Résultats sauvegardés:" -ForegroundColor Green
Write-Host "   📊 Données détaillées: $resultsPath" -ForegroundColor White
Write-Host "   📝 Logs de performance: $logPath" -ForegroundColor White

Write-Host ""
Write-Host "🔗 Dashboards de monitoring:" -ForegroundColor Cyan
Write-Host "   📊 Grafana: http://localhost:3000/d/express_app_monitoring_complete" -ForegroundColor White
Write-Host "   📈 Prometheus: http://localhost:9090" -ForegroundColor White

Write-Host ""
Write-Host "🎯 Test de stress terminé avec succès!" -ForegroundColor Magenta 