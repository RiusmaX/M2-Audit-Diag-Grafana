const {
  simulation,
  scenario,
  exec,
  pause,
  constantUsersPerSec,
  rampUsersPerSec,
  nothingFor,
  atOnceUsers,
  http
} = require('@gatling.io/js-sdk');

// Configuration par défaut (peut être surchargée par variables d'environnement)
const config = {
  targetUrl: process.env.TARGET_URL || 'http://localhost:3001',
  baseUsers: parseInt(process.env.BASE_USERS) || 5,
  maxUsers: parseInt(process.env.MAX_USERS) || 50,
  testDuration: parseInt(process.env.TEST_DURATION) || 60, // secondes
  rampDuration: parseInt(process.env.RAMP_DURATION) || 30, // secondes
  thinkTime: parseInt(process.env.THINK_TIME) || 1, // secondes entre requêtes
  endpoints: process.env.ENDPOINTS ? process.env.ENDPOINTS.split(',') : ['/'],
  httpMethods: process.env.HTTP_METHODS ? process.env.HTTP_METHODS.split(',') : ['GET'],
  headers: process.env.HEADERS ? JSON.parse(process.env.HEADERS) : {},
  requestTimeout: parseInt(process.env.REQUEST_TIMEOUT) || 10000, // ms
  enableDebug: process.env.DEBUG === 'true'
};

console.log('Configuration du test:');
console.log(JSON.stringify(config, null, 2));

// Configuration HTTP globale
const httpProtocol = http
  .baseUrl(config.targetUrl)
  .acceptHeader('application/json, text/html, */*')
  .acceptLanguageHeader('fr-FR,fr;q=0.9,en;q=0.8')
  .acceptEncodingHeader('gzip, deflate')
  .userAgentHeader('Gatling Universal Tester 1.0')
  .requestTimeout(config.requestTimeout);

// Ajout des headers personnalisés si définis
if (Object.keys(config.headers).length > 0) {
  Object.entries(config.headers).forEach(([key, value]) => {
    httpProtocol.header(key, value);
  });
}

// Fonction pour créer une requête selon la méthode HTTP
function createRequest(endpoint, method = 'GET') {
  const requestName = `${method} ${endpoint}`;
  
  switch (method.toUpperCase()) {
    case 'GET':
      return http(requestName).get(endpoint);
    case 'POST':
      return http(requestName).post(endpoint)
        .header('Content-Type', 'application/json')
        .body('{"test": true, "timestamp": "#{timestamp}"}');
    case 'PUT':
      return http(requestName).put(endpoint)
        .header('Content-Type', 'application/json')
        .body('{"updated": true, "timestamp": "#{timestamp}"}');
    case 'DELETE':
      return http(requestName).delete(endpoint);
    case 'PATCH':
      return http(requestName).patch(endpoint)
        .header('Content-Type', 'application/json')
        .body('{"patched": true, "timestamp": "#{timestamp}"}');
    default:
      return http(requestName).get(endpoint);
  }
}

// Scénario de test principal
const universalTestScenario = scenario('Test Universel URL')
  .feed([
    { timestamp: () => new Date().toISOString() },
    { userId: () => Math.floor(Math.random() * 10000) },
    { sessionId: () => Math.random().toString(36).substring(7) }
  ])
  .exec(session => {
    if (config.enableDebug) {
      console.log(`Démarrage session utilisateur: ${session.get('userId')}`);
    }
    return session;
  })
  .repeat(config.endpoints.length * config.httpMethods.length).on(
    exec(session => {
      // Sélection cyclique des endpoints et méthodes
      const endpointIndex = session.get('gatling.core.controller.inject.open.OpenInjectionStep$Users') % config.endpoints.length;
      const methodIndex = session.get('gatling.core.controller.inject.open.OpenInjectionStep$Users') % config.httpMethods.length;
      
      const endpoint = config.endpoints[endpointIndex];
      const method = config.httpMethods[methodIndex];
      
      return session.set('currentEndpoint', endpoint).set('currentMethod', method);
    })
    .exec(session => {
      const endpoint = session.get('currentEndpoint');
      const method = session.get('currentMethod');
      
      return createRequest(endpoint, method)
        .check(
          // Vérifications de base
          status().is(200, 201, 202, 204, 301, 302),
          responseTimeInMillis().lt(config.requestTimeout)
        );
    })
    .pause(config.thinkTime)
  )
  .exec(session => {
    if (config.enableDebug) {
      console.log(`Fin session utilisateur: ${session.get('userId')}`);
    }
    return session;
  });

// Scénario de test de charge progressive
const loadTestScenario = scenario('Test de Charge Progressive')
  .feed([
    { timestamp: () => new Date().toISOString() },
    { userId: () => Math.floor(Math.random() * 10000) }
  ])
  .during(config.testDuration).on(
    config.endpoints.map((endpoint, index) => {
      const method = config.httpMethods[index % config.httpMethods.length];
      return exec(
        createRequest(endpoint, method)
          .check(
            status().in([200, 201, 202, 204, 301, 302, 404, 500]),
            responseTimeInMillis().saveAs(`responseTime_${endpoint.replace(/[^a-zA-Z0-9]/g, '_')}`)
          )
      ).pause(config.thinkTime);
    }).reduce((acc, curr) => acc.exec(curr), exec())
  );

// Scénario de test de stress
const stressTestScenario = scenario('Test de Stress')
  .feed([
    { timestamp: () => new Date().toISOString() },
    { correlationId: () => Math.random().toString(36).substring(7) }
  ])
  .forever().on(
    config.endpoints.map(endpoint => {
      const method = config.httpMethods[0]; // Utilise la première méthode pour le stress
      return exec(
        createRequest(endpoint, method)
          .check(
            status().in([200, 201, 202, 204, 301, 302, 404, 500, 503]),
            responseTimeInMillis().lt(config.requestTimeout * 2)
          )
      );
    }).reduce((acc, curr) => acc.exec(curr), exec())
    .pause(0.1, 0.5) // Pause très courte pour le stress test
  );

// Configuration de la simulation
export default simulation('Simulation Test Universel')
  .protocols(httpProtocol)
  .scenarios(
    // Test de base
    universalTestScenario.injectOpen(
      atOnceUsers(config.baseUsers),
      rampUsersPerSec(1).to(config.baseUsers).during(config.rampDuration),
      constantUsersPerSec(config.baseUsers).during(config.testDuration)
    ),
    
    // Test de charge progressive (optionnel selon MAX_USERS)
    ...(config.maxUsers > config.baseUsers ? [
      loadTestScenario.injectOpen(
        nothingFor(10),
        rampUsersPerSec(config.baseUsers).to(config.maxUsers).during(config.rampDuration),
        constantUsersPerSec(config.maxUsers).during(config.testDuration)
      )
    ] : []),
    
    // Test de stress (optionnel si activé)
    ...(process.env.ENABLE_STRESS === 'true' ? [
      stressTestScenario.injectOpen(
        nothingFor(config.rampDuration + 10),
        atOnceUsers(config.maxUsers * 2),
        rampUsersPerSec(config.maxUsers).to(config.maxUsers * 3).during(30)
      )
    ] : [])
  )
  .assertions(
    // Assertions globales
    global().responseTime().percentile3().lt(config.requestTimeout),
    global().responseTime().mean().lt(config.requestTimeout / 2),
    global().successfulRequests().percent().gt(95),
    
    // Assertions par endpoint
    ...config.endpoints.map(endpoint => [
      details(endpoint).responseTime().percentile3().lt(config.requestTimeout),
      details(endpoint).successfulRequests().percent().gt(90)
    ]).flat()
  ); 