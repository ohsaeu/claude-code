# API 응답 시간 최적화 — 5단계 가이드

## 문제 진단 흐름

```
느린 API 응답
    │
    ▼
[Step 1] 응답 시간 측정 → 병목 위치 파악
    │
    ├─ DB가 60%↑ 차지  → [Step 2] DB 쿼리 최적화
    ├─ 외부 API > 200ms → [Step 3] 네트워크 최적화
    └─ 반복 조회 패턴  → [Step 4] 캐싱 전략
    │
    ▼
[Step 5] 부하 테스트로 Before/After 검증
```

---

## 단계별 파일 구조

```
api_performance/
├── step1_profiling/
│   ├── responseTimeMiddleware.ts   # 구간별 시간 측정 미들웨어
│   └── bottleneckReport.ts         # 병목 자동 분류 (DB/외부API/직렬화)
│
├── step2_db/
│   └── queryOptimizer.ts           # N+1 제거, 인덱스, Cursor Pagination
│
├── step3_network/
│   └── networkOptimizer.ts         # Keep-Alive, 병렬 호출, Circuit Breaker
│
├── step4_cache/
│   └── cacheStrategy.ts            # L1 LRU + L2 Redis + HTTP Cache-Control
│
└── step5_verify/
    ├── loadTest.ts                 # 부하 테스트 엔진 (Before/After 비교)
    └── optimizedApp.ts             # 모든 최적화가 통합된 Express 앱
```

---

## 단계별 핵심 내용

### Step 1 — 병목 식별

| 측정 구간 | API에서의 의미 |
|-----------|---------------|
| `db`      | ORM 쿼리 실행 시간 |
| `external_api` | 결제/알림 등 외부 호출 |
| `serialize` | JSON 직렬화 |
| 나머지 | 비즈니스 로직 |

**진단 기준**:
- DB 시간 > 전체의 60% → Step 2
- 외부 API > 200ms → Step 3 Circuit Breaker
- 전체 > 300ms + 동일 패턴 반복 → Step 4 캐싱

---

### Step 2 — DB 쿼리 최적화

| 문제 | 해결 | 효과 |
|------|------|------|
| N+1 쿼리 | Eager Loading (`include`) | 11 → 1 쿼리 |
| OFFSET Pagination | Cursor-based Pagination | O(n) → O(1) |
| SELECT * | 필요 컬럼만 명시 | 네트워크 I/O ↓ |
| 인덱스 누락 | 복합 인덱스 추가 | Full Scan 제거 |

```typescript
// ❌ BEFORE — N+1
for (const recipe of recipes) {
  recipe.author = await User.findByPk(recipe.userId);  // 매번 쿼리
}

// ✅ AFTER — Eager Loading
Recipe.findAll({
  include: [{ model: User, as: 'author', attributes: ['id', 'name'] }]
})
```

---

### Step 3 — 네트워크 최적화

| 항목 | 설정 | 효과 |
|------|------|------|
| Keep-Alive | `keepAliveTimeout = 65초` | TCP 핸드셰이크 재사용 |
| gzip 압축 | `compression({ level: 6 })` | 응답 크기 70% 감소 |
| 병렬 호출 | `Promise.all([...])` | 합산시간 → 최대시간 |
| Circuit Breaker | 5회 실패 시 30초 차단 | 외부 장애 격리 |

```typescript
// ❌ BEFORE — 순차: 80 + 120 + 60 = 260ms
const profile = await getProfile(userId);
const orders  = await getOrders(userId);
const points  = await getPoints(userId);

// ✅ AFTER — 병렬: max(80, 120, 60) = 120ms
const [profile, orders, points] = await Promise.all([
  getProfile(userId), getOrders(userId), getPoints(userId),
]);
```

---

### Step 4 — 캐싱 전략

**2-레벨 캐시 계층**:
```
요청
 │
 ▼
L1 LRU (프로세스 내, <1ms) ─ HIT → 반환
 │ MISS
 ▼
L2 Redis (공유 캐시, <5ms) ─ HIT → L1에도 저장 후 반환
 │ MISS
 ▼
DB 조회 → L1 + L2 저장 후 반환
```

**TTL 정책**:

| 데이터 유형 | TTL | 이유 |
|------------|-----|------|
| 레시피 목록 | 5분 | 변경 빈도 낮음 |
| 레시피 상세 | 10분 | 변경 빈도 낮음 |
| 사용자 프로필 | 2분 | 팔로워 수 변동 |
| 검색 결과 | 1분 | 실시간성 필요 |
| 마스터 데이터 | 24시간 | 거의 변경 없음 |

---

### Step 5 — 검증 목표

| 지표 | 목표 |
|------|------|
| p95 응답 시간 | < 200ms |
| 오류율 | < 1% |
| 캐시 히트율 | > 70% |
| 처리량(RPS) | 최적화 전 대비 3× 이상 |

**실행 방법**:
```bash
# 서버 실행
API_URL=http://localhost:3000 npx ts-node step5_verify/loadTest.ts
```

**성능 메트릭 확인**:
```bash
curl http://localhost:3000/api/metrics
```

---

## 최적화 적용 순서 (우선순위)

1. **즉시 적용** (코드 변경 최소): 응답 압축, HTTP 캐시 헤더, Keep-Alive
2. **높은 효과** (1~2일): N+1 쿼리 제거, 인덱스 추가
3. **중기 적용** (3~5일): Redis 캐시 도입, Circuit Breaker
4. **장기 적용** (1~2주): 부하 테스트 자동화, 메트릭 대시보드 연동
