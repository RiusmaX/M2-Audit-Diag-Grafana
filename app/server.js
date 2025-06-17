const express = require('express');
const prometheus = require('prom-client');
const responseTime = require('response-time');

const app = express();
const PORT = process.env.PORT || 3001;

// Configuration Prometheus
const collectDefaultMetrics = prometheus.collectDefaultMetrics;
collectDefaultMetrics({ timeout: 5000 });

// Création des métriques personnalisées
const httpRequestsTotal = new prometheus.Counter({
  name: 'http_requests_total',
  help: 'Nombre total de requêtes HTTP',
  labelNames: ['method', 'endpoint', 'status_code']
});

const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Durée des requêtes HTTP en secondes',
  labelNames: ['method', 'endpoint', 'status_code'],
  buckets: [0.001, 0.01, 0.1, 0.5, 1, 2, 5]
});

const activeConnections = new prometheus.Gauge({
  name: 'active_connections',
  help: 'Nombre de connexions actives'
});

const businessMetrics = new prometheus.Counter({
  name: 'business_operations_total',
  help: 'Opérations métier par endpoint',
  labelNames: ['operation', 'status']
});

// Middleware pour mesurer le temps de réponse
app.use(responseTime((req, res, time) => {
  const timeInSeconds = time / 1000;
  httpRequestDuration
    .labels(req.method, req.route?.path || req.path, res.statusCode)
    .observe(timeInSeconds);
}));

// Middleware pour compter les requêtes
app.use((req, res, next) => {
  activeConnections.inc();
  res.on('finish', () => {
    activeConnections.dec();
    httpRequestsTotal
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .inc();
  });
  next();
});

// Middleware JSON
app.use(express.json());

// Routes de l'application avec métriques

// 1. Endpoint d'accueil
app.get('/', (req, res) => {
  businessMetrics.labels('home_visit', 'success').inc();
  res.json({
    message: '🏠 Bienvenue sur l\'API de démo monitoring !',
    endpoints: [
      'GET / - Accueil',
      'GET /api/users - Liste des utilisateurs',
      'POST /api/users - Créer un utilisateur',
      'GET /api/products - Liste des produits',
      'GET /api/orders - Liste des commandes',
      'POST /api/payment - Traitement paiement',
      'GET /metrics - Métriques Prometheus'
    ],
    timestamp: new Date().toISOString()
  });
});

// 2. Endpoint utilisateurs (lecture)
app.get('/api/users', (req, res) => {
  // Simulation d'une opération qui peut échouer parfois
  if (Math.random() < 0.1) {
    businessMetrics.labels('get_users', 'error').inc();
    return res.status(500).json({ error: 'Erreur base de données' });
  }
  
  businessMetrics.labels('get_users', 'success').inc();
  
  // Simulation d'une latence variable
  const delay = Math.random() * 200;
  setTimeout(() => {
    res.json({
      users: [
        { id: 1, name: 'Alice Dupont', email: 'alice@example.com' },
        { id: 2, name: 'Bob Martin', email: 'bob@example.com' },
        { id: 3, name: 'Claire Bernard', email: 'claire@example.com' }
      ],
      total: 3,
      timestamp: new Date().toISOString()
    });
  }, delay);
});

// 3. Endpoint création utilisateur
app.post('/api/users', (req, res) => {
  // Validation simple
  if (!req.body.name || !req.body.email) {
    businessMetrics.labels('create_user', 'validation_error').inc();
    return res.status(400).json({ error: 'Nom et email requis' });
  }
  
  // Simulation d'erreur occasionnelle
  if (Math.random() < 0.05) {
    businessMetrics.labels('create_user', 'error').inc();
    return res.status(500).json({ error: 'Erreur création utilisateur' });
  }
  
  businessMetrics.labels('create_user', 'success').inc();
  
  res.status(201).json({
    message: 'Utilisateur créé avec succès',
    user: {
      id: Math.floor(Math.random() * 1000),
      name: req.body.name,
      email: req.body.email,
      created_at: new Date().toISOString()
    }
  });
});

// 4. Endpoint produits
app.get('/api/products', (req, res) => {
  businessMetrics.labels('get_products', 'success').inc();
  
  // Simulation d'une latence plus importante pour ce endpoint
  const delay = Math.random() * 500;
  setTimeout(() => {
    res.json({
      products: [
        { id: 1, name: 'Ordinateur portable', price: 899.99, stock: 45 },
        { id: 2, name: 'Smartphone', price: 599.99, stock: 23 },
        { id: 3, name: 'Tablette', price: 349.99, stock: 67 },
        { id: 4, name: 'Écouteurs', price: 149.99, stock: 156 }
      ],
      total: 4,
      timestamp: new Date().toISOString()
    });
  }, delay);
});

// 5. Endpoint commandes
app.get('/api/orders', (req, res) => {
  // Simulation d'un endpoint avec charge variable
  if (Math.random() < 0.15) {
    businessMetrics.labels('get_orders', 'timeout').inc();
    return res.status(408).json({ error: 'Timeout - Service temporairement indisponible' });
  }
  
  businessMetrics.labels('get_orders', 'success').inc();
  
  res.json({
    orders: [
      { id: 1001, user_id: 1, total: 1249.98, status: 'shipped', date: '2024-01-15' },
      { id: 1002, user_id: 2, total: 599.99, status: 'processing', date: '2024-01-16' },
      { id: 1003, user_id: 3, total: 349.99, status: 'delivered', date: '2024-01-14' }
    ],
    total: 3,
    timestamp: new Date().toISOString()
  });
});

// 6. Endpoint paiement (simulation)
app.post('/api/payment', (req, res) => {
  // Endpoint critique avec métriques spéciales
  if (!req.body.amount || !req.body.card_token) {
    businessMetrics.labels('payment', 'validation_error').inc();
    return res.status(400).json({ error: 'Montant et token carte requis' });
  }
  
  // Simulation de différents résultats de paiement
  const random = Math.random();
  
  if (random < 0.05) {
    businessMetrics.labels('payment', 'declined').inc();
    return res.status(402).json({ 
      error: 'Paiement refusé',
      reason: 'Fonds insuffisants'
    });
  }
  
  if (random < 0.1) {
    businessMetrics.labels('payment', 'fraud_detected').inc();
    return res.status(403).json({ 
      error: 'Transaction suspecte détectée',
      reason: 'Sécurité'
    });
  }
  
  if (random < 0.12) {
    businessMetrics.labels('payment', 'gateway_error').inc();
    return res.status(502).json({ 
      error: 'Erreur passerelle de paiement',
      reason: 'Service temporairement indisponible'
    });
  }
  
  // Paiement réussi
  businessMetrics.labels('payment', 'success').inc();
  
  // Simulation d'un délai de traitement
  const delay = Math.random() * 1000;
  setTimeout(() => {
    res.json({
      success: true,
      transaction_id: `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      amount: req.body.amount,
      status: 'completed',
      timestamp: new Date().toISOString()
    });
  }, delay);
});

// Endpoint pour les métriques Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  const metrics = await prometheus.register.metrics();
  res.end(metrics);
});

// Endpoint de santé
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    memory: process.memoryUsage(),
    pid: process.pid
  });
});

// Middleware de gestion d'erreurs
app.use((err, req, res, next) => {
  console.error('Erreur:', err);
  httpRequestsTotal
    .labels(req.method, req.route?.path || req.path, 500)
    .inc();
  res.status(500).json({ error: 'Erreur interne du serveur' });
});

// Gestion 404
app.use((req, res) => {
  res.status(404).json({ 
    error: 'Endpoint non trouvé',
    available_endpoints: [
      'GET /',
      'GET /api/users',
      'POST /api/users',
      'GET /api/products',
      'GET /api/orders',
      'POST /api/payment',
      'GET /metrics',
      'GET /health'
    ]
  });
});

// Démarrage du serveur
app.listen(PORT, () => {
  console.log(`🚀 Serveur Express démarré sur le port ${PORT}`);
  console.log(`📊 Métriques disponibles sur http://localhost:${PORT}/metrics`);
  console.log(`❤️ Santé de l'application sur http://localhost:${PORT}/health`);
  console.log(`📚 API documentation sur http://localhost:${PORT}/`);
});

// Gestion propre de l'arrêt
process.on('SIGTERM', () => {
  console.log('🛑 Arrêt du serveur...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 Arrêt du serveur...');
  process.exit(0);
}); 