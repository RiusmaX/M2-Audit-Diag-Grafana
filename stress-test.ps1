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

# Fonction de requête de stress simplifiée
function Invoke-StressRequest {
    param(
        [int]$UserId,
        [string]$BaseUrl
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
    $success = $false
    
    try {
        if ($selectedEndpoint.Body) {
            $jsonBody = $selectedEndpoint.Body | ConvertTo-Json
            $response = Invoke-RestMethod -Uri $url -Method $selectedEndpoint.Method -Body $jsonBody -ContentType "application/json" -TimeoutSec 10
        } else {
            $response = Invoke-RestMethod -Uri $url -Method $selectedEndpoint.Method -TimeoutSec 10
        }
        $success = $true
    }
    catch {
        $success = $false
    }
    finally {
        $stopwatch.Stop()
    }
    
    return @{
        Success = $success
        ResponseTime = $stopwatch.ElapsedMilliseconds
        Endpoint = $selectedEndpoint.Endpoint
        Method = $selectedEndpoint.Method
    }
}

# Exécution d'un palier de stress avec une approche synchrone
function Invoke-StressStep {
    param(
        [int]$Step,
        [int]$Users,
        [int]$Duration,
        [string]$BaseUrl
    )
    
    Write-Host "📊 PALIER $Step`: $Users utilisateurs pendant ${Duration}s" -ForegroundColor Cyan
    
    # Initialisation des statistiques
    $totalRequests = 0
    $successfulRequests = 0
    $failedRequests = 0
    $totalResponseTime = 0
    $minResponseTime = [int]::MaxValue
    $maxResponseTime = 0
    
    # Variables de contrôle
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($Duration)
    $testRunning = $true
    
    # Fichier temporaire pour le contrôle des threads
    $controlFile = "stress-control-$Step.tmp"
    "RUNNING" | Out-File -FilePath $controlFile
    
    # Démarrage des jobs utilisateurs avec script complet
    $userJobs = @()
    for ($i = 1; $i -le $Users; $i++) {
        $userJobs += Start-Job -ScriptBlock {
            param($userId, $baseUrl, $controlFilePath)
            
            # Fonction de requête dans le job
            function Invoke-JobStressRequest {
                param($UserId, $BaseUrl)
                
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
                $success = $false
                
                try {
                    if ($selectedEndpoint.Body) {
                        $jsonBody = $selectedEndpoint.Body | ConvertTo-Json
                        Invoke-RestMethod -Uri $url -Method $selectedEndpoint.Method -Body $jsonBody -ContentType "application/json" -TimeoutSec 10 | Out-Null
                    } else {
                        Invoke-RestMethod -Uri $url -Method $selectedEndpoint.Method -TimeoutSec 10 | Out-Null
                    }
                    $success = $true
                }
                catch {
                    $success = $false
                }
                finally {
                    $stopwatch.Stop()
                }
                
                return @{
                    Success = $success
                    ResponseTime = $stopwatch.ElapsedMilliseconds
                    Timestamp = Get-Date
                }
            }
            
            # Boucle principale du job
            $results = @()
            while ((Test-Path $controlFilePath) -and ((Get-Content $controlFilePath) -eq "RUNNING")) {
                $result = Invoke-JobStressRequest -UserId $userId -BaseUrl $baseUrl
                $results += $result
                
                # Pause aléatoire
                Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 200)
            }
            
            return $results
        } -ArgumentList $i, $BaseUrl, $controlFile
    }
    
    # Monitoring en temps réel
    while ((Get-Date) -lt $endTime) {
        Start-Sleep -Seconds 5
        
        # Collecte des résultats partiels des jobs en cours
        $partialResults = @()
        foreach ($job in $userJobs) {
            if ($job.State -eq "Running") {
                try {
                    $jobResults = Receive-Job -Job $job -Keep
                    if ($jobResults) {
                        $partialResults += $jobResults
                    }
                }
                catch {
                    # Ignore les erreurs de lecture partielle
                }
            }
        }
        
        # Calcul des métriques en temps réel
        if ($partialResults.Count -gt 0) {
            $totalRequests = $partialResults.Count
            $successfulRequests = ($partialResults | Where-Object { $_.Success }).Count
            $failedRequests = $totalRequests - $successfulRequests
            
            if ($successfulRequests -gt 0) {
                $successfulResults = $partialResults | Where-Object { $_.Success }
                $totalResponseTime = ($successfulResults | Measure-Object -Property ResponseTime -Sum).Sum
                $minResponseTime = ($successfulResults | Measure-Object -Property ResponseTime -Minimum).Minimum
                $maxResponseTime = ($successfulResults | Measure-Object -Property ResponseTime -Maximum).Maximum
            }
        }
        
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $rps = if ($elapsed -gt 0) { [math]::Round($totalRequests / $elapsed, 2) } else { 0 }
        $avgTime = if ($successfulRequests -gt 0) { [math]::Round($totalResponseTime / $successfulRequests, 2) } else { 0 }
        $errorRate = if ($totalRequests -gt 0) { [math]::Round(($failedRequests / $totalRequests) * 100, 2) } else { 0 }
        
        Write-Host "`r📊 Palier $Step`: $([math]::Round($elapsed, 0))s | Users: $Users | Req/s: $rps | Avg: ${avgTime}ms | Erreurs: ${errorRate}%" -ForegroundColor Green -NoNewline
    }
    
    # Arrêt du palier
    "STOPPED" | Out-File -FilePath $controlFile
    
    # Collecte des résultats finaux
    $allResults = @()
    foreach ($job in $userJobs) {
        try {
            $jobResults = Receive-Job -Job $job -Wait
            if ($jobResults) {
                $allResults += $jobResults
            }
        }
        catch {
            Write-Host "`n⚠️  Erreur lors de la collecte des résultats du job: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        Remove-Job -Job $job -Force
    }
    
    # Nettoyage
    Remove-Item -Path $controlFile -Force -ErrorAction SilentlyContinue
    
    # Calcul des statistiques finales
    if ($allResults.Count -gt 0) {
        $totalRequests = $allResults.Count
        $successfulRequests = ($allResults | Where-Object { $_.Success }).Count
        $failedRequests = $totalRequests - $successfulRequests
        
        if ($successfulRequests -gt 0) {
            $successfulResults = $allResults | Where-Object { $_.Success }
            $totalResponseTime = ($successfulResults | Measure-Object -Property ResponseTime -Sum).Sum
            $minResponseTime = ($successfulResults | Measure-Object -Property ResponseTime -Minimum).Minimum
            $maxResponseTime = ($successfulResults | Measure-Object -Property ResponseTime -Maximum).Maximum
        }
    }
    
    $actualDuration = ((Get-Date) - $startTime).TotalSeconds
    $finalRps = if ($actualDuration -gt 0) { [math]::Round($totalRequests / $actualDuration, 2) } else { 0 }
    $finalAvgTime = if ($successfulRequests -gt 0) { [math]::Round($totalResponseTime / $successfulRequests, 2) } else { 0 }
    $finalErrorRate = if ($totalRequests -gt 0) { [math]::Round(($failedRequests / $totalRequests) * 100, 2) } else { 0 }
    
    # Métriques système
    $systemMetrics = Get-SystemMetrics
    
    # Sauvegarde des résultats
    $Global:StressResults += [PSCustomObject]@{
        Step = $Step
        Users = $Users
        Duration = [math]::Round($actualDuration, 2)
        TotalRequests = $totalRequests
        SuccessfulRequests = $successfulRequests
        FailedRequests = $failedRequests
        RPS = $finalRps
        AvgResponseTime = $finalAvgTime
        MinResponseTime = if ($minResponseTime -eq [int]::MaxValue) { 0 } else { $minResponseTime }
        MaxResponseTime = $maxResponseTime
        ErrorRate = $finalErrorRate
        CPUUsage = $systemMetrics.CPU
        MemoryUsage = $systemMetrics.Memory
    }
    
    Write-Host ""
    Write-Host "📋 Palier $Step terminé:" -ForegroundColor Cyan
    Write-Host "   Requêtes: $totalRequests | Succès: $successfulRequests | Échecs: $failedRequests" -ForegroundColor White
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
    Write-Host "💡 Assurez-vous que l'API Express est démarrée avec: docker-compose up" -ForegroundColor Yellow
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
if ($bestRps -gt 0) {
    Write-Host "🏆 Meilleure performance: Palier $bestStep avec $bestRps req/s" -ForegroundColor Green
} else {
    Write-Host "⚠️  Aucune requête réussie détectée" -ForegroundColor Red
}

if ($worstErrorRate -gt 5) {
    Write-Host "⚠️  Palier critique: Palier $worstStep avec ${worstErrorRate}% d'erreurs" -ForegroundColor Red
}

# Recommandations finales
Write-Host ""
Write-Host "🎯 RECOMMANDATIONS DE CAPACITÉ:" -ForegroundColor Cyan

if ($bestRps -gt 0) {
    $recommendedRps = [math]::Round($bestRps * 0.7, 2)
    Write-Host "   📊 Capacité recommandée: $recommendedRps req/s (70% du pic)" -ForegroundColor Green
} else {
    Write-Host "   ❌ Impossible de déterminer la capacité - Aucune requête réussie" -ForegroundColor Red
    Write-Host "   💡 Vérifiez que l'API fonctionne correctement" -ForegroundColor Yellow
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