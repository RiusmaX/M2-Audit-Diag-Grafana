# Script PowerShell - Exécution des Tests de Stress Gatling
# Interface simplifiée pour lancer les tests de charge avec Gatling

param(
    [int]$Users = 50,
    [int]$RampDuration = 30,
    [int]$TestDuration = 300,
    [string]$BaseUrl = "http://localhost:3001",
    [switch]$ReportsOnly,
    [switch]$CleanResults
)

Write-Host "🎯 GATLING STRESS TESTING SUITE" -ForegroundColor Magenta
Write-Host "===============================" -ForegroundColor Magenta
Write-Host ""

# Vérification des prérequis
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker n'est pas installé ou accessible." -ForegroundColor Red
    Write-Host "💡 Veuillez installer Docker Desktop." -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command "docker-compose" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Docker Compose n'est pas installé ou accessible." -ForegroundColor Red
    Write-Host "💡 Veuillez installer Docker Compose." -ForegroundColor Yellow
    exit 1
}

# Création des dossiers nécessaires
$directories = @("gatling/results", "gatling/reports", "gatling/user-files/data")
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "📁 Créé: $dir" -ForegroundColor Green
    }
}

# Nettoyage des résultats précédents si demandé
if ($CleanResults) {
    Write-Host "🧹 Nettoyage des résultats précédents..." -ForegroundColor Yellow
    Remove-Item "gatling/results/*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "gatling/reports/*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Nettoyage terminé" -ForegroundColor Green
}

# Mode rapports seulement
if ($ReportsOnly) {
    Write-Host "📊 GÉNÉRATION DES RAPPORTS GATLING" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    
    if (-not (Test-Path "gatling/results/*")) {
        Write-Host "❌ Aucun résultat trouvé dans gatling/results/" -ForegroundColor Red
        Write-Host "💡 Exécutez d'abord des tests pour générer des données." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "📈 Génération des rapports à partir des résultats existants..." -ForegroundColor Blue
    
    try {
        & docker-compose -f docker-compose.gatling.yml --profile reports up gatling-reports
        
        Write-Host ""
        Write-Host "✅ Rapports générés avec succès!" -ForegroundColor Green
        Write-Host "📂 Emplacement: ./gatling/reports/" -ForegroundColor White
        
        # Tenter d'ouvrir le rapport dans le navigateur
        $latestReport = Get-ChildItem "gatling/reports" -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($latestReport) {
            $indexPath = Join-Path $latestReport.FullName "index.html"
            if (Test-Path $indexPath) {
                Write-Host "🌐 Ouverture du rapport dans le navigateur..." -ForegroundColor Cyan
                Start-Process $indexPath
            }
        }
    }
    catch {
        Write-Host "❌ Erreur lors de la génération des rapports: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    exit 0
}

# Vérification de l'API avant les tests
Write-Host "🔍 Vérification de l'API cible..." -ForegroundColor Blue
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 10
    Write-Host "✅ API disponible - Uptime: $([math]::Round($response.uptime, 2))s" -ForegroundColor Green
}
catch {
    Write-Host "❌ API non disponible sur $BaseUrl" -ForegroundColor Red
    Write-Host "💡 Assurez-vous que l'API Express est démarrée:" -ForegroundColor Yellow
    Write-Host "   docker-compose up -d" -ForegroundColor White
    exit 1
}

# Configuration des tests
Write-Host ""
Write-Host "🚀 CONFIGURATION DU TEST DE STRESS" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "👥 Utilisateurs simultanés: $Users" -ForegroundColor Yellow
Write-Host "📈 Durée de montée en charge: $RampDuration secondes" -ForegroundColor Yellow
Write-Host "⏱️  Durée totale du test: $TestDuration secondes" -ForegroundColor Yellow
Write-Host "🎯 URL cible: $BaseUrl" -ForegroundColor Yellow
Write-Host ""

# Estimation de la durée
$estimatedDuration = [math]::Round(($TestDuration + $RampDuration + 60) / 60, 1)
Write-Host "⏰ Durée estimée: $estimatedDuration minutes" -ForegroundColor Magenta

# Demande de confirmation
$confirmation = Read-Host "Voulez-vous continuer? (o/N)"
if ($confirmation -notmatch '^[oOyY]') {
    Write-Host "❌ Test annulé par l'utilisateur." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "🚀 DÉMARRAGE DU TEST DE STRESS GATLING" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green

# Création du fichier d'environnement pour Gatling
$envContent = @"
# Configuration pour les tests Gatling
-Dusers=$Users
-DrampDuration=$RampDuration
-DtestDuration=$TestDuration
-DbaseUrl=$BaseUrl
"@

$envContent | Out-File -FilePath "gatling/.env" -Encoding UTF8

try {
    # Démarrage de Gatling avec Docker Compose
    $startTime = Get-Date
    
    Write-Host "📊 Lancement de Gatling..." -ForegroundColor Blue
    Write-Host "💡 Vous pouvez suivre les métriques en temps réel sur:" -ForegroundColor Cyan
    Write-Host "   📈 Grafana: http://localhost:3000/d/express_app_monitoring_complete" -ForegroundColor White
    Write-Host "   📊 Prometheus: http://localhost:9090" -ForegroundColor White
    Write-Host ""
    
    # Exécution avec passage des variables d'environnement
    $env:JAVA_OPTS = "-Xmx2g -Xms1g -Dusers=$Users -DrampDuration=$RampDuration -DtestDuration=$TestDuration -DbaseUrl=$BaseUrl"
    
    & docker-compose -f docker-compose.gatling.yml up --remove-orphans gatling
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalMinutes
    
    Write-Host ""
    Write-Host "✅ TEST TERMINÉ AVEC SUCCÈS!" -ForegroundColor Green
    Write-Host "⏱️  Durée réelle: $([math]::Round($duration, 1)) minutes" -ForegroundColor White
    
    # Recherche du rapport généré
    $latestResult = Get-ChildItem "gatling/results" -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
    
    if ($latestResult) {
        Write-Host ""
        Write-Host "📊 RÉSULTATS DISPONIBLES" -ForegroundColor Cyan
        Write-Host "========================" -ForegroundColor Cyan
        Write-Host "📂 Données brutes: $($latestResult.FullName)" -ForegroundColor White
        
        # Recherche du fichier de simulation.log pour un résumé rapide
        $logFile = Join-Path $latestResult.FullName "simulation.log"
        if (Test-Path $logFile) {
            Write-Host "📋 Résumé des résultats:" -ForegroundColor Yellow
            
            # Analyse basique du fichier de log
            $logContent = Get-Content $logFile
            $requestCount = ($logContent | Where-Object { $_ -match "^REQUEST" }).Count
            $errorCount = ($logContent | Where-Object { $_ -match "^REQUEST.*KO" }).Count
            $successCount = $requestCount - $errorCount
            
            if ($requestCount -gt 0) {
                $successRate = [math]::Round(($successCount / $requestCount) * 100, 2)
                Write-Host "   📊 Total des requêtes: $requestCount" -ForegroundColor White
                Write-Host "   ✅ Succès: $successCount ($successRate%)" -ForegroundColor Green
                Write-Host "   ❌ Échecs: $errorCount" -ForegroundColor Red
            }
        }
        
        # Génération automatique du rapport HTML
        Write-Host ""
        Write-Host "📈 Génération du rapport HTML..." -ForegroundColor Blue
        
        try {
            $env:JAVA_OPTS = "-Xmx1g"
            & docker run --rm -v "${PWD}/gatling:/opt/gatling" denvazh/gatling:3.9.5 ./bin/gatling.sh -ro "results/$($latestResult.Name)"
            
            $reportPath = "gatling/results/$($latestResult.Name)/index.html"
            if (Test-Path $reportPath) {
                Write-Host "✅ Rapport HTML généré: $reportPath" -ForegroundColor Green
                Write-Host "🌐 Ouverture automatique du rapport..." -ForegroundColor Cyan
                Start-Process (Resolve-Path $reportPath)
            }
        }
        catch {
            Write-Host "⚠️  Impossible de générer automatiquement le rapport HTML" -ForegroundColor Yellow
            Write-Host "💡 Utilisez: ./run-gatling.ps1 -ReportsOnly" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
    Write-Host "💡 COMMANDES UTILES:" -ForegroundColor Cyan
    Write-Host "   📊 Générer rapports: ./run-gatling.ps1 -ReportsOnly" -ForegroundColor White
    Write-Host "   🧹 Nettoyer résultats: ./run-gatling.ps1 -CleanResults" -ForegroundColor White
    Write-Host "   🔄 Relancer test: ./run-gatling.ps1 -Users $Users -TestDuration $TestDuration" -ForegroundColor White
}
catch {
    Write-Host ""
    Write-Host "❌ ERREUR LORS DE L'EXÉCUTION" -ForegroundColor Red
    Write-Host "=============================" -ForegroundColor Red
    Write-Host "Détails: $($_.Exception.Message)" -ForegroundColor Red
    
    Write-Host ""
    Write-Host "🔧 SOLUTIONS POSSIBLES:" -ForegroundColor Yellow
    Write-Host "   1. Vérifiez que Docker est démarré" -ForegroundColor White
    Write-Host "   2. Vérifiez que l'API Express fonctionne" -ForegroundColor White
    Write-Host "   3. Libérez de la mémoire (Gatling utilise 2GB)" -ForegroundColor White
    Write-Host "   4. Vérifiez les logs Docker: docker-compose -f docker-compose.gatling.yml logs" -ForegroundColor White
    
    exit 1
}

Write-Host ""
Write-Host "🎯 Test de stress Gatling terminé!" -ForegroundColor Magenta 