# Architecture Decision Records (ADRs)

**Project**: Open Source Multi-Vendor Grocery Commerce Platform  
**System Components**: Customer App (`com.rast.opem`), Admin App (`com.rast.opem.admin`), Supabase / PostgreSQL Shared Backend  
**Phase**: Phase 9 — Advanced Platform Evolution, Extreme Scale, and Enterprise Resilience  
**Core Architectural Philosophy**: **MEASURE FIRST**. Zero speculative infrastructure (no premature Kafka, Kubernetes, Elasticsearch, or distributed Redis) until quantified traffic thresholds demand it.

---

## Index of Architecture Decision Records

| ADR ID | Title | Status | Date |
| :--- | :--- | :--- | :--- |
| [ADR-001](#adr-001-postgresql-as-single-authoritative-datastore-vs-polyglot-micro-databases) | PostgreSQL as Single Authoritative Datastore vs. Polyglot Micro-Databases | **Accepted** | 2026-09-22 |
| [ADR-002](#adr-002-in-memory-application-caching-vs-distributed-redis-cluster) | In-Memory / Application-Level Caching vs. Distributed Redis Cluster | **Accepted** | 2026-09-22 |
| [ADR-003](#adr-003-postgresql-trigram-gin-search-vs-external-elasticsearch-cluster) | PostgreSQL Trigram / GIN Search vs. External Elasticsearch / Meilisearch | **Accepted** | 2026-09-22 |
| [ADR-004](#adr-004-transactional-outbox-pattern-vs-external-kafka--rabbitmq) | Transactional Outbox Pattern (`event_outbox`) vs. External Kafka / RabbitMQ | **Accepted** | 2026-09-22 |
| [ADR-005](#adr-005-connection-pooling-pgbouncer--read-replicas-vs-multi-region-active-active) | Connection Pooling (PgBouncer) & Read Replicas vs. Multi-Region Active-Active | **Accepted** | 2026-09-22 |
| [ADR-006](#adr-006-multi-location-dark-store-inventory--optimistic-concurrency-control-occ) | Multi-Location Dark Store Inventory & Optimistic Concurrency Control (OCC) | **Accepted** | 2026-09-22 |
| [ADR-007](#adr-007-payment-resilience-circuit-breaker-engine--failover-orchestration) | Payment Resilience, Circuit Breaker Engine & Failover Orchestration | **Accepted** | 2026-09-22 |
| [ADR-008](#adr-008-modular-architecture-vs-microservices-decomposition) | Modular Flutter Architecture & Unified Backend vs. Microservices Decomposition | **Accepted** | 2026-09-22 |

---

### ADR-001: PostgreSQL as Single Authoritative Datastore vs. Polyglot Micro-Databases

#### Context & Problem Statement
Commercial grocery platforms handle diverse operational needs: high-velocity inventory allocation, transactional payments, user profiles, product catalogs, customer reviews, and analytics. Teams frequently default to polyglot architectures (e.g., MongoDB for catalog, Cassandra for cart, Neo4j for recommendations, PostgreSQL for payments). We must decide whether to decompose into polyglot stores or retain PostgreSQL as the unified system of record.

#### Decision Drivers
- Strict ACID consistency requirements for financial balances, reservations, and inventory.
- Operational overhead: multi-database backups, two-phase commits, cross-datastore synchronization anomalies.
- Current scale: ~1,500 daily active users, ~150 peak requests/sec.
- Observability and database maintenance capacity of the engineering team.

#### Considered Options
1. **Option A**: Unified PostgreSQL engine running on Supabase with relational partitioning and connection pooling.
2. **Option B**: Polyglot architecture (MongoDB for product documents, PostgreSQL for ledger/orders, Redis for cart).

#### Decision Outcome
**Chosen Option: Option A (Unified PostgreSQL Engine)**.  
PostgreSQL with jsonb support, GiST/GIN indexes, row-level locking (`FOR UPDATE SKIP LOCKED`), and check constraints provides superior data integrity and eliminates distributed dual-write inconsistencies.

#### Pros & Cons
- **Pros**:
  - Single database transaction guarantees atomicity between inventory reservations and order placements.
  - Simplified disaster recovery: single point for WAL point-in-time recovery (PITR).
  - Low operational complexity: zero inter-database reconciliation scripts.
- **Cons**:
  - Requires diligent query profiling and indexing hygiene to avoid connection starvation during write spikes.

#### Evolution Trigger
- When sustained write transactions exceed 4,000 writes/second or database storage exceeds 4 TB with multi-terabyte analytics tables (at which point cold telemetry moves to ClickHouse/Snowflake while transactional core remains PostgreSQL).

---

### ADR-002: In-Memory / Application-Level Caching vs. Distributed Redis Cluster

#### Context & Problem Statement
Catalog navigation, category listings, and promotional banners generate repetitive read requests. Should we deploy a dedicated Redis/Valkey cluster or utilize in-memory bounded TTL caches within the Flutter clients and Supabase edge layers?

#### Decision Drivers
- Latency over mobile networks: round-trip time from phone to external Redis adds network hops.
- Cache invalidation complexity: stale catalog pricing can mislead customers.
- Operational infrastructure cost ($150-$400/mo for managed high-availability Redis).

#### Considered Options
1. **Option A**: Client-side bounded memory caching (`CacheService`) with prefix invalidation, TTLs (5 min), and optimistic cache-then-network strategies.
2. **Option B**: Remote Redis cluster deployed alongside backend functions.

#### Decision Outcome
**Chosen Option: Option A (Client-Side Bounded TTL Cache + HTTP CDN Caching)**.  
The existing `CacheService` stores hot catalog entities in client RAM. When an admin updates catalog products, client caches are deterministically purged using `cacheService.invalidatePrefix('products:')`. Critical checkout stock checks bypass cache entirely for authoritative database reads.

#### Pros & Cons
- **Pros**:
  - Instant UI rendering (0ms cache hits) with zero mobile data consumption.
  - Zero external infrastructure dependency or operational maintenance overhead.
  - Stock accuracy preserved because stock reservations never hit cache.
- **Cons**:
  - Cross-device cache invalidation relies on Supabase Realtime event broadcasts or short TTL expiry.

#### Evolution Trigger
- When catalog read volume exceeds 10,000 req/sec at the backend gateway and database replica CPU exceeds 70% under read-heavy traffic.

---

### ADR-003: PostgreSQL Trigram / GIN Search vs. External Elasticsearch Cluster

#### Context & Problem Statement
Grocery shoppers frequently search with partial words, typos, and multilingual transliterations (e.g., "tomto", "avocado", "milk 1l"). External search engines like Elasticsearch, OpenSearch, or Meilisearch are frequently proposed.

#### Decision Drivers
- Maintenance burden of Elasticsearch (JVM heap sizing, cluster balancing, index mapping synchronization).
- Catalog volume: 500 to 50,000 SKUs in typical regional grocery operations.
- Latency: Trigram search on 50,000 rows executes in < 8ms with indexed PostgreSQL `pg_trgm`.

#### Considered Options
1. **Option A**: PostgreSQL native `pg_trgm` extension with GIN trigram indexes on `products.name` and `products.description`.
2. **Option B**: Self-hosted or managed Elasticsearch / OpenSearch cluster with change data capture (CDC) pipeline.

#### Decision Outcome
**Chosen Option: Option A (PostgreSQL `pg_trgm` with GIN Indexes)**.  
Migration `20260921000001_initial_schema.sql` created `CREATE INDEX idx_products_name_trgm ON public.products USING gin (name gin_trgm_ops)`. This delivers sub-10ms fuzzy matching directly in PostgreSQL without synchronization lag or pipeline failures.

#### Pros & Cons
- **Pros**:
  - Realtime update visibility: When an admin updates a product title, it is immediately searchable.
  - Zero synchronization lag, zero CDC pipelines, zero indexing worker nodes.
- **Cons**:
  - Not suited for full-text semantic embedding or vector relevance ranking across millions of documents.

#### Evolution Trigger
- When product SKU count exceeds 250,000 items or semantic / AI-driven vector search is mandated by product leadership.

---

### ADR-004: Transactional Outbox Pattern vs. External Kafka / RabbitMQ

#### Context & Problem Statement
When an order is created or inventory is adjusted, downstream systems (push notifications, delivery partner webhooks, audit loggers, analytics) must be notified reliably without creating dual-write race conditions.

#### Decision Drivers
- Dual-write failure: If the database write succeeds but Kafka publish fails, events are lost.
- Operational burden of Kafka / RabbitMQ (Zookeeper/KRaft, partition rebalances, consumer group lag).
- Current event throughput: ~10-50 events/sec.

#### Considered Options
1. **Option A**: Transactional Outbox table (`public.event_outbox`) in PostgreSQL, inserted in the same transaction, polled with `FOR UPDATE SKIP LOCKED`.
2. **Option B**: External Apache Kafka / RabbitMQ message broker.

#### Decision Outcome
**Chosen Option: Option A (Transactional Outbox Pattern)**.  
Events are inserted atomically into `public.event_outbox` during the business mutation. A worker or scheduled RPC (`rpc_process_outbox_batch`) claims batches of 50 events using `SELECT ... FOR UPDATE SKIP LOCKED`, dispatches them, and marks them `published` or updates retry counts.

#### Pros & Cons
- **Pros**:
  - 100% ACID consistency: If the order transaction rolls back, the event is never published.
  - Automatic ordering and idempotency via `correlation_id` and unique event keys.
  - Zero external messaging infrastructure to provision, patch, or monitor.
- **Cons**:
  - Outbox table requires periodic pruning (or partitioning) of old `published` rows.

#### Evolution Trigger
- When platform event generation exceeds 2,500 events/second continuously, at which point an outbox CDC connector (Debezium) pipes outbox WAL events to an external stream.

---

### ADR-005: Connection Pooling (PgBouncer) & Read Replicas vs. Multi-Region Active-Active

#### Context & Problem Statement
As mobile user concurrency grows, database connection limits and read latency become bottlenecks. Multi-region active-active databases (e.g., CockroachDB, Spanner) are complex and incur high multi-master coordination latencies.

#### Decision Drivers
- PostgreSQL connection model: 1 connection per client process consumes RAM and backend overhead.
- Regional locality: 98% of orders are delivered within designated metropolitan areas.
- Write latency: Active-active cross-region consensus adds 150-300ms latency to every inventory decrement.

#### Considered Options
1. **Option A**: Managed PgBouncer connection pooler in transaction mode, paired with read-only replicas for analytics and read-heavy queries.
2. **Option B**: Distributed multi-region active-active database cluster.

#### Decision Outcome
**Chosen Option: Option A (PgBouncer Transaction Pooling + Read Replicas)**.  
Supabase provides built-in PgBouncer pooling on port 6543. Transaction-mode pooling supports up to 10,000 concurrent mobile connections with only 60 physical backend connections. Read-heavy analytical queries are directed to read replicas.

#### Pros & Cons
- **Pros**:
  - Fast single-digit millisecond write transactions.
  - No distributed split-brain scenarios or complex conflict-resolution algorithms.
  - Low cost and standard PostgreSQL compatibility.
- **Cons**:
  - Geographical distance to single primary datastore introduces 80-120ms round-trip for remote international clients.

#### Evolution Trigger
- When international expansion spans across distinct continents with independent local inventory, at which point separate regional databases per continent with shared user auth are provisioned.

---

### ADR-006: Multi-Location Dark Store Inventory & Optimistic Concurrency Control (OCC)

#### Context & Problem Statement
Grocery fulfillment is geographically partitioned into localized dark stores and micro-fulfillment centers. Additionally, multiple administrators simultaneously updating the catalog can cause lost updates (the "last-write-wins" problem).

#### Decision Drivers
- 10-minute to 30-minute quick-commerce delivery promises require inventory checks against the customer's specific nearest dark store.
- Concurrent admin stock and price adjustments must not overwrite each other silently.

#### Considered Options
1. **Option A**: Hierarchical multi-location schema (`fulfillment_locations`, `inventory_by_location`) with dark-store routing, plus explicit `version INT` columns on mutable entities for Optimistic Concurrency Control.
2. **Option B**: Single global stock count with pessimistic row locking across the entire store.

#### Decision Outcome
**Chosen Option: Option A (Multi-Location Inventory + OCC)**.  
Created `fulfillment_locations` (dark stores, hubs) and `inventory_by_location` with dark-store inventory reservation RPC (`rpc_allocate_location_inventory`). Added `version INT NOT NULL DEFAULT 1` to `products`, validated via `rpc_update_product_occ`. If an admin submits an update with a stale version, `StaleVersionException` is raised and the UI displays a conflict resolution banner.

#### Pros & Cons
- **Pros**:
  - Enables hyper-local delivery promises based on customer pincode mapping.
  - Completely eliminates silent lost updates during multi-admin catalog operations.
  - Fully backward-compatible: default location fallback is Bangalore Central (`wh_blr_central`).
- **Cons**:
  - Admins must handle version conflict dialogs during concurrent edits.

#### Evolution Trigger
- When automated dark store robotics or ERP integration requires automated multi-node replenishment syncing.

---

### ADR-007: Payment Resilience, Circuit Breaker Engine & Failover Orchestration

#### Context & Problem Statement
External payment providers (Razorpay, Stripe, UPI gateways) occasionally suffer from elevated error rates, network timeouts, or complete outages. Naive retry loops exacerbate cascading failures and lock user shopping carts.

#### Decision Drivers
- User trust: Never charge a customer twice; never leave a payment in an undefined state.
- System stability: Fast fail-over when third-party gateways degrade.
- Idempotency guarantees for all financial interactions.

#### Considered Options
1. **Option A**: Integrated `CircuitBreaker` engine (`closed`, `open`, `halfOpen` states) with failure counters, timeout reset windows, and graceful fallback to cash-on-delivery or alternate gateway.
2. **Option B**: Uncapped HTTP retries with exponential backoff.

#### Decision Outcome
**Chosen Option: Option A (Circuit Breaker Engine with Fail-Fast Fallbacks)**.  
Implemented `lib/utils/circuit_breaker.dart` with `CircuitBreaker` and `CircuitBreakerRegistry`. If consecutive gateway timeouts exceed 5 failures within 60 seconds, the circuit trips to `OPEN`. Incoming payment attempts fail fast with a clear message and suggest alternate payment methods (e.g., UPI, NetBanking, COD) without tying up backend server threads.

#### Pros & Cons
- **Pros**:
  - Eliminates cascading timeouts on mobile app and Supabase functions.
  - Graceful customer experience with instant feedback during provider downtime.
  - Automatic probing and recovery in `HALF_OPEN` state.
- **Cons**:
  - Temporary rejection of traffic on degraded provider during the reset timeout window.

#### Evolution Trigger
- When multi-gateway automated payment routing (dynamic transaction fee arbitrage) is adopted across 3+ parallel payment processors.

---

### ADR-008: Modular Flutter Architecture & Unified Backend vs. Microservices Decomposition

#### Context & Problem Statement
Engineering organizations often decompose systems into microservices prematurely, incurring significant network latency, complex serialization, distributed tracing overhead, and high cloud costs.

#### Decision Drivers
- Team size: Single pair-programming / small engineering team.
- Code sharing: Shared domain models, validation logic, and design tokens across Customer App and Admin App.
- Latency and debugging simplicity.

#### Considered Options
1. **Option A**: Modular monolith structure (Customer App, Admin App, shared models, domain services) backed by unified Supabase/PostgreSQL backend with RLS boundaries.
2. **Option B**: Microservices architecture (Auth service, Catalog service, Cart service, Order service, Notification service, Payment service running on Kubernetes).

#### Decision Outcome
**Chosen Option: Option A (Modular Architecture with Unified Backend)**.  
The system maintains strict modular separation at the package and directory level (`lib/models`, `lib/services`, `lib/screens/admin`, `lib/screens/customer`), isolated by PostgreSQL Row Level Security (RLS) policies and role-based permissions (`is_admin()`).

#### Pros & Cons
- **Pros**:
  - Zero network hop latency between domain components.
  - End-to-end type safety in Dart.
  - Rapid debugging, single CI/CD pipeline, minimal infrastructure operational cost.
- **Cons**:
  - Deployments deploy the complete application bundle.

#### Evolution Trigger
- Only when distinct autonomous teams (> 15 engineers) own isolated bounded contexts with independent deployment cadences and distinct scalability bottlenecks.
