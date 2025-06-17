# Stack de Monitoring Système - Prometheus + Grafana

Cette stack Docker Compose permet de monitorer votre PC comme un serveur avec Prometheus et Grafana.

## 🛠️ Composants inclus

- **Prometheus** : Collecte et stockage des métriques
- **Grafana** : Interface de visualisation des données
- **Node Exporter** : Export des métriques système (CPU, mémoire, disque, réseau)
- **cAdvisor** : Monitoring des conteneurs Docker
- **AlertManager** : Gestion des alertes (optionnel)

## 🚀 Démarrage rapide

### Prérequis
- Docker et Docker Compose installés
- Ports libres : 3000 (Grafana), 9090 (Prometheus), 9100 (Node Exporter), 8081 (cAdvisor), 9093 (AlertManager)

### Lancement
```bash
# Cloner/télécharger les fichiers dans un répertoire
# Puis lancer la stack
docker-compose up -d

# Vérifier que tous les services sont en cours d'exécution
docker-compose ps
```

### Arrêt
```bash
docker-compose down

# Pour supprimer également les volumes (données persistantes)
docker-compose down -v
```

## 📊 Accès aux interfaces

| Service | URL | Identifiants |
|---------|-----|--------------|
| **Grafana** | http://localhost:3000 | admin / admin123 |
| **Prometheus** | http://localhost:9090 | - |
| **Node Exporter** | http://localhost:9100 | - |
| **cAdvisor** | http://localhost:8081 | - |
| **AlertManager** | http://localhost:9093 | - |

## 📈 Métriques disponibles

### Métriques système (Node Exporter)
- **CPU** : Utilisation par cœur, charge système
- **Mémoire** : RAM utilisée/disponible, swap
- **Disque** : Espace utilisé/libre par partition, I/O
- **Réseau** : Trafic entrant/sortant par interface
- **Processus** : Nombre de processus, états

### Métriques conteneurs (cAdvisor)
- Utilisation CPU/mémoire par conteneur
- I/O réseau et disque par conteneur
- Statistiques Docker

## 🔔 Alertes configurées

Les alertes suivantes sont préconfigurées :
- ✅ **CPU élevé** : > 80% pendant 5 minutes
- ✅ **Mémoire élevée** : > 85% pendant 5 minutes
- ✅ **Espace disque faible** : < 15% d'espace libre
- ✅ **Service arrêté** : Perte de connexion
- ✅ **Charge système élevée** : Load average > 2

## 🎯 Dashboard Grafana

Un dashboard "Monitoring Système PC" est automatiquement importé avec :
- Graphiques d'utilisation CPU et mémoire
- Monitoring en temps réel
- Actualisation automatique toutes les 5 secondes

### Ajouter des dashboards supplémentaires
1. Aller sur https://grafana.com/grafana/dashboards/
2. Chercher des dashboards pour "Node Exporter" (ex: Dashboard ID 1860)
3. Les importer dans Grafana via l'interface web

## ⚙️ Configuration

### Modifier les seuils d'alertes
Éditer le fichier `prometheus/alert.rules` et relancer :
```bash
docker-compose restart prometheus
```

### Personnaliser Prometheus
Modifier `prometheus/prometheus.yml` pour ajouter de nouvelles cibles de monitoring.

### Changer les identifiants Grafana
Modifier les variables d'environnement dans `docker-compose.yml` :
```yaml
environment:
  - GF_SECURITY_ADMIN_USER=votre_user
  - GF_SECURITY_ADMIN_PASSWORD=votre_password
```

## 🐛 Dépannage

### Vérifier les logs
```bash
# Logs de tous les services
docker-compose logs

# Logs d'un service spécifique
docker-compose logs grafana
docker-compose logs prometheus
```

### Problèmes courants

1. **Port déjà utilisé** : Modifier les ports dans `docker-compose.yml`
2. **Permissions sur les volumes** : Sous Linux, vérifier les permissions Docker
3. **Node Exporter ne remonte pas les métriques** : Vérifier que les volumes sont bien montés

### Redémarrer un service
```bash
docker-compose restart grafana
```

## 📝 Structure des fichiers

```
.
├── docker-compose.yml              # Configuration principale
├── prometheus/
│   ├── prometheus.yml             # Configuration Prometheus
│   └── alert.rules               # Règles d'alertes
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── prometheus.yml    # Source de données auto
│   │   └── dashboards/
│   │       └── dashboards.yml    # Config dashboards auto
│   └── dashboards/
│       └── system-monitoring.json # Dashboard système
└── alertmanager/
    └── alertmanager.yml          # Configuration AlertManager
```

## 🔧 Personnalisation avancée

### Ajouter de nouveaux exporters
Exemple pour MongoDB :
```yaml
mongo-exporter:
  image: percona/mongodb_exporter:latest
  ports:
    - "9216:9216"
  environment:
    - MONGODB_URI=mongodb://localhost:27017
```

### Intégration avec Slack/Teams
Modifier `alertmanager/alertmanager.yml` pour ajouter des webhooks.

## 📚 Ressources utiles

- [Documentation Prometheus](https://prometheus.io/docs/)
- [Documentation Grafana](https://grafana.com/docs/)
- [Dashboards Grafana communautaires](https://grafana.com/grafana/dashboards/)
- [Exporters Prometheus](https://prometheus.io/docs/instrumenting/exporters/)

---

**Note** : Cette configuration est optimisée pour un environnement de développement/test. Pour la production, considérez l'ajout d'authentification, HTTPS, et la sécurisation des accès. 