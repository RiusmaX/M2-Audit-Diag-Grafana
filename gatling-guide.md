# 🎯 Guide Complet des Tests de Stress Gatling

## 📋 Vue d'ensemble

Gatling est un outil de test de charge haute performance qui permet de simuler des milliers d'utilisateurs simultanés. Cette suite de tests est spécialement conçue pour votre API Express avec monitoring intégré.

## 🚀 Installation et Prérequis

### Prérequis
- **Docker** et **Docker Compose** installés
- **Au moins 4GB de RAM** libre (Gatling utilise 2GB)
- **API Express** démarrée sur `localhost:3001`

### Structure des fichiers
```
gatling/
├── user-files/
│   ├── simulations/
│   │   └── ExpressApiStressTest.scala    # Test principal
│   └── data/                             # Données de test
├── conf/
│   └── gatling.conf                      # Configuration
├── results/                              # Résultats bruts
└── reports/                              # Rapports HTML
```

## 🎮 Utilisation

### 🔥 **Test de Stress Standard**

#### PowerShell
```powershell
# Test basique (50 utilisateurs, 5 minutes)
./run-gatling.ps1

# Test personnalisé
./run-gatling.ps1 -Users 100 -RampDuration 60 -TestDuration 600 -BaseUrl "http://localhost:3001"
```

#### Bash
```bash
# Test basique
./run-gatling.sh

# Test personnalisé (100 utilisateurs, 1 min de ramp, 10 min de test)
./run-gatling.sh 100 60 600 "http://localhost:3001"
```

### 📊 **Génération de Rapports**

```bash
# PowerShell
./run-gatling.ps1 -ReportsOnly

# Bash
./run-gatling.sh --reports-only
```

### 🧹 **Nettoyage des Résultats**

```bash
# PowerShell
./run-gatling.ps1 -CleanResults

# Bash
./run-gatling.sh --clean-results
```

## 🎯 Types de Tests Inclus

### 1. **Tests par Endpoint** 
- ✅ `GET /` - Page d'accueil
- ✅ `GET /api/users` - Liste des utilisateurs
- ✅ `POST /api/users` - Création d'utilisateur
- ✅ `GET /api/products` - Catalogue produits
- ✅ `GET /api/orders` - Commandes
- ✅ `POST /api/payment` - Paiements (critique)
- ✅ `GET /health` - Santé du système

### 2. **Scénarios de Test**

#### **Parcours Utilisateur Complet**
1. Accès page d'accueil
2. Navigation produits
3. Création de compte
4. Consultation commandes
5. Processus de paiement

#### **Test de Charge Progressive**
- Montée en charge par paliers
- Distribution intelligente du trafic
- Pauses réalistes entre actions

#### **Test de Résilience**
- Charge constante prolongée
- Test des points de rupture
- Validation des limites système

## 📈 Configuration des Tests

### Variables Configurables

| Paramètre | PowerShell | Bash | Description | Défaut |
|-----------|------------|------|-------------|---------|
| Utilisateurs | `-Users 100` | `100` | Nombre d'utilisateurs simultanés | 50 |
| Montée | `-RampDuration 60` | `60` | Durée de montée en charge (s) | 30 |
| Test | `-TestDuration 600` | `600` | Durée totale du test (s) | 300 |
| URL | `-BaseUrl "..."` | `"..."` | URL de l'API à tester | localhost:3001 |

### Configuration Avancée

Le fichier `gatling/user-files/simulations/ExpressApiStressTest.scala` permet de personnaliser :

- **Distribution du trafic** par endpoint
- **Patterns de charge** (ramp, constant, spike)
- **Assertions de performance** automatiques
- **Feeders de données** dynamiques

## 📊 Analyse des Résultats

### 🎯 **Métriques Collectées**

#### Performance
- **RPS** (Requêtes par seconde)
- **Temps de réponse** (percentiles 50, 75, 95, 99)
- **Débit** (KB/s)
- **Concurrence** active

#### Fiabilité
- **Taux de succès** par endpoint
- **Distribution des erreurs** HTTP
- **Timeouts** et connexions échouées

#### Charge
- **Montée en charge** progressive
- **Paliers de stabilité**
- **Points de rupture**

### 📋 **Rapports Générés**

#### **Console** (Temps réel)
```
================================================================================
---- Global Information --------------------------------------------------------
> request count                                      12847 (OK=12754  KO=93   )
> min response time                                      2 (OK=2      KO=3    )
> max response time                                   1547 (OK=1547   KO=1456 )
> mean response time                                   187 (OK=186    KO=234  )
> std deviation                                        156 (OK=155    KO=187  )
> response time 50th percentile                        134 (OK=134    KO=187  )
> response time 75th percentile                        256 (OK=255    KO=312  )
> response time 95th percentile                        478 (OK=476    KO=567  )
> response time 99th percentile                        687 (OK=685    KO=891  )
> mean requests/sec                                    42.8 (OK=42.51  KO=0.31 )
================================================================================
```

#### **HTML** (Détaillé)
- 📊 **Graphiques de performance** interactifs
- 📈 **Évolution des métriques** dans le temps
- 🎯 **Analyse par endpoint** détaillée
- 🔍 **Distribution des temps** de réponse
- ⚠️ **Détail des erreurs** rencontrées

### 🎯 **Seuils de Performance**

#### ✅ **Excellent**
- RPS : > 100
- Temps de réponse P95 : < 500ms
- Taux de succès : > 99%
- Stabilité : Aucune dégradation

#### 🟡 **Acceptable**
- RPS : 50-100
- Temps de réponse P95 : 500ms-1s
- Taux de succès : 95-99%
- Stabilité : Dégradation mineure

#### 🔴 **Critique**
- RPS : < 50
- Temps de réponse P95 : > 1s
- Taux de succès : < 95%
- Stabilité : Dégradation importante

## ⚡ Optimisations de Performance

### Configuration Gatling

```scala
// Dans ExpressApiStressTest.scala
val httpProtocol = http
  .baseUrl(baseUrl)
  .acceptHeader("application/json")
  .contentTypeHeader("application/json")
  .connectionHeader("keep-alive")      // Réutilisation des connexions
  .acceptEncodingHeader("gzip")        // Compression
```

### JVM Settings

```bash
export JAVA_OPTS="-Xmx4g -Xms2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

## 🔧 Résolution de Problèmes

### Erreurs Communes

#### 1. **Mémoire insuffisante**
```
Exception: OutOfMemoryError
```
**Solution :** Réduire le nombre d'utilisateurs ou augmenter la RAM allouée

#### 2. **API non disponible**
```
Connection refused to localhost:3001
```
**Solution :** Vérifier que l'API Express est démarrée

#### 3. **Docker out of space**
```
No space left on device
```
**Solution :** Nettoyer Docker `docker system prune -a`

### Performance Debugging

#### Monitoring Système
```bash
# Pendant le test
docker stats
htop
```

#### Logs Gatling
```bash
docker-compose -f docker-compose.gatling.yml logs gatling
```

## 🚀 Intégration CI/CD

### GitHub Actions

```yaml
name: Gatling Load Tests
on: [push]
jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Start API
        run: docker-compose up -d
      - name: Wait for API
        run: sleep 30
      - name: Run Gatling Tests
        run: ./run-gatling.sh 25 30 120
      - name: Upload Results
        uses: actions/upload-artifact@v2
        with:
          name: gatling-results
          path: gatling/results
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any
    stages {
        stage('API Setup') {
            steps {
                sh 'docker-compose up -d'
                sh 'sleep 30'
            }
        }
        stage('Load Tests') {
            steps {
                sh './run-gatling.sh 50 60 300'
            }
        }
        stage('Publish Results') {
            steps {
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'gatling/results',
                    reportFiles: '*/index.html',
                    reportName: 'Gatling Report'
                ])
            }
        }
    }
}
```

## 📈 Monitoring en Temps Réel

### Dashboards Disponibles

#### **Grafana** (Recommandé)
- **URL :** http://localhost:3000/d/express_app_monitoring_complete
- **Métriques :** RPS, temps de réponse, erreurs en temps réel
- **Alertes :** Seuils configurables

#### **Prometheus**
- **URL :** http://localhost:9090
- **Métriques brutes :** Toutes les métriques Prometheus
- **Requêtes :** PromQL pour analyses custom

### Corrélation des Données

Pendant un test Gatling, surveillez simultanément :
1. **Gatling Console** - Progression du test
2. **Grafana Dashboard** - Métriques applicatives
3. **Logs Docker** - Erreurs système

## 🎯 Scénarios de Test Recommandés

### 🏢 **Production**
```bash
# Test de pic journalier (1000 users, 15 min)
./run-gatling.sh 1000 300 900

# Test de charge soutenue (500 users, 1 heure)
./run-gatling.sh 500 600 3600
```

### 🧪 **Validation**
```bash
# Test de régression (100 users, 5 min)
./run-gatling.sh 100 60 300

# Test de capacité (200 users, 10 min)
./run-gatling.sh 200 120 600
```

### 🔍 **Debug**
```bash
# Test léger pour debugging (10 users, 2 min)
./run-gatling.sh 10 30 120
```

## 📞 Support et Documentation

### Ressources
- 📚 **Documentation officielle :** https://gatling.io/docs/
- 🎥 **Tutoriels :** https://gatling.io/academy/
- 💬 **Community :** https://community.gatling.io/

### Logs et Debug
```bash
# Logs détaillés
export GATLING_OPTS="-Dlogback.configurationFile=logback-debug.xml"

# Mode verbose
./run-gatling.sh --help
```

---

**🎯 Profitez de vos tests de stress professionnels avec Gatling !** 