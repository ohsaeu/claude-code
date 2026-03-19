# 마이크로서비스 분리 — 5단계 가이드

## 단계 간 입출력 흐름

```
[Step 1] service-boundaries.ts
         ↓ BOUNDED_CONTEXTS      → Step 2 엔티티별 DB 스키마 결정
         ↓ SERVICE_DEPENDENCIES  → Step 4 sync/async 통신 방식 결정
         ↓ port 번호             → Step 3 라우팅 테이블
              │
              ▼
[Step 2] db-separation-plan.ts
         ↓ DATABASE_CONFIGS     → Step 3 서비스 URL 구성
         ↓ DDL                  → 각 서비스 DB 마이그레이션
         ↓ MIGRATION_PHASES     → 무중단 전환 절차
              │
              ▼
[Step 3] api-gateway.ts
         ↓ SERVICE_URLS         → Step 4 ServiceClient 초기화
         ↓ ROUTE_RULES          → 경로 → 서비스 매핑
         ↓ authMiddleware        → JWT 검증 위임 (user-service)
              │
              ▼
[Step 4] service-communication.ts
         ↓ ServiceClient        → Step 5 Saga 각 단계에서 사용
         ↓ EventBus             → Step 5 이벤트 발행
         ↓ publishEvent         → Step 5 Saga 완료 후 이벤트 발행
              │
              ▼
[Step 5] saga-transaction.ts
         ↑ 모든 단계의 산출물을 통합
         — 분산 트랜잭션을 Saga 패턴으로 조율
```

---

## 파일 구조

```
microservices/
├── step1_boundaries/
│   └── service-boundaries.ts     # 경계 컨텍스트, 엔티티 소유, 이벤트 목록
│
├── step2_databases/
│   └── db-separation-plan.ts     # 서비스별 DB 엔진, DDL, 마이그레이션 전략
│
├── step3_gateway/
│   └── api-gateway.ts            # 단일 진입점, JWT 인증, 경로 라우팅, Rate Limit
│
├── step4_communication/
│   └── service-communication.ts  # HTTP 클라이언트(Circuit Breaker) + EventBus
│
└── step5_transactions/
    └── saga-transaction.ts        # Saga 오케스트레이터, 주문/취소 Saga
```

---

## 단계별 핵심 결정

### Step 1 — 서비스 경계

| 서비스 | 소유 엔티티 | 포트 |
|--------|-------------|------|
| user-service | User | 3001 |
| order-service | Order, OrderItem | 3002 |
| payment-service | Payment, Refund | 3003 |
| notification-service | NotificationLog | 3004 |

**의존 방향 규칙**:
- `order → user`: 동기 (사용자 존재 확인은 실시간)
- `payment → order`: 동기 (금액 조회는 실시간)
- 나머지: 비동기 이벤트 (알림, 상태 전파)

---

### Step 2 — DB 분리 전략

**Cross-DB FK 금지 원칙**: `orders.user_id`는 `TEXT`로만 저장 (외래키 없음)

3단계 무중단 마이그레이션:
```
Phase 1: 단일 DB 내 스키마 논리 분리 (배포 없음)
Phase 2: 물리 DB 분리 + Dual Write     (이중 쓰기 기간)
Phase 3: 이중 쓰기 종료 + 데이터 검증  (기존 DB 연결 해제)
```

---

### Step 3 — API 게이트웨이

```
클라이언트
    │ :3000
    ▼
Gateway ── JWT 검증 → user-service
    │
    ├─ /auth/*   → user-service   :3001
    ├─ /users/*  → user-service   :3001
    ├─ /orders/* → order-service  :3002
    └─ /payments/* → payment-service :3003
```

---

### Step 4 — 서비스 간 통신

| 호출 방향 | 방식 | 이유 |
|-----------|------|------|
| order → user | 동기 HTTP + Circuit Breaker | 주문 생성 전 즉시 확인 필요 |
| payment → order | 동기 HTTP + Circuit Breaker | 정확한 금액 필요 |
| payment → order (상태) | 비동기 이벤트 | 결제 후 상태 변경 지연 허용 |
| * → notification | 비동기 이벤트 | 알림 실패가 비즈니스에 영향 없음 |

---

### Step 5 — Saga 패턴

**주문 생성 Saga** (`OrderPlacementSaga`):
```
validate-user   → create-order   → process-payment → publish-event
     ↓                ↓                  ↓
 (보상없음)    취소(cancelled)       환불 처리
```

**주문 취소 Saga** (`OrderCancellationSaga`):
```
cancel-order   →   refund-payment   →   publish-event
     ↓                  ↓
상태 paid 복원    [수동처리] 불가
```

---

## 실행 순서

```bash
# 1. 서비스 경계 검증
npx ts-node -e "
  const { validateBoundaries } = require('./step1_boundaries/service-boundaries');
  console.log(validateBoundaries());
"

# 2. DB 커버리지 검증
npx ts-node -e "
  const { validateDbCoverage } = require('./step2_databases/db-separation-plan');
  console.log(validateDbCoverage());
"

# 3. 게이트웨이 실행
GATEWAY_PORT=3000 npx ts-node step3_gateway/api-gateway.ts

# 4. 주문 생성 Saga 테스트
npx ts-node -e "
  const { runOrderPlacementSaga } = require('./step5_transactions/saga-transaction');
  runOrderPlacementSaga({
    userId: 'USER001',
    items: [{ productId: 'P1', name: '노트북', quantity: 1, price: 1500000 }],
    paymentMethod: { type: 'card', cardNumber: '4242...' }
  }).then(console.log);
"
```
