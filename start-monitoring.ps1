# Script PowerShell pour démarrer la stack de monitoring
# Auteur: Assistant IA
# Description: Lance Prometheus, Grafana, Node Exporter et cAdvisor pour monitorer votre PC

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "   STACK DE MONITORING SYSTÈME" -ForegroundColor Yellow
Write-Host "   Prometheus + Grafana + Node Exporter" -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Vérification de Docker
Write-Host "🔍 Vérification de Docker..." -ForegroundColor Blue
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker détecté: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker n'est pas installé ou non accessible" -ForegroundColor Red
    Write-Host "   Veuillez installer Docker Desktop pour Windows" -ForegroundColor Yellow
    pause
    exit 1
}

# Vérification de Docker Compose
try {
    $composeVersion = docker-compose --version
    Write-Host "✅ Docker Compose détecté: $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker Compose n'est pas disponible" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""

# Vérification des ports
Write-Host "🔍 Vérification des ports..." -ForegroundColor Blue
$ports = @(3000, 9090, 9100, 8081, 9093)
$portsInUse = @()

foreach ($port in $ports) {
    $connection = Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue
    if ($connection.TcpTestSucceeded) {
        $portsInUse += $port
    }
}

if ($portsInUse.Count -gt 0) {
    Write-Host "⚠️ Ports déjà utilisés: $($portsInUse -join ', ')" -ForegroundColor Yellow
    $response = Read-Host "Continuer quand même ? (o/N)"
    if ($response -ne 'o' -and $response -ne 'O') {
        exit 1
    }
}

Write-Host ""

# Démarrage de la stack
Write-Host "🚀 Démarrage de la stack de monitoring..." -ForegroundColor Blue
Write-Host ""

try {
    # Construction et démarrage des conteneurs
    docker-compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Stack démarrée avec succès !" -ForegroundColor Green
        Write-Host ""
        
        # Attendre que les services soient prêts
        Write-Host "⏳ Attente du démarrage des services..." -ForegroundColor Blue
        Start-Sleep -Seconds 10
        
        # Affichage du statut
        Write-Host "📊 Statut des conteneurs:" -ForegroundColor Cyan
        docker-compose ps
        
        Write-Host ""
        Write-Host "🌐 ACCÈS AUX INTERFACES:" -ForegroundColor Yellow -BackgroundColor DarkBlue
        Write-Host ""
        Write-Host "   🔹 Grafana (Dashboard):    http://localhost:3000" -ForegroundColor White
        Write-Host "     Identifiants: admin / admin123" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   🔹 Prometheus (Métriques): http://localhost:9090" -ForegroundColor White
        Write-Host "   🔹 Node Exporter:          http://localhost:9100" -ForegroundColor White
        Write-Host "   🔹 cAdvisor (Conteneurs):  http://localhost:8081" -ForegroundColor White
        Write-Host "   🔹 AlertManager:           http://localhost:9093" -ForegroundColor White
        Write-Host ""
        
        # Proposer d'ouvrir Grafana
        $openGrafana = Read-Host "Ouvrir Grafana dans le navigateur ? (O/n)"
        if ($openGrafana -ne 'n' -and $openGrafana -ne 'N') {
            Start-Process "http://localhost:3000"
        }
        
        Write-Host ""
        Write-Host "💡 CONSEILS D'UTILISATION:" -ForegroundColor Cyan
        Write-Host "   • Le dashboard 'Monitoring Système PC' est automatiquement configuré"
        Write-Host "   • Les alertes sont actives pour CPU > 80%, Mémoire > 85%, etc."
        Write-Host "   • Consultez le README.md pour plus d'informations"
        Write-Host ""
        Write-Host "🛑 Pour arrêter la stack:"
        Write-Host "   docker-compose down" -ForegroundColor Yellow
        Write-Host ""
        
    } else {
        Write-Host "❌ Erreur lors du démarrage de la stack" -ForegroundColor Red
        Write-Host "Vérifiez les logs avec: docker-compose logs" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Erreur: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Appuyez sur une touche pour continuer..."
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null 