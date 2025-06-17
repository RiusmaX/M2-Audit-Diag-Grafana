#!/usr/bin/env pwsh

<#
.SYNOPSIS
Script PowerShell pour exécuter les tests Gatling JavaScript universels

.DESCRIPTION
Ce script permet d'exécuter facilement les tests de performance Gatling JavaScript
pour n'importe quelle URL avec des configurations personnalisables.

.PARAMETER TargetUrl
URL cible à tester (défaut: http://localhost:3001)

.PARAMETER Endpoints
Liste des endpoints séparés par des virgules (défaut: /)

.PARAMETER HttpMethods
Méthodes HTTP séparées par des virgules (défaut: GET)

.PARAMETER BaseUsers
Nombre d'utilisateurs de base (défaut: 5)

.PARAMETER MaxUsers
Nombre maximum d'utilisateurs (défaut: 50)

.PARAMETER TestDuration
Durée du test en secondes (défaut: 60)

.PARAMETER EnableStress
Active le test de stress (défaut: false)

.PARAMETER Debug
Active le mode debug (défaut: false)

.PARAMETER Headers
Headers HTTP personnalisés au format JSON

.PARAMETER Setup
Installe les dépendances Gatling JS

.EXAMPLE
.\run-gatling-js.ps1 -TargetUrl "https://api.exemple.com" -Endpoints "/users,/products" -HttpMethods "GET,POST"

.EXAMPLE
.\run-gatling-js.ps1 -Setup

.EXAMPLE
.\run-gatling-js.ps1 -TargetUrl "http://localhost:3001" -EnableStress -Debug
#>

param(
    [string]$TargetUrl = "http://localhost:3001",
    [string]$Endpoints = "/",
    [string]$HttpMethods = "GET",
    [int]$BaseUsers = 5,
    [int]$MaxUsers = 50,
    [int]$TestDuration = 60,
    [int]$RampDuration = 30,
    [int]$ThinkTime = 1,
    [string]$Headers = "{}",
    [int]$RequestTimeout = 10000,
    [switch]$EnableStress,
    [switch]$Debug,
    [switch]$Setup,
    [switch]$Help
)

# Couleurs pour l'affichage
$RED = "`e[31m"
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$MAGENTA = "`e[35m"
$CYAN = "`e[36m"
$NC = "`e[0m" # No Color

function Write-ColoredOutput {
    param([string]$Message, [string]$Color = $NC)
    Write-Host "${Color}${Message}${NC}"
}

function Show-Help {
    Write-ColoredOutput "🚀 Gatling JavaScript Universal Tester" $CYAN
    Write-ColoredOutput "=======================================" $CYAN
    Write-Host ""
    Write-ColoredOutput "UTILISATION:" $YELLOW
    Write-Host "  .\run-gatling-js.ps1 [OPTIONS]"
    Write-Host ""
    Write-ColoredOutput "OPTIONS PRINCIPALES:" $YELLOW
    Write-Host "  -TargetUrl <url>        URL cible à tester"
    Write-Host "  -Endpoints <list>       Endpoints séparés par virgules"
    Write-Host "  -HttpMethods <list>     Méthodes HTTP (GET,POST,PUT,DELETE,PATCH)"
    Write-Host "  -BaseUsers <number>     Nombre d'utilisateurs de base"
    Write-Host "  -MaxUsers <number>      Nombre maximum d'utilisateurs"
    Write-Host "  -TestDuration <sec>     Durée du test en secondes"
    Write-Host "  -EnableStress           Active le test de stress"
    Write-Host "  -Debug                  Active le mode debug"
    Write-Host "  -Setup                  Installe les dépendances"
    Write-Host ""
    Write-ColoredOutput "EXEMPLES:" $YELLOW
    Write-Host "  # Test simple"
    Write-Host "  .\run-gatling-js.ps1 -TargetUrl 'https://api.exemple.com'"
    Write-Host ""
    Write-Host "  # Test multi-endpoints"
    Write-Host "  .\run-gatling-js.ps1 -TargetUrl 'http://localhost:3001' -Endpoints '/,/api/users,/api/products'"
    Write-Host ""
    Write-Host "  # Test de stress"
    Write-Host "  .\run-gatling-js.ps1 -TargetUrl 'http://localhost:3001' -EnableStress -MaxUsers 100"
    Write-Host ""
    Write-Host "  # Installation"
    Write-Host "  .\run-gatling-js.ps1 -Setup"
}

function Test-Prerequisites {
    Write-ColoredOutput "🔍 Vérification des prérequis..." $BLUE
    
    # Vérifier Node.js
    try {
        $nodeVersion = node --version
        Write-ColoredOutput "✅ Node.js détecté: $nodeVersion" $GREEN
    } catch {
        Write-ColoredOutput "❌ Node.js n'est pas installé!" $RED
        Write-ColoredOutput "Installez Node.js depuis https://nodejs.org/" $YELLOW
        return $false
    }
    
    # Vérifier npm
    try {
        $npmVersion = npm --version
        Write-ColoredOutput "✅ npm détecté: $npmVersion" $GREEN
    } catch {
        Write-ColoredOutput "❌ npm n'est pas disponible!" $RED
        return $false
    }
    
    return $true
}

function Install-Dependencies {
    Write-ColoredOutput "📦 Installation des dépendances Gatling JavaScript..." $BLUE
    
    if (!(Test-Path "package.json")) {
        Write-ColoredOutput "❌ Fichier package.json non trouvé!" $RED
        return $false
    }
    
    try {
        Write-ColoredOutput "Installation des packages npm..." $YELLOW
        npm install
        
        Write-ColoredOutput "Installation de Gatling CLI globalement..." $YELLOW
        npm install -g @gatling.io/cli
        
        Write-ColoredOutput "✅ Installation terminée!" $GREEN
        return $true
    } catch {
        Write-ColoredOutput "❌ Erreur lors de l'installation: $_" $RED
        return $false
    }
}

function Test-TargetUrl {
    param([string]$Url)
    
    Write-ColoredOutput "🌐 Test de connectivité vers $Url..." $BLUE
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method HEAD -TimeoutSec 10 -UseBasicParsing
        Write-ColoredOutput "✅ URL accessible (Status: $($response.StatusCode))" $GREEN
        return $true
    } catch {
        Write-ColoredOutput "⚠️  URL non accessible ou timeout: $_" $YELLOW
        Write-ColoredOutput "Le test continuera quand même..." $YELLOW
        return $true # On continue même si l'URL n'est pas accessible
    }
}

function Start-GatlingTest {
    Write-ColoredOutput "🚀 Démarrage du test Gatling JavaScript..." $CYAN
    Write-ColoredOutput "=========================================" $CYAN
    
    # Configuration des variables d'environnement
    $env:TARGET_URL = $TargetUrl
    $env:ENDPOINTS = $Endpoints
    $env:HTTP_METHODS = $HttpMethods
    $env:BASE_USERS = $BaseUsers.ToString()
    $env:MAX_USERS = $MaxUsers.ToString()
    $env:TEST_DURATION = $TestDuration.ToString()
    $env:RAMP_DURATION = $RampDuration.ToString()
    $env:THINK_TIME = $ThinkTime.ToString()
    $env:HEADERS = $Headers
    $env:REQUEST_TIMEOUT = $RequestTimeout.ToString()
    $env:ENABLE_STRESS = if ($EnableStress) { "true" } else { "false" }
    $env:DEBUG = if ($Debug) { "true" } else { "false" }
    
    Write-ColoredOutput "Configuration du test:" $YELLOW
    Write-Host "  URL cible: $TargetUrl"
    Write-Host "  Endpoints: $Endpoints"
    Write-Host "  Méthodes HTTP: $HttpMethods"
    Write-Host "  Utilisateurs base/max: $BaseUsers/$MaxUsers"
    Write-Host "  Durée: $TestDuration secondes"
    Write-Host "  Test de stress: $(if ($EnableStress) { 'Activé' } else { 'Désactivé' })"
    Write-Host "  Mode debug: $(if ($Debug) { 'Activé' } else { 'Désactivé' })"
    Write-Host ""
    
    $startTime = Get-Date
    Write-ColoredOutput "⏱️  Début du test: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" $BLUE
    
    try {
        # Exécution du test Gatling
        gatling run --simulation gatling-js-universal-test.js
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-ColoredOutput "✅ Test terminé avec succès!" $GREEN
        Write-ColoredOutput "⏱️  Durée totale: $($duration.ToString('mm\:ss'))" $BLUE
        
        # Recherche du répertoire de résultats
        $resultsDir = Get-ChildItem -Path "results" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($resultsDir) {
            $reportPath = Join-Path $resultsDir.FullName "index.html"
            if (Test-Path $reportPath) {
                Write-ColoredOutput "📊 Rapport disponible: $reportPath" $CYAN
                Write-ColoredOutput "💡 Ouvrir le rapport: start '$reportPath'" $YELLOW
            }
        }
        
    } catch {
        Write-ColoredOutput "❌ Erreur lors de l'exécution: $_" $RED
        return $false
    }
    
    return $true
}

function Show-Summary {
    Write-ColoredOutput "`n📋 RÉSUMÉ DU TEST" $CYAN
    Write-ColoredOutput "=================" $CYAN
    Write-Host "  URL testée: $TargetUrl"
    Write-Host "  Endpoints: $Endpoints"
    Write-Host "  Méthodes: $HttpMethods"
    Write-Host "  Charge: $BaseUsers → $MaxUsers utilisateurs"
    Write-Host "  Durée: $TestDuration secondes"
    Write-Host "  Stress test: $(if ($EnableStress) { 'Oui' } else { 'Non' })"
    Write-Host ""
    Write-ColoredOutput "💡 Conseils:" $YELLOW
    Write-Host "  • Analysez le rapport HTML généré"
    Write-Host "  • Vérifiez les temps de réponse et taux d'erreur"
    Write-Host "  • Ajustez les paramètres selon les résultats"
    Write-Host "  • Utilisez -Debug pour plus de détails"
}

# ============================================================================
# SCRIPT PRINCIPAL
# ============================================================================

if ($Help) {
    Show-Help
    exit 0
}

Write-ColoredOutput "🚀 Gatling JavaScript Universal Tester" $CYAN
Write-ColoredOutput "=======================================" $CYAN

# Vérification des prérequis
if (!(Test-Prerequisites)) {
    exit 1
}

# Installation si demandée
if ($Setup) {
    if (Install-Dependencies) {
        Write-ColoredOutput "`n✅ Installation terminée! Vous pouvez maintenant lancer des tests." $GREEN
        Show-Help
    } else {
        Write-ColoredOutput "`n❌ Échec de l'installation." $RED
        exit 1
    }
    exit 0
}

# Vérification de l'existence du script de test
if (!(Test-Path "gatling-js-universal-test.js")) {
    Write-ColoredOutput "❌ Script de test 'gatling-js-universal-test.js' non trouvé!" $RED
    Write-ColoredOutput "Assurez-vous d'être dans le bon répertoire." $YELLOW
    exit 1
}

# Test de connectivité
Test-TargetUrl -Url $TargetUrl

# Démarrage du test
if (Start-GatlingTest) {
    Show-Summary
    Write-ColoredOutput "`n🎉 Test terminé avec succès!" $GREEN
} else {
    Write-ColoredOutput "`n❌ Le test a échoué." $RED
    exit 1
} 