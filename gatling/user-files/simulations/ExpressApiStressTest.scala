package simulations

import io.gatling.core.Predef._
import io.gatling.http.Predef._
import scala.concurrent.duration._
import scala.util.Random

class ExpressApiStressTest extends Simulation {

  // Configuration de base
  val baseUrl = System.getProperty("baseUrl", "http://localhost:3001")
  val users = Integer.getInteger("users", 50).toInt
  val rampDuration = Integer.getInteger("rampDuration", 30).toInt
  val testDuration = Integer.getInteger("testDuration", 300).toInt
  
  // Configuration HTTP
  val httpProtocol = http
    .baseUrl(baseUrl)
    .acceptHeader("application/json")
    .contentTypeHeader("application/json")
    .userAgentHeader("Gatling Load Test")
    .acceptEncodingHeader("gzip, deflate")
    .acceptLanguageHeader("fr-FR,fr;q=0.9,en;q=0.8")
    .check(status.in(200, 201, 400, 404, 500)) // Accepter tous les codes de statut pour l'analyse

  // Feeders pour données dynamiques
  val userFeeder = Iterator.continually(Map(
    "userId" -> Random.nextInt(10000),
    "userName" -> s"TestUser${Random.nextInt(10000)}",
    "userEmail" -> s"test${Random.nextInt(10000)}@example.com"
  ))

  val paymentFeeder = Iterator.continually(Map(
    "amount" -> (Random.nextDouble() * 500 + 10).round,
    "cardToken" -> s"tok_${Random.alphanumeric.take(16).mkString}"
  ))

  val productFeeder = Iterator.continually(Map(
    "productId" -> Random.nextInt(100),
    "productName" -> s"Product${Random.nextInt(1000)}"
  ))

  // Scénarios de test pour chaque endpoint

  // 1. Test de base - Page d'accueil
  val homePageScenario = scenario("Home Page Access")
    .exec(
      http("GET /")
        .get("/")
        .check(status.is(200))
        .check(responseTimeInMillis.lte(1000))
    )

  // 2. Test des utilisateurs - GET
  val getUsersScenario = scenario("Get Users")
    .exec(
      http("GET /api/users")
        .get("/api/users")
        .check(status.is(200))
        .check(responseTimeInMillis.lte(2000))
        .check(jsonPath("$.length()").exists)
    )

  // 3. Test de création d'utilisateurs - POST
  val createUserScenario = scenario("Create User")
    .feed(userFeeder)
    .exec(
      http("POST /api/users")
        .post("/api/users")
        .body(StringBody("""{
          "name": "${userName}",
          "email": "${userEmail}"
        }""")).asJson
        .check(status.is(201))
        .check(responseTimeInMillis.lte(3000))
        .check(jsonPath("$.id").exists)
        .check(jsonPath("$.name").is("${userName}"))
    )

  // 4. Test des produits - GET
  val getProductsScenario = scenario("Get Products")
    .exec(
      http("GET /api/products")
        .get("/api/products")
        .check(status.is(200))
        .check(responseTimeInMillis.lte(2000))
        .check(jsonPath("$.data").exists)
        .check(jsonPath("$.data[*].id").exists)
    )

  // 5. Test des commandes - GET
  val getOrdersScenario = scenario("Get Orders")
    .exec(
      http("GET /api/orders")
        .get("/api/orders")
        .check(status.is(200))
        .check(responseTimeInMillis.lte(2000))
        .check(jsonPath("$.orders").exists)
    )

  // 6. Test de paiement - POST (endpoint critique)
  val paymentScenario = scenario("Process Payment")
    .feed(paymentFeeder)
    .exec(
      http("POST /api/payment")
        .post("/api/payment")
        .body(StringBody("""{
          "amount": ${amount},
          "card_token": "${cardToken}"
        }""")).asJson
        .check(status.in(200, 400, 500)) // Accepter les erreurs simulées
        .check(responseTimeInMillis.lte(5000))
        .check(jsonPath("$.transaction_id").optional.saveAs("transactionId"))
    )

  // 7. Test de santé du système
  val healthCheckScenario = scenario("Health Check")
    .exec(
      http("GET /health")
        .get("/health")
        .check(status.is(200))
        .check(responseTimeInMillis.lte(500))
        .check(jsonPath("$.status").is("healthy"))
        .check(jsonPath("$.uptime").exists)
    )

  // Scénario mixte réaliste - Parcours utilisateur complet
  val fullUserJourneyScenario = scenario("Full User Journey")
    .feed(userFeeder)
    .feed(paymentFeeder)
    .exec(
      // 1. Accès à la page d'accueil
      http("Access Home")
        .get("/")
        .check(status.is(200))
    )
    .pause(1, 3) // Pause réaliste
    .exec(
      // 2. Consultation des produits
      http("Browse Products")
        .get("/api/products")
        .check(status.is(200))
    )
    .pause(2, 5)
    .exec(
      // 3. Création d'un compte utilisateur
      http("Create Account")
        .post("/api/users")
        .body(StringBody("""{
          "name": "${userName}",
          "email": "${userEmail}"
        }""")).asJson
        .check(status.is(201))
    )
    .pause(1, 2)
    .exec(
      // 4. Consultation des commandes
      http("Check Orders")
        .get("/api/orders")
        .check(status.is(200))
    )
    .pause(1, 3)
    .exec(
      // 5. Processus de paiement
      http("Make Payment")
        .post("/api/payment")
        .body(StringBody("""{
          "amount": ${amount},
          "card_token": "${cardToken}"
        }""")).asJson
        .check(status.in(200, 400, 500))
    )

  // Configuration des tests de charge par paliers

  // Test 1: Charge progressive sur tous les endpoints
  val allEndpointsStressTest = scenario("All Endpoints Stress")
    .during(testDuration.seconds) {
      randomSwitch(
        15.0 -> exec(homePageScenario.exec),
        20.0 -> exec(getUsersScenario.exec),
        15.0 -> exec(createUserScenario.exec),
        20.0 -> exec(getProductsScenario.exec),
        15.0 -> exec(getOrdersScenario.exec),
        10.0 -> exec(paymentScenario.exec),
        5.0 -> exec(healthCheckScenario.exec)
      )
      .pause(100.milliseconds, 2.seconds)
    }

  // Configuration des assertions pour validation automatique
  val assertions = Seq(
    // Assertions globales
    global.responseTime.max.lt(10000), // Temps de réponse max < 10s
    global.responseTime.mean.lt(2000), // Temps de réponse moyen < 2s
    global.successfulRequests.percent.gt(95), // Taux de succès > 95%
    
    // Assertions par endpoint critique
    forAll.responseTime.percentile3.lt(5000), // P99 < 5s
    forAll.responseTime.percentile4.lt(3000), // P95 < 3s
    
    // Assertions spécifiques par endpoint
    details("GET /").responseTime.mean.lt(500),
    details("GET /api/users").responseTime.mean.lt(1000),
    details("POST /api/users").responseTime.mean.lt(1500),
    details("GET /api/products").responseTime.mean.lt(1000),
    details("GET /api/orders").responseTime.mean.lt(1000),
    details("POST /api/payment").responseTime.mean.lt(3000),
    details("GET /health").responseTime.mean.lt(200),
    
    // Assertions de débit
    global.requestsPerSec.gte(10) // Au moins 10 req/sec
  )

  // Configuration des scénarios de test

  setUp(
    // Scénario 1: Test de charge progressive (warmup)
    allEndpointsStressTest.inject(
      rampUsers(users / 4) during (rampDuration / 3).seconds,
      constantUsersPerSec(users / 8) during 60.seconds
    ).protocols(httpProtocol),

    // Scénario 2: Test de pic de charge
    allEndpointsStressTest.inject(
      rampUsers(users / 2) during (rampDuration / 2).seconds,
      constantUsersPerSec(users / 4) during 120.seconds,
      rampUsers(users) during rampDuration.seconds
    ).protocols(httpProtocol),

    // Scénario 3: Parcours utilisateur réaliste
    fullUserJourneyScenario.inject(
      rampUsers(users / 3) during rampDuration.seconds,
      constantUsersPerSec(users / 6) during (testDuration / 2).seconds
    ).protocols(httpProtocol),

    // Scénario 4: Test spécifique du endpoint critique (paiements)
    paymentScenario.inject(
      rampUsers(users / 5) during rampDuration.seconds,
      constantUsersPerSec(users / 10) during 180.seconds
    ).protocols(httpProtocol),

    // Scénario 5: Test de résilience avec charge constante
    allEndpointsStressTest.inject(
      constantUsersPerSec(users / 2) during testDuration.seconds
    ).protocols(httpProtocol)

  ).protocols(httpProtocol)
   .assertions(assertions: _*)
   .maxDuration(testDuration + 60 seconds) // Timeout de sécurité

} 