# 🚀 Guide Gatling JavaScript Universal Tester

## Vue d'ensemble

Ce projet fournit un script Gatling JavaScript universel pour tester n'importe quelle URL ou API avec des configurations flexibles et complètes. Il permet d'effectuer des tests de charge, de performance et de stress de manière simple et configurable.

## 📋 Table des matières

- [Prérequis](#prérequis)
- [Installation](#installation)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Exemples](#exemples)
- [Options avancées](#options-avancées)
- [Analyse des résultats](#analyse-des-résultats)
- [Troubleshooting](#troubleshooting)

## 🔧 Prérequis

### Logiciels requis
- **Node.js** >= 16.0.0
- **npm** (inclus avec Node.js)
- **PowerShell 7+** (Windows) ou **Bash** (Linux/macOS)

### Installation Node.js
```bash
# Windows (via Chocolatey)
choco install nodejs

# macOS (via Homebrew)
brew install node

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

## 📦 Installation

### 1. Installation automatique (recommandée)

**Windows (PowerShell):**
```powershell
.\run-gatling-js.ps1 -Setup
```

**Linux/macOS (Bash):**
```bash
chmod +x run-gatling-js.sh
./run-gatling-js.sh --setup
```

### 2. Installation manuelle

```bash
# Installation des dépendances du projet
npm install

# Installation de Gatling CLI globalement
npm install -g @gatling.io/cli
```

## ⚙️ Configuration

### Variables d'environnement

Le script utilise des variables d'environnement pour la configuration :

| Variable | Description | Défaut | Exemple |
|----------|-------------|---------|---------|
| `TARGET_URL` | URL cible à tester | `http://localhost:3001` | `https://api.exemple.com` |
| `ENDPOINTS` | Endpoints séparés par virgules | `/` | `/,/api/users,/api/products` |
| `HTTP_METHODS` | Méthodes HTTP séparées par virgules | `GET` | `GET,POST,PUT,DELETE` |
| `BASE_USERS` | Nombre d'utilisateurs de base | `5` | `10` |
| `MAX_USERS` | Nombre maximum d'utilisateurs | `50` | `100` |
| `TEST_DURATION` | Durée du test en secondes | `60` | `300` |
| `RAMP_DURATION` | Durée de montée en charge | `30` | `60` |
| `THINK_TIME` | Pause entre requêtes (secondes) | `1` | `2` |
| `HEADERS` | Headers HTTP au format JSON | `{}` | `{"Authorization":"Bearer token"}` |
| `REQUEST_TIMEOUT` | Timeout des requêtes (ms) | `10000` | `5000` |
| `ENABLE_STRESS` | Active le test de stress | `false` | `true` |
| `DEBUG` | Active le mode debug | `false` | `true` |

### Configuration dans le code

Vous pouvez également modifier directement les valeurs par défaut dans `gatling-js-universal-test.js` :

```javascript
const config = {
  targetUrl: process.env.TARGET_URL || 'http://localhost:3001',
  baseUsers: parseInt(process.env.BASE_USERS) || 5,
  maxUsers: parseInt(process.env.MAX_USERS) || 50,
  // ... autres options
};
```

## 🚀 Utilisation

### Syntaxe de base

**Windows (PowerShell):**
```powershell
.\run-gatling-js.ps1 [OPTIONS]
```

**Linux/macOS (Bash):**
```bash
./run-gatling-js.sh [OPTIONS]
```

### Options principales

#### Windows (PowerShell)
```powershell
-TargetUrl <url>        # URL cible
-Endpoints <list>       # Endpoints séparés par virgules
-HttpMethods <list>     # Méthodes HTTP
-BaseUsers <number>     # Utilisateurs de base
-MaxUsers <number>      # Utilisateurs maximum
-TestDuration <sec>     # Durée du test
-EnableStress           # Active le test de stress
-Debug                  # Active le mode debug
-Setup                  # Installation des dépendances
-Help                   # Affiche l'aide
```

#### Linux/macOS (Bash)
```bash
-u, --url <url>         # URL cible
-e, --endpoints <list>  # Endpoints séparés par virgules
-m, --methods <list>    # Méthodes HTTP
-b, --base-users <n>    # Utilisateurs de base
-M, --max-users <n>     # Utilisateurs maximum
-d, --duration <sec>    # Durée du test
-s, --stress            # Active le test de stress
-D, --debug             # Active le mode debug
-S, --setup             # Installation des dépendances
-h, --help              # Affiche l'aide
```

## 📚 Exemples

### 1. Test simple d'une URL

**Windows:**
```powershell
.\run-gatling-js.ps1 -TargetUrl "https://httpbin.org/get"
```

**Linux/macOS:**
```bash
./run-gatling-js.sh -u "https://httpbin.org/get"
```

### 2. Test multi-endpoints d'une API

**Windows:**
```powershell
.\run-gatling-js.ps1 -TargetUrl "http://localhost:3001" -Endpoints "/,/api/users,/api/products,/api/orders" -HttpMethods "GET,POST"
```

**Linux/macOS:**
```bash
./run-gatling-js.sh -u "http://localhost:3001" -e "/,/api/users,/api/products,/api/orders" -m "GET,POST"
```

### 3. Test de charge intensive

**Windows:**
```powershell
.\run-gatling-js.ps1 -TargetUrl "https://api.exemple.com" -BaseUsers 20 -MaxUsers 200 -TestDuration 300
```

**Linux/macOS:**
```bash
./run-gatling-js.sh -u "https://api.exemple.com" -b 20 -M 200 -d 300
```

### 4. Test de stress complet

**Windows:**
```powershell
.\run-gatling-js.ps1 -TargetUrl "http://localhost:3001" -EnableStress -MaxUsers 100 -Debug
```

**Linux/macOS:**
```bash
./run-gatling-js.sh -u "http://localhost:3001" --stress -M 100 --debug
```

### 5. Test avec headers d'authentification

**Windows:**
```powershell
$headers = '{"Authorization":"Bearer your-token","Content-Type":"application/json"}'
.\run-gatling-js.ps1 -TargetUrl "https://api.secure.com" -Headers $headers
```

**Linux/macOS:**
```bash
./run-gatling-js.sh -u "https://api.secure.com" --headers '{"Authorization":"Bearer your-token","Content-Type":"application/json"}'
```

### 6. Test de différentes méthodes HTTP

**Windows:**
```powershell
.\run-gatling-js.ps1 -TargetUrl "https://httpbin.org" -Endpoints "/get,/post,/put,/delete" -HttpMethods "GET,POST,PUT,DELETE"
```

**Linux/macOS:**
```bash
./run-gatling-js.sh -u "https://httpbin.org" -e "/get,/post,/put,/delete" -m "GET,POST,PUT,DELETE"
```

### 7. Test avec variables d'environnement

**Windows:**
```powershell
$env:TARGET_URL="https://api.exemple.com"
$env:BASE_USERS="10"
$env:MAX_USERS="50"
$env:ENABLE_STRESS="true"
.\run-gatling-js.ps1
```

**Linux/macOS:**
```bash
export TARGET_URL="https://api.exemple.com"
export BASE_USERS="10"
export MAX_USERS="50"
export ENABLE_STRESS="true"
./run-gatling-js.sh
```

## 🔧 Options avancées

### Personnalisation du script Gatling

Le fichier `gatling-js-universal-test.js` peut être modifié pour des besoins spécifiques :

#### Ajout de vérifications personnalisées
```javascript
.check(
  status().is(200),
  responseTimeInMillis().lt(5000),
  jsonPath('$.status').is('success'), // Vérification JSON
  header('Content-Type').is('application/json')
)
```

#### Ajout de feeders de données
```javascript
const dataFeeder = [
  { userId: 1, email: 'user1@example.com' },
  { userId: 2, email: 'user2@example.com' },
  { userId: 3, email: 'user3@example.com' }
];

const scenario = scenario('Test avec données')
  .feed(dataFeeder)
  .exec(
    http('Create User')
      .post('/api/users')
      .body('{"userId": "${userId}", "email": "${email}"}')
  );
```

#### Configuration de patterns d'injection complexes
```javascript
// Pattern d'injection par paliers
.injectOpen(
  atOnceUsers(10),
  rampUsersPerSec(1).to(5).during(30),
  constantUsersPerSec(5).during(60),
  rampUsersPerSec(5).to(1).during(30)
)
```

### Scripts de configuration

#### Fichier .env pour les configurations
Créez un fichier `.env` pour stocker vos configurations :

```bash
TARGET_URL=https://api.exemple.com
ENDPOINTS=/,/api/users,/api/products
HTTP_METHODS=GET,POST,PUT
BASE_USERS=10
MAX_USERS=100
TEST_DURATION=300
ENABLE_STRESS=true
DEBUG=false
HEADERS={"Authorization":"Bearer token123"}
```

Puis chargez-le avant d'exécuter le test :

**Windows:**
```powershell
Get-Content .env | ForEach-Object {
  $name, $value = $_.split('=')
  Set-Item "env:$name" $value
}
.\run-gatling-js.ps1
```

**Linux/macOS:**
```bash
export $(cat .env | xargs)
./run-gatling-js.sh
```

## 📊 Analyse des résultats

### Structure des rapports

Après l'exécution, Gatling génère un rapport HTML dans le dossier `results/` :

```
results/
├── simulation-timestamp/
│   ├── index.html              # Rapport principal
│   ├── global_stats.json       # Statistiques globales
│   ├── stats.json              # Statistiques détaillées
│   └── assertions.json         # Résultats des assertions
```

### Métriques importantes

#### 1. Temps de réponse
- **Mean** : Temps de réponse moyen
- **95th percentile** : 95% des requêtes sont plus rapides
- **99th percentile** : 99% des requêtes sont plus rapides
- **Max** : Temps de réponse maximum

#### 2. Throughput (Débit)
- **Requests/sec** : Nombre de requêtes par seconde
- **Peak RPS** : Pic de requêtes par seconde

#### 3. Taux d'erreur
- **Success rate** : Pourcentage de requêtes réussies
- **Error rate** : Pourcentage d'erreurs
- **Error types** : Types d'erreurs rencontrées

#### 4. Codes de statut HTTP
- Distribution des codes de statut (200, 404, 500, etc.)

### Interprétation des résultats

#### ✅ Bon résultat
- Taux de succès > 99%
- Temps de réponse 95e percentile < 1000ms
- Pas d'augmentation significative des erreurs sous charge

#### ⚠️ Résultat à surveiller
- Taux de succès 95-99%
- Temps de réponse 95e percentile 1000-3000ms
- Augmentation modérée des erreurs

#### ❌ Problème détecté
- Taux de succès < 95%
- Temps de réponse 95e percentile > 3000ms
- Augmentation importante des erreurs

### Commandes d'analyse post-test

#### Extraction des statistiques clés
**Windows:**
```powershell
# Trouve le dernier rapport généré
$latestReport = Get-ChildItem -Path "results" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$statsFile = Join-Path $latestReport.FullName "stats.json"

# Analyse des stats
$stats = Get-Content $statsFile | ConvertFrom-Json
$stats.stats | Where-Object { $_.name -eq "Global" } | Format-Table name, numberOfRequests, meanResponseTime, percentiles95
```

**Linux/macOS:**
```bash
# Trouve le dernier rapport
LATEST_REPORT=$(find results -type d -name "*" | sort | tail -1)

# Analyse avec jq (si disponible)
cat "$LATEST_REPORT/stats.json" | jq '.stats[] | select(.name=="Global") | {name, numberOfRequests, meanResponseTime, percentiles95}'
```

## 🔍 Troubleshooting

### Problèmes courants

#### 1. Erreur "gatling command not found"

**Solution :**
```bash
# Réinstaller Gatling CLI
npm install -g @gatling.io/cli

# Vérifier l'installation
gatling --version
```

#### 2. Erreur "Module not found: @gatling.io/js-sdk"

**Solution :**
```bash
# Installer les dépendances locales
npm install

# Ou réinstaller complètement
rm -rf node_modules package-lock.json
npm install
```

#### 3. Erreur de timeout/connexion

**Solutions :**
- Vérifier que l'URL cible est accessible
- Augmenter le `REQUEST_TIMEOUT`
- Vérifier les proxies/firewalls
- Utiliser l'option `-Debug` pour plus d'informations

#### 4. Performances dégradées

**Solutions :**
- Réduire le nombre d'utilisateurs simultanés
- Augmenter le `THINK_TIME`
- Vérifier les ressources système (CPU, RAM)
- Optimiser les assertions et vérifications

#### 5. Erreurs de compilation JavaScript

**Solution :**
```bash
# Vérifier la syntaxe du script
node -c gatling-js-universal-test.js

# Mettre à jour Node.js si nécessaire
node --version  # Doit être >= 16.0.0
```

### Logs et débogage

#### Activation du mode debug

**Windows:**
```powershell
.\run-gatling-js.ps1 -Debug -TargetUrl "your-url"
```

**Linux/macOS:**
```bash
./run-gatling-js.sh --debug -u "your-url"
```

#### Logs détaillés Gatling

Ajoutez dans votre script Gatling :

```javascript
// Configuration de logging détaillée
.exec(session => {
  console.log(`Session: ${session.get('userId')}, Endpoint: ${session.get('currentEndpoint')}`);
  return session;
})
```

### Support et ressources

#### Documentation officielle
- [Gatling JavaScript SDK](https://gatling.io/docs/gatling/guides/javascript_sdk/)
- [Gatling CLI](https://gatling.io/docs/gatling/guides/cli/)

#### Communauté
- [GitHub Gatling](https://github.com/gatling/gatling)
- [Forum Gatling](https://community.gatling.io/)

## 🎯 Bonnes pratiques

### 1. Planification des tests
- Commencer par des tests de fumée (smoke tests)
- Augmenter progressivement la charge
- Tester différents scénarios d'usage

### 2. Configuration des assertions
```javascript
.assertions(
  global().responseTime().percentile3().lt(1000),
  global().successfulRequests().percent().gt(95),
  details('endpoint-critique').responseTime().mean().lt(500)
)
```

### 3. Monitoring pendant les tests
- Surveiller les métriques système (CPU, RAM, réseau)
- Vérifier les logs d'application
- Observer les métriques de base de données

### 4. Analyse post-test
- Comparer avec les tests précédents
- Identifier les goulots d'étranglement
- Documenter les améliorations nécessaires

### 5. Intégration CI/CD
```yaml
# Exemple GitHub Actions
- name: Run Gatling Tests
  run: |
    ./run-gatling-js.sh -u ${{ env.API_URL }} -b 5 -M 20 -d 60
    
- name: Archive Results
  uses: actions/upload-artifact@v3
  with:
    name: gatling-results
    path: results/
```

---

## 📝 Résumé

Ce guide vous fournit tous les outils nécessaires pour effectuer des tests de performance complets avec Gatling JavaScript. Le script universel permet de tester n'importe quelle URL ou API avec une configuration flexible et des résultats détaillés.

**Avantages du script universel :**
- ✅ Configuration flexible par variables d'environnement
- ✅ Support de multiple endpoints et méthodes HTTP
- ✅ Tests de charge, performance et stress intégrés
- ✅ Scripts cross-platform (Windows/Linux/macOS)
- ✅ Rapports HTML détaillés automatiques
- ✅ Mode debug pour le troubleshooting
- ✅ Installation automatisée des dépendances

Pour commencer rapidement :
1. Exécutez `./run-gatling-js.sh --setup` (ou `.ps1` sur Windows)
2. Lancez un test simple : `./run-gatling-js.sh -u "https://httpbin.org/get"`
3. Analysez les résultats dans le rapport HTML généré

**Happy testing!** 🚀 