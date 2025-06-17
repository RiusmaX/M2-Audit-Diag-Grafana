# Script PowerShell - Comparaison des Résultats de Tests de Charge
# Analyse et compare les performances entre plusieurs tests

param(
    [string[]]$TestFiles = @(),
    [string]$OutputPath = "comparison-report.html"
)

Write-Host "📊 ANALYSEUR DE RÉSULTATS DE TESTS DE CHARGE" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if ($TestFiles.Count -eq 0) {
    # Auto-découverte des fichiers de résultats
    $TestFiles = Get-ChildItem -Path "." -Filter "*load-test-*.csv" | Select-Object -ExpandProperty Name
    $TestFiles += Get-ChildItem -Path "." -Filter "*stress-test-*.csv" | Select-Object -ExpandProperty Name
}

if ($TestFiles.Count -eq 0) {
    Write-Host "❌ Aucun fichier de résultats trouvé." -ForegroundColor Red
    Write-Host "💡 Exécutez d'abord des tests de charge pour générer des données." -ForegroundColor Yellow
    exit 1
}

Write-Host "📁 Fichiers de résultats trouvés: $($TestFiles.Count)" -ForegroundColor Green
foreach ($file in $TestFiles) {
    Write-Host "   📄 $file" -ForegroundColor White
}
Write-Host ""

# Structure pour stocker toutes les données
$AllResults = @()

# Lecture et parsing des fichiers CSV
foreach ($file in $TestFiles) {
    if (Test-Path $file) {
        try {
            $data = Import-Csv $file
            $fileInfo = Get-Item $file
            
            foreach ($row in $data) {
                $AllResults += [PSCustomObject]@{
                    FileName = $file
                    TestDate = $fileInfo.CreationTime
                    TestType = if ($file -like "*stress*") { "Stress" } else { "Load" }
                    Step = $row.Step
                    Users = [int]$row.Users
                    Duration = [double]$row.Duration
                    TotalRequests = [int]$row.TotalRequests
                    SuccessfulRequests = [int]$row.SuccessfulRequests
                    FailedRequests = [int]$row.FailedRequests
                    RPS = [double]$row.RPS
                    AvgResponseTime = [double]$row.AvgResponseTime
                    MinResponseTime = [double]$row.MinResponseTime
                    MaxResponseTime = [double]$row.MaxResponseTime
                    ErrorRate = [double]$row.ErrorRate
                }
            }
            
            Write-Host "✅ Chargé: $file ($($data.Count) enregistrements)" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️  Erreur lors du chargement de $file : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

if ($AllResults.Count -eq 0) {
    Write-Host "❌ Aucune donnée valide trouvée dans les fichiers." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📈 ANALYSE DES PERFORMANCES" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

# Analyse globale
$globalStats = $AllResults | Measure-Object -Property RPS, AvgResponseTime, ErrorRate -Average -Maximum -Minimum

Write-Host "🎯 Statistiques Globales:" -ForegroundColor Yellow
Write-Host "   RPS Moyen: $([math]::Round($globalStats[0].Average, 2)) (Min: $([math]::Round($globalStats[0].Minimum, 2)), Max: $([math]::Round($globalStats[0].Maximum, 2)))" -ForegroundColor White
Write-Host "   Temps de Réponse Moyen: $([math]::Round($globalStats[1].Average, 2))ms (Min: $([math]::Round($globalStats[1].Minimum, 2))ms, Max: $([math]::Round($globalStats[1].Maximum, 2))ms)" -ForegroundColor White
Write-Host "   Taux d'Erreur Moyen: $([math]::Round($globalStats[2].Average, 2))% (Min: $([math]::Round($globalStats[2].Minimum, 2))%, Max: $([math]::Round($globalStats[2].Maximum, 2))%)" -ForegroundColor White
Write-Host ""

# Analyse par type de test
$testTypes = $AllResults | Group-Object TestType

foreach ($testType in $testTypes) {
    Write-Host "📊 Tests de type '$($testType.Name)':" -ForegroundColor Cyan
    
    $typeStats = $testType.Group | Measure-Object -Property RPS, AvgResponseTime, ErrorRate -Average
    Write-Host "   Nombre de tests: $($testType.Count)" -ForegroundColor White
    Write-Host "   RPS Moyen: $([math]::Round($typeStats[0].Average, 2))" -ForegroundColor White
    Write-Host "   Temps Moyen: $([math]::Round($typeStats[1].Average, 2))ms" -ForegroundColor White
    Write-Host "   Erreurs Moyennes: $([math]::Round($typeStats[2].Average, 2))%" -ForegroundColor White
    Write-Host ""
}

# Top des meilleures performances
Write-Host "🏆 TOP 5 - MEILLEURES PERFORMANCES (RPS)" -ForegroundColor Green
$topRPS = $AllResults | Sort-Object RPS -Descending | Select-Object -First 5
foreach ($result in $topRPS) {
    Write-Host "   $($result.RPS) req/s - $($result.Users) users - $($result.FileName)" -ForegroundColor White
}
Write-Host ""

# Top des temps de réponse les plus rapides
Write-Host "⚡ TOP 5 - TEMPS DE RÉPONSE LES PLUS RAPIDES" -ForegroundColor Green
$topSpeed = $AllResults | Sort-Object AvgResponseTime | Select-Object -First 5
foreach ($result in $topSpeed) {
    Write-Host "   $($result.AvgResponseTime)ms - $($result.Users) users - $($result.FileName)" -ForegroundColor White
}
Write-Host ""

# Détection des problèmes
Write-Host "🔍 DÉTECTION DE PROBLÈMES" -ForegroundColor Red
$problems = $AllResults | Where-Object { $_.ErrorRate -gt 5 -or $_.AvgResponseTime -gt 1000 }

if ($problems.Count -gt 0) {
    Write-Host "⚠️  $($problems.Count) tests problématiques détectés:" -ForegroundColor Red
    foreach ($problem in $problems) {
        $issues = @()
        if ($problem.ErrorRate -gt 5) { $issues += "Taux d'erreur élevé ($($problem.ErrorRate)%)" }
        if ($problem.AvgResponseTime -gt 1000) { $issues += "Temps de réponse lent ($($problem.AvgResponseTime)ms)" }
        
        Write-Host "   📄 $($problem.FileName) - $($problem.Users) users: $($issues -join ', ')" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ Aucun problème majeur détecté!" -ForegroundColor Green
}
Write-Host ""

# Analyse de tendances
Write-Host "📈 ANALYSE DE TENDANCES" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

# Tendance par nombre d'utilisateurs
$userGroups = $AllResults | Group-Object Users | Sort-Object Name

Write-Host "📊 Performance par nombre d'utilisateurs:" -ForegroundColor Yellow
foreach ($group in $userGroups) {
    $avgRPS = ($group.Group | Measure-Object RPS -Average).Average
    $avgTime = ($group.Group | Measure-Object AvgResponseTime -Average).Average
    $avgError = ($group.Group | Measure-Object ErrorRate -Average).Average
    
    Write-Host "   $($group.Name) users: $([math]::Round($avgRPS, 2)) req/s, $([math]::Round($avgTime, 2))ms, $([math]::Round($avgError, 2))% erreurs" -ForegroundColor White
}
Write-Host ""

# Recommandations
Write-Host "🎯 RECOMMANDATIONS" -ForegroundColor Magenta
Write-Host "==================" -ForegroundColor Magenta

$bestPerformance = $AllResults | Sort-Object RPS -Descending | Select-Object -First 1
$optimalUsers = $bestPerformance.Users * 0.7

Write-Host "💡 Recommandations basées sur l'analyse:" -ForegroundColor Yellow
Write-Host "   🎯 Nombre optimal d'utilisateurs simultanés: $([math]::Round($optimalUsers, 0))" -ForegroundColor Green
Write-Host "   📊 RPS cible recommandé: $([math]::Round($bestPerformance.RPS * 0.8, 2))" -ForegroundColor Green

if ($globalStats[2].Average -gt 1) {
    Write-Host "   ⚠️  Optimisation nécessaire pour réduire le taux d'erreur" -ForegroundColor Red
}

if ($globalStats[1].Average -gt 500) {
    Write-Host "   ⚠️  Optimisation des temps de réponse recommandée" -ForegroundColor Red
}

# Génération du rapport HTML
Write-Host ""
Write-Host "📄 GÉNÉRATION DU RAPPORT HTML" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Rapport de Comparaison des Tests de Charge</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .metric { display: inline-block; margin: 10px; padding: 15px; background: #ecf0f1; border-radius: 5px; min-width: 150px; text-align: center; }
        .metric-value { font-size: 24px; font-weight: bold; color: #2980b9; }
        .metric-label { font-size: 12px; color: #7f8c8d; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #3498db; color: white; }
        .good { color: #27ae60; font-weight: bold; }
        .warning { color: #f39c12; font-weight: bold; }
        .error { color: #e74c3c; font-weight: bold; }
        .chart { margin: 20px 0; padding: 20px; background: #f8f9fa; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Rapport de Comparaison des Tests de Charge</h1>
        <p><strong>Généré le:</strong> $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')</p>
        <p><strong>Nombre de tests analysés:</strong> $($AllResults.Count)</p>
        
        <h2>🎯 Métriques Globales</h2>
        <div class="metric">
            <div class="metric-value">$([math]::Round($globalStats[0].Average, 2))</div>
            <div class="metric-label">RPS Moyen</div>
        </div>
        <div class="metric">
            <div class="metric-value">$([math]::Round($globalStats[1].Average, 2))ms</div>
            <div class="metric-label">Temps Moyen</div>
        </div>
        <div class="metric">
            <div class="metric-value">$([math]::Round($globalStats[2].Average, 2))%</div>
            <div class="metric-label">Taux d'Erreur</div>
        </div>
        
        <h2>📈 Résultats Détaillés</h2>
        <table>
            <tr>
                <th>Fichier</th>
                <th>Date</th>
                <th>Type</th>
                <th>Utilisateurs</th>
                <th>RPS</th>
                <th>Temps Moyen</th>
                <th>Taux d'Erreur</th>
                <th>Status</th>
            </tr>
"@

foreach ($result in $AllResults | Sort-Object TestDate -Descending) {
    $status = "good"
    $statusText = "✅ Bon"
    
    if ($result.ErrorRate -gt 5 -or $result.AvgResponseTime -gt 1000) {
        $status = "error"
        $statusText = "❌ Problème"
    } elseif ($result.ErrorRate -gt 1 -or $result.AvgResponseTime -gt 500) {
        $status = "warning"
        $statusText = "⚠️ Attention"
    }
    
    $htmlContent += @"
            <tr>
                <td>$($result.FileName)</td>
                <td>$($result.TestDate.ToString('dd/MM HH:mm'))</td>
                <td>$($result.TestType)</td>
                <td>$($result.Users)</td>
                <td>$($result.RPS)</td>
                <td>$($result.AvgResponseTime)ms</td>
                <td>$($result.ErrorRate)%</td>
                <td class="$status">$statusText</td>
            </tr>
"@
}

$htmlContent += @"
        </table>
        
        <h2>🏆 Top Performances</h2>
        <div class="chart">
            <h3>Meilleur RPS: $($topRPS[0].RPS) req/s</h3>
            <p>Obtenu avec $($topRPS[0].Users) utilisateurs dans $($topRPS[0].FileName)</p>
        </div>
        
        <h2>🎯 Recommandations</h2>
        <ul>
            <li><strong>Nombre optimal d'utilisateurs:</strong> $([math]::Round($optimalUsers, 0))</li>
            <li><strong>RPS cible:</strong> $([math]::Round($bestPerformance.RPS * 0.8, 2))</li>
            <li><strong>Seuil d'alerte temps de réponse:</strong> 500ms</li>
            <li><strong>Seuil d'alerte taux d'erreur:</strong> 1%</li>
        </ul>
        
        <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #7f8c8d; text-align: center;">
            <p>Généré par l'Analyseur de Tests de Charge - MyDigitalSchool</p>
        </footer>
    </div>
</body>
</html>
"@

try {
    $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "✅ Rapport HTML généré: $OutputPath" -ForegroundColor Green
    
    # Tentative d'ouverture automatique
    if (Get-Command "start" -ErrorAction SilentlyContinue) {
        Start-Process $OutputPath
        Write-Host "🌐 Rapport ouvert automatiquement dans le navigateur" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "❌ Erreur lors de la génération du rapport: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎯 Analyse terminée avec succès!" -ForegroundColor Magenta
Write-Host "📊 $($AllResults.Count) tests analysés dans $($TestFiles.Count) fichiers" -ForegroundColor White
Write-Host "📄 Rapport disponible: $OutputPath" -ForegroundColor White 