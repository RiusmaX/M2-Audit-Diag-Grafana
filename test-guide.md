# 🚀 Guide Complet des Tests de Charge et de Performance

## 📋 Vue d'ensemble

Ce guide vous présente les différents scripts de test disponibles pour évaluer les performances de votre API Express sous différentes conditions de charge.

## 🛠️ Scripts Disponibles

### 1. **Tests de Charge Standard**

#### PowerShell : `load-test.ps1`
```powershell
# Test basique (10 utilisateurs, 60 secondes)
./load-test.ps1

# Test personnalisé
./load-test.ps1 -Users 25 -Duration 120 -RampUp 15 -BaseUrl "http://localhost:3001"
```

#### Bash : `load-test.sh`
```bash
# Test basique
./load-test.sh

# Test personnalisé
./load-test.sh 25 120 15 "http://localhost:3001"
```

**Caractéristiques :**
- ✅ Simulation d'utilisateurs réalistes
- ✅ Montée en charge progressive
- ✅ Monitoring en temps réel
- ✅ Rapports détaillés CSV
- ✅ Recommandations automatiques

### 2. **Tests de Stress Intensif**

#### PowerShell : `stress-test.ps1`
```powershell
# Test de stress standard
./stress-test.ps1

# Test de stress personnalisé
./stress-test.ps1 -MaxUsers 100 -StepDuration 45 -StressDuration 180
```

#### Bash : `stress-test.sh`
```bash
# Test de stress standard
./stress-test.sh

# Test de stress personnalisé
./stress-test.sh 100 45 180
```

**Caractéristiques :**
- 🔥 Tests par paliers croissants (5, 10, 20, 30, 50 users)
- 🔥 Phase de stress final intensif
- 🔥 Identification des points de rupture
- 🔥 Métriques système (CPU, RAM)
- 🔥 Analyse de capacité

### 3. **Tests Rapides de Validation**

#### PowerShell : `test-api.ps1`, `generate-traffic.ps1`, `test-simple.ps1`
#### Bash : `generate-traffic.sh`, `test-simple.sh`

## 📊 Types de Tests Recommandés

### 🟢 **Test de Développement** (quotidien)
```bash
# Validation rapide
./test-simple.sh
```
**Durée :** 30 secondes  
**Objectif :** Vérifier que l'API fonctionne

### 🟡 **Test de Validation** (avant déploiement)
```powershell
# Test de charge modéré
./load-test.ps1 -Users 15 -Duration 90
```
**Durée :** 90 secondes  
**Objectif :** Valider les performances sous charge normale

### 🟠 **Test de Performance** (hebdomadaire)
```bash
# Test de charge complet
./load-test.sh 30 180 20
```
**Durée :** 3 minutes  
**Objectif :** Mesurer les performances optimales

### 🔴 **Test de Stress** (avant mise en production)
```powershell
# Test de stress complet
./stress-test.ps1 -MaxUsers 75 -StressDuration 300
```
**Durée :** 10 minutes  
**Objectif :** Identifier les limites du système

## 📈 Métriques Collectées

### 🎯 **Métriques de Performance**
- **RPS** (Requêtes par seconde)
- **Temps de réponse** (min, moyenne, max)
- **Taux d'erreur** (%)
- **Débit** (MB/s)

### 🖥️ **Métriques Système**
- **CPU** (% d'utilisation)
- **RAM** (% d'utilisation)
- **Connexions actives**
- **Uptime du service**

### 🔍 **Métriques Applicatives**
- **Requêtes par endpoint**
- **Codes de statut HTTP**
- **Erreurs métier**
- **Performance par fonctionnalité**

## 🎯 Seuils de Performance Recommandés

### ✅ **Excellent**
- RPS : > 50
- Temps de réponse moyen : < 200ms
- Taux d'erreur : < 0.1%
- CPU : < 50%

### 🟡 **Acceptable**
- RPS : 20-50
- Temps de réponse moyen : 200-500ms
- Taux d'erreur : 0.1-1%
- CPU : 50-70%

### 🔴 **Critique**
- RPS : < 20
- Temps de réponse moyen : > 500ms
- Taux d'erreur : > 1%
- CPU : > 70%

## 🔧 Configuration des Tests

### Variables d'Environnement
```bash
export API_BASE_URL="http://localhost:3001"
export MAX_CONCURRENT_USERS=50
export DEFAULT_TEST_DURATION=60
```

### Paramètres Personnalisables

| Paramètre | PowerShell | Bash | Description | Défaut |
|-----------|------------|------|-------------|---------|
| Utilisateurs | `-Users` | `$1` | Nombre d'utilisateurs simultanés | 10 |
| Durée | `-Duration` | `$2` | Durée du test (secondes) | 60 |
| Montée en charge | `-RampUp` | `$3` | Temps de montée progressive | 10 |
| URL | `-BaseUrl` | `$4` | URL de l'API à tester | localhost:3001 |

## 📋 Interprétation des Résultats

### 🟢 **Signaux Positifs**
- Temps de réponse stable
- Taux d'erreur faible
- RPS linéaire avec la charge
- CPU/RAM sous contrôle

### 🔴 **Signaux d'Alerte**
- Temps de réponse croissant
- Erreurs de timeout
- Chute brutale du RPS
- Saturation des ressources

### 📊 **Exemples de Rapports**

#### Rapport de Test Standard
```
📋 RAPPORT DE TEST DE CHARGE
==============================
⏱️  Durée totale: 60.2 secondes
📊 Requêtes totales: 1,847
✅ Requêtes réussies: 1,843
❌ Requêtes échouées: 4
🔥 Requêtes/seconde: 30.7
📈 Taux d'erreur: 0.22%

⏱️ TEMPS DE RÉPONSE:
   📉 Minimum: 45ms
   📊 Moyenne: 187ms
   📈 Maximum: 2,341ms
```

#### Rapport de Stress
```
📊 ANALYSE FINALE DU TEST DE STRESS
====================================
🏆 Meilleure performance: Palier 3 avec 42.5 req/s
⚠️  Palier critique: Palier 5 avec 8.3% d'erreurs

🎯 RECOMMANDATIONS DE CAPACITÉ:
   📊 Capacité recommandée: 29.75 req/s (70% du pic)
```

## 🚀 Automatisation et CI/CD

### GitHub Actions
```yaml
name: Load Tests
on: [push]
jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Load Test
        run: ./load-test.sh 20 90 15
```

### Cron Job (Tests réguliers)
```bash
# Tests quotidiens à 2h du matin
0 2 * * * /path/to/load-test.sh 15 60 10 >> /var/log/load-tests.log
```

## 🔍 Monitoring en Temps Réel

### Dashboards Grafana
- **URL :** http://localhost:3000/d/express_app_monitoring_complete
- **Actualisation :** 5 secondes
- **Métriques :** RPS, temps de réponse, erreurs, business KPIs

### Prometheus
- **URL :** http://localhost:9090
- **Métriques brutes :** Toutes les métriques collectées
- **Alertes :** Configuration des seuils critiques

## 🎯 Scénarios de Test Recommandés

### 🏢 **Environnement de Production**
1. **Peak Hours** : Test avec la charge maximale attendue
2. **Black Friday** : Test avec 300% de la charge normale
3. **Degraded Mode** : Test avec pannes partielles
4. **Recovery** : Test de récupération après panne

### 🧪 **Environnement de Test**
1. **Regression** : Validation après chaque déploiement
2. **Feature** : Test des nouvelles fonctionnalités
3. **Performance** : Comparaison des versions
4. **Capacity** : Planification de capacité

## 🛠️ Résolution de Problèmes

### Erreurs Communes

#### API non disponible
```bash
❌ API non disponible. Arrêt du test.
```
**Solution :** Vérifiez que l'API est démarrée sur le port correct

#### Timeouts
```bash
⚠️ Nombreux timeouts détectés
```
**Solution :** Réduisez la charge ou optimisez l'API

#### Mémoire insuffisante
```bash
🔴 CPU/RAM critique
```
**Solution :** Réduisez le nombre d'utilisateurs simultanés

## 📞 Support et Contact

Pour toute question ou problème :
- 📧 **Email :** support@mydigitalschool.com
- 📚 **Documentation :** README.md
- 🐛 **Issues :** Créez un ticket GitHub
- 💬 **Chat :** Canal #monitoring Slack

---

**🎯 Bonne chance avec vos tests de performance !** 