# 시스템 운영 Runbook

**프로젝트**: runbook-api
**작성일**: 2026-03-18
**대상 독자**: 운영팀, On-Call 엔지니어

---

## 목차

1. [시스템 구성](#1-시스템-구성)
2. [모니터링 시스템](#2-모니터링-시스템)
3. [알림별 대응 절차](#3-알림별-대응-절차)
4. [장애 대응 절차](#4-장애-대응-절차)
5. [서비스 재시작 방법](#5-서비스-재시작-방법)
6. [성능 이슈 진단](#6-성능-이슈-진단)
7. [로그 분석 가이드](#7-로그-분석-가이드)
8. [비상 연락처](#8-비상-연락처)

---

## 1. 시스템 구성

### 서비스 토폴로지

```
인터넷
  │
  ▼
Nginx (80/443)        ← 로드밸런서 / SSL 종단
  │
  ▼
app:3000              ← Node.js API (runbook-api)
  ├── postgresql:5432  ← 주 데이터베이스
  └── redis:6379       ← 캐시 / 세션
```

### 서비스 목록 및 포트

| 서비스 | 포트 | 역할 |
|--------|------|------|
| nginx | 80, 443 | 리버스 프록시, SSL |
| app (Node.js) | 3000 | API 서버 |
| postgresql | 5432 | 데이터베이스 |
| redis | 6379 | 캐시 |

### 헬스체크 엔드포인트

| 엔드포인트 | 목적 | 정상 응답 |
|------------|------|-----------|
| `GET /health` | 기본 상태 | `{"status":"healthy"}` |
| `GET /api/v1/status` | API 상태 | HTTP 200 |
| `GET /api/v1/metrics` | 메트릭 | HTTP 200 |
| `GET /api/v1/db-check` | DB 연결 | `{"database":"connected"}` |
| `GET /api/v1/cache-check` | Redis 연결 | `{"cache":"connected"}` |

---

## 2. 모니터링 시스템

### 구성

| 도구 | 포트 | 역할 |
|------|------|------|
| Prometheus | 9090 | 메트릭 수집 (수집 주기: 15s) |
| Grafana | 3000 | 대시보드 시각화 |
| AlertManager | 9093 | 알림 라우팅 |
| Node Exporter | 9100 | 시스템 메트릭 수집 |
| PostgreSQL Exporter | 9187 | DB 메트릭 수집 |

### Prometheus 스크랩 대상

| Job | 대상 | 수집 주기 |
|-----|------|-----------|
| prometheus | localhost:9090 | 15s |
| node-exporter | localhost:9100 | 15s |
| web-service | web-service:8080 `/metrics` | **5s** (고빈도) |
| database | postgres-exporter:9187 | 15s |
| application | app:3000 `/actuator/prometheus` | 15s |

### Grafana 대시보드

**접속**: http://localhost:3000 (계정: admin / admin)
**대시보드**: "System Monitoring Dashboard"

| 패널 | 메트릭 쿼리 | 임계값 |
|------|------------|--------|
| CPU Usage | `100 - irate(node_cpu_seconds_total{mode="idle"}[5m]) * 100` | 황색 ≥70%, 적색 ≥85% |
| Memory Usage | `(1 - MemAvailable/MemTotal) * 100` | 황색 ≥75%, 적색 ≥90% |
| HTTP Response Time | `http_request_duration_seconds{quantile="0.95"}` | p95 기준 |
| Error Rate | `rate(http 5xx[5m]) / rate(http total[5m]) * 100` | 비율 % |

대시보드 새로고침 주기: **5초** / 기본 시간 범위: 최근 1시간

### 모니터링 스택 실행

```bash
# 모니터링 스택 전체 기동
docker-compose -f monitoring/config/docker-compose.yml up -d

# 상태 확인
docker-compose -f monitoring/config/docker-compose.yml ps

# Prometheus 설정 리로드 (재시작 없이)
curl -X POST http://localhost:9090/-/reload
```

---

## 3. 알림별 대응 절차

`alerts.yml`에 정의된 6개 알림의 조건과 대응 절차입니다.

---

### 🔴 CRITICAL: ServiceDown

**조건**: `up == 0` — 서비스가 1분 이상 응답 없음
**영향**: 전체 서비스 중단

**즉시 대응 (목표: 5분 이내)**:

```bash
# 1. 어떤 서비스가 다운됐는지 확인
systemctl status nginx app postgresql redis

# 2. 프로세스 존재 여부 확인
ps aux | grep -E "(node|nginx|postgres|redis)"

# 3. 포트 리스닝 확인
ss -tlnp | grep -E "(80|443|3000|5432|6379)"

# 4. 의존성 순서대로 재시작
sudo ./monitoring/scripts/restart-services.sh all

# 5. 복구 확인
curl -f http://localhost:3000/health
```

**Prometheus에서 다운된 서비스 확인**:
```
# Prometheus 쿼리
up == 0
```

---

### 🔴 CRITICAL: HighMemoryUsage

**조건**: 메모리 사용률 > **85%** 지속 **5분**
**영향**: OOM Killer 발동 위험, 서비스 불안정

**즉시 대응**:

```bash
# 1. 현재 메모리 상태 확인
free -h
# 출력 예: Mem: 15G total, 13G used → 86% 사용 중

# 2. 메모리 점유 상위 프로세스 확인
ps aux --sort=-%mem | head -10

# 3. Node.js 앱 힙 메모리 확인
curl -s http://localhost:3000/api/v1/metrics | grep -E "memory|heap"

# 4. 캐시 메모리 (Redis) 확인
redis-cli info memory | grep used_memory_human

# 5. Node.js 프로세스 힙 덤프 (메모리 누수 의심 시)
kill -USR2 $(pgrep -f "node src/app.js")
# heap dump가 현재 디렉터리에 생성됨

# 6. 즉각 완화: 앱 재시작 (힙 초기화)
sudo ./monitoring/scripts/restart-services.sh app
```

**에스컬레이션 기준**: 재시작 후에도 10분 내에 85% 재도달 → 시니어 엔지니어 호출

---

### 🔴 CRITICAL: DiskSpaceLow

**조건**: 루트(`/`) 디스크 사용률 > **90%** 지속 **1분**
**영향**: 로그/DB 쓰기 실패, 서비스 전체 중단 가능

**즉시 대응**:

```bash
# 1. 디스크 사용량 전체 확인
df -h

# 2. 큰 파일/디렉터리 찾기
du -sh /var/log/* 2>/dev/null | sort -hr | head -10
du -sh /tmp/* 2>/dev/null | sort -hr | head -5

# 3. 오래된 배포 로그 정리
ls -t deployment/logs/*.log | tail -n +11 | xargs rm -f

# 4. Docker 이미지/컨테이너 정리
docker system prune -f
docker image prune -a -f   # 태그 없는 이미지 전체 삭제

# 5. 오래된 DB 백업 정리 (최근 5개 유지)
ls -t backups/db_backup_*.sql | tail -n +6 | xargs rm -f

# 6. 로그 강제 로테이션
sudo logrotate -f /etc/logrotate.conf

# 7. 임시 파일 정리
find /tmp -type f -atime +3 -delete
```

**복구 확인**: `df -h` 로 사용률 85% 미만 확인

---

### 🔴 CRITICAL: HighErrorRate

**조건**: HTTP 5xx 비율 > **10%** 지속 **2분**
**영향**: 사용자 요청 10건 중 1건 이상 오류

**즉시 대응**:

```bash
# 1. 실시간 에러 로그 확인
kubectl logs -f deployment/runbook-api -n production 2>/dev/null \
    || journalctl -u app -f

# 2. 에러 상세 패턴 확인
kubectl logs deployment/runbook-api -n production --since=5m \
    | grep -E "ERROR|FATAL|UnhandledPromise"

# 3. API 상태 직접 확인
curl -sv http://localhost:3000/api/v1/status

# 4. DB 연결 상태 확인
curl -s http://localhost:3000/api/v1/db-check

# 5. Redis 연결 상태 확인
curl -s http://localhost:3000/api/v1/cache-check

# 6. 원인 불명 시 앱 롤링 재시작
kubectl rollout restart deployment/runbook-api -n production
```

**Prometheus에서 에러율 확인**:
```promql
rate(http_requests_total{status=~"5.."}[5m])
/ rate(http_requests_total[5m]) * 100
```

---

### ⚠️ WARNING: HighCpuUsage

**조건**: CPU 사용률 > **80%** 지속 **2분**
**영향**: 응답 지연 시작, 에러율 상승 전조

**대응 절차**:

```bash
# 1. CPU 사용 상위 프로세스 확인
top -bn1 | head -20
# 또는
ps aux --sort=-%cpu | head -10

# 2. Node.js 이벤트 루프 지연 확인 (메트릭 서버 설정 시)
curl -s http://localhost:3000/api/v1/metrics | grep event_loop

# 3. 느린 DB 쿼리가 원인인지 확인
psql -h localhost -U runbook -d runbook_dev -c "
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC
LIMIT 5;"

# 4. 특정 프로세스의 CPU 사용 패턴 분석
pidstat -u 5 3

# 5. Kubernetes: 수평 스케일 아웃 (프로덕션)
kubectl scale deployment runbook-api --replicas=4 -n production
```

**경고 지속 시**: 10분 내 해소되지 않으면 CRITICAL로 에스컬레이션

---

### ⚠️ WARNING: HighResponseTime

**조건**: p95 응답 시간 > **2초** 지속 **3분**
**영향**: 사용자 체감 품질 저하

**대응 절차**:

```bash
# 1. 현재 응답 시간 직접 측정
curl -w "\nTotal: %{time_total}s\nConnect: %{time_connect}s\nTTFB: %{time_starttransfer}s\n" \
    -s -o /dev/null http://localhost:3000/api/v1/ping

# 2. Prometheus에서 p95 추이 확인
# http://localhost:9090/graph
# 쿼리: http_request_duration_seconds{quantile="0.95"}

# 3. 느린 쿼리 확인 (PostgreSQL)
psql -h localhost -U runbook -d runbook_dev -c "
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;"

# 4. Redis 지연 확인
redis-cli --latency -h localhost

# 5. Nginx 업스트림 응답 시간 확인
tail -100 /var/log/nginx/access.log \
    | awk '{print $NF}' \
    | sort -n \
    | tail -10
```

---

## 4. 장애 대응 절차

### 심각도 분류

| 레벨 | 기준 | 목표 복구 시간 | 에스컬레이션 |
|------|------|---------------|-------------|
| P1 (Critical) | 서비스 전체 중단 | 30분 | 즉시 팀장 + CTO |
| P2 (High) | 주요 기능 장애, 에러율 > 10% | 2시간 | 시니어 엔지니어 |
| P3 (Medium) | 성능 저하, 일부 기능 이상 | 4시간 | 담당 엔지니어 |
| P4 (Low) | 경고 수준, 사용자 영향 없음 | 다음 근무일 | 티켓 생성 |

### 장애 대응 단계

#### 단계 1 — 상황 파악 (1~2분)

```bash
# Grafana 대시보드 확인
open http://localhost:3000  # "System Monitoring Dashboard"

# 전체 서비스 상태 한눈에 보기
systemctl status nginx app postgresql redis --no-pager

# 최근 5분 에러 로그
journalctl -u app --since "5 minutes ago" | grep -E "ERROR|FATAL"
```

#### 단계 2 — 긴급 복구 (5분 이내)

```bash
# 표준 재시작 스크립트 실행 (root 권한 필요)
sudo ./monitoring/scripts/restart-services.sh all

# 복구 확인
curl -f http://localhost:3000/health \
    && echo "✅ 서비스 정상" \
    || echo "❌ 복구 실패 - 에스컬레이션 필요"
```

#### 단계 3 — 서비스별 선택적 재시작

복구가 안 될 경우 의존성 순서대로 개별 재시작:

```bash
# 1순위: 데이터베이스 (app의 의존 서비스)
sudo ./monitoring/scripts/restart-services.sh postgresql

# 2순위: 캐시
sudo ./monitoring/scripts/restart-services.sh redis

# 3순위: 애플리케이션
sudo ./monitoring/scripts/restart-services.sh app

# 4순위: 웹 서버 (app이 살아있어야 의미 있음)
sudo ./monitoring/scripts/restart-services.sh nginx
```

#### 단계 4 — 롤백 (코드 문제인 경우)

```bash
# 배포 직후 장애 → 즉시 롤백
npm run rollback:prod

# 또는 Kubernetes 직접 롤백
kubectl rollout undo deployment/runbook-api -n production
kubectl rollout status deployment/runbook-api -n production --timeout=300s
```

#### 단계 5 — 근본 원인 분석 (복구 후)

1. 장애 시점 전후 Grafana 메트릭 스크린샷 저장
2. 관련 로그 수집: `journalctl -u app --since "1 hour ago" > incident_$(date +%Y%m%d_%H%M).log`
3. 타임라인 재구성: 최초 알림 시각 → 감지 → 대응 → 복구
4. 인시던트 리포트 작성 (원인, 영향 범위, 재발 방지 방안)

---

## 5. 서비스 재시작 방법

### 자동 재시작 스크립트

`monitoring/scripts/restart-services.sh` 특성:
- **root 권한 필수**
- 재시작 전 **의존성 자동 확인** (app 재시작 전 postgresql 확인, nginx 재시작 전 app 확인)
- 각 서비스 재시작 후 **5초 대기 + 상태 검증**
- 결과를 `/var/log/service-restart.log`에 기록

```bash
# 전체 서비스 재시작 (권장 순서: nginx → postgresql → app → redis)
sudo ./monitoring/scripts/restart-services.sh all

# 특정 서비스만 재시작
sudo ./monitoring/scripts/restart-services.sh nginx
sudo ./monitoring/scripts/restart-services.sh postgresql
sudo ./monitoring/scripts/restart-services.sh app
sudo ./monitoring/scripts/restart-services.sh redis
```

### 수동 재시작 (서비스별 상세)

#### PostgreSQL

```bash
# 정상 재시작
sudo systemctl stop postgresql
sleep 5
sudo systemctl start postgresql

# 상태 확인
sudo systemctl status postgresql
sudo -u postgres psql -c "SELECT version();"

# 연결 수 확인
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
```

#### Redis

```bash
sudo systemctl restart redis

# PONG 응답 확인
redis-cli ping

# 메모리/연결 상태 확인
redis-cli info server | grep -E "redis_version|uptime"
redis-cli info memory | grep used_memory_human
```

#### App (Node.js)

```bash
# Graceful Shutdown 후 재시작
sudo systemctl stop app
sleep 5  # 진행 중인 요청 처리 완료 대기
sudo systemctl start app

# 헬스체크 대기 (최대 60초)
for i in $(seq 1 12); do
    sleep 5
    if curl -sf http://localhost:3000/health | grep -q '"status":"healthy"'; then
        echo "✅ App is healthy"
        break
    fi
    echo "⏳ Waiting... ($((i*5))s)"
done
```

#### Nginx

```bash
# 설정 파일 문법 검사 (재시작 전 필수)
sudo nginx -t

# 무중단 설정 리로드 (권장)
sudo nginx -s reload

# 전체 재시작 (설정 리로드로 안 될 때)
sudo systemctl restart nginx
curl -I http://localhost/  # 응답 헤더 확인
```

### Kubernetes 환경 재시작 (프로덕션)

```bash
# 롤링 재시작 (무중단)
kubectl rollout restart deployment/runbook-api -n production

# 재시작 진행 상황 확인
kubectl rollout status deployment/runbook-api -n production

# 특정 파드만 강제 삭제 (자동 재생성)
kubectl delete pod <pod-name> -n production

# 파드 상태 실시간 모니터링
kubectl get pods -n production -l app=runbook-api -w
```

---

## 6. 성능 이슈 진단

### 진단 흐름도

```
응답 느림 / 에러 발생
       │
       ├─ CPU > 80%? ──→ [CPU 진단]
       │
       ├─ Memory > 85%? ──→ [메모리 진단]
       │
       ├─ DB 응답 느림? ──→ [DB 진단]
       │
       └─ Redis 연결 문제? ──→ [Redis 진단]
```

### CPU 이슈 진단

```bash
# 1. CPU 사용률 및 Load Average 확인
top -bn1 | grep -E "Cpu|load average"
# load average가 CPU 코어 수를 초과하면 포화 상태

# 2. 프로세스별 CPU 점유
ps aux --sort=-%cpu | head -10

# 3. Node.js 프로세스가 CPU를 독점하는 경우
# → 무한 루프 또는 동기 블로킹 코드 의심
strace -p $(pgrep -f "node src/app.js") -e trace=all -c 2>&1 | head -20

# 4. I/O 대기(wa) 높은 경우 → 디스크 I/O 문제
iostat -x 2 5 | awk '/^[a-z]/{print $1, $14}'  # %util 컬럼

# 5. Kubernetes 파드별 CPU 확인
kubectl top pods -n production --sort-by=cpu
```

### 메모리 이슈 진단

```bash
# 1. 전체 메모리 현황
free -h

# 2. Node.js 힙 메모리 현황 (앱 메트릭에서)
curl -s http://localhost:3000/api/v1/metrics \
    | grep -E "heap|memory"

# 3. 프로세스별 메모리 (RSS 기준)
ps aux --sort=-%mem | awk 'NR<=10 {print $2, $4, $11}'

# 4. 메모리 누수 패턴 확인 (시간에 따라 증가하는지)
# Grafana에서 Memory Usage 패널 → 시간 범위 6시간으로 확인
# 지속적으로 우상향 곡선이면 누수 의심

# 5. Redis 메모리가 원인인 경우
redis-cli info memory
redis-cli info stats | grep evicted_keys  # 0이 아니면 메모리 부족
```

### 데이터베이스 이슈 진단

```bash
# 1. DB 응답 기본 확인
time psql -h localhost -U runbook -d runbook_dev -c "SELECT 1;"

# 2. 현재 실행 중인 쿼리 확인
psql -h localhost -U runbook -d runbook_dev -c "
SELECT pid,
       now() - query_start AS duration,
       state,
       left(query, 80) AS query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC
LIMIT 10;"

# 3. 락 대기 확인 (락 경합이 있으면 응답 느려짐)
psql -h localhost -U runbook -d runbook_dev -c "
SELECT blocked_locks.pid AS blocked_pid,
       blocking_locks.pid AS blocking_pid,
       left(blocked_activity.query, 60) AS blocked_query
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.granted
    AND NOT blocked_locks.granted
JOIN pg_catalog.pg_stat_activity blocked_activity
    ON blocked_activity.pid = blocked_locks.pid;"

# 4. 느린 쿼리 통계 (pg_stat_statements 활성화 시)
psql -h localhost -U runbook -d runbook_dev -c "
SELECT left(query, 60), calls, round(mean_exec_time::numeric, 2) AS avg_ms
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 5;"

# 5. 커넥션 풀 상태 확인
psql -h localhost -U runbook -d runbook_dev -c "
SELECT state, count(*)
FROM pg_stat_activity
GROUP BY state;"
```

### Redis 이슈 진단

```bash
# 1. 기본 응답성 확인
redis-cli ping
redis-cli --latency -h localhost -n 5

# 2. 메모리 / 히트율 확인
redis-cli info stats | grep -E "keyspace_hits|keyspace_misses"
# hit_rate = hits / (hits + misses) * 100 → 80% 미만이면 캐시 효율 저하

# 3. 느린 명령 확인 (slowlog)
redis-cli slowlog get 10

# 4. 연결 수 확인
redis-cli info clients | grep connected_clients
```

---

## 7. 로그 분석 가이드

### 로그 위치

```
deployment/logs/
├── deploy_<env>_<timestamp>.log       # 배포 실행 로그
├── rollback_<env>_<timestamp>.log     # 롤백 실행 로그
├── last_deployment_<env>.json         # 최근 배포 상태

/var/log/
├── service-restart.log                # 서비스 재시작 이력
├── nginx/access.log                   # Nginx 접근 로그
└── nginx/error.log                    # Nginx 에러 로그
```

### 애플리케이션 로그 분석

```bash
# 실시간 에러 확인
journalctl -u app -f | grep -E "ERROR|FATAL|UnhandledPromise"

# 최근 1시간 에러 빈도
journalctl -u app --since "1 hour ago" \
    | grep "ERROR" \
    | awk '{print $1, $2}' \
    | cut -c1-16 \
    | uniq -c \
    | sort -nr

# 특정 에러 패턴 검색
journalctl -u app --since "30 minutes ago" \
    | grep -E "ECONNREFUSED|ETIMEDOUT|heap out of memory"

# Kubernetes 로그 (프로덕션)
kubectl logs deployment/runbook-api -n production --since=1h \
    | grep ERROR | tail -20

# 이전 파드 로그 (크래시 후)
kubectl logs deployment/runbook-api -n production --previous
```

### Nginx 로그 분석

```bash
# 상태 코드별 통계
awk '{print $9}' /var/log/nginx/access.log \
    | sort | uniq -c | sort -nr

# 에러율 계산 (5xx)
awk '{if($9 >= 500) err++; total++}
     END {printf "Error rate: %.2f%%\n", err/total*100}' \
    /var/log/nginx/access.log

# 응답 시간 느린 요청 (2초 이상)
awk '$NF > 2.0 {print $7, $9, $NF"s"}' /var/log/nginx/access.log \
    | sort -k3 -nr | head -10

# 최근 5분간 트래픽
awk -v cutoff="$(date -d '5 minutes ago' '+%d/%b/%Y:%H:%M')" \
    '$4 > "["cutoff {print}' /var/log/nginx/access.log | wc -l
```

### 서비스 재시작 이력 확인

```bash
# restart-services.sh 실행 이력
cat /var/log/service-restart.log

# 오늘 재시작 건수
grep "$(date '+%Y-%m-%d')" /var/log/service-restart.log \
    | grep -c "Attempting to restart"

# 실패한 재시작 확인
grep "ERROR: Failed" /var/log/service-restart.log
```

### 배포 이력 확인

```bash
# 최근 프로덕션 배포 정보
cat deployment/logs/last_deployment_production.json

# 배포 로그에서 에러 확인
grep -E "\[ERROR\]|\[WARNING\]" deployment/logs/deploy_production_*.log \
    | tail -20
```

### 종합 에러 리포트 생성

```bash
#!/bin/bash
# 장애 발생 시 즉시 실행하여 상황 파악

REPORT="incident_report_$(date +%Y%m%d_%H%M%S).txt"
echo "=== 인시던트 리포트 $(date) ===" > "$REPORT"

echo -e "\n[서비스 상태]" >> "$REPORT"
systemctl status nginx app postgresql redis --no-pager >> "$REPORT" 2>&1

echo -e "\n[최근 배포]" >> "$REPORT"
cat deployment/logs/last_deployment_production.json >> "$REPORT" 2>&1

echo -e "\n[앱 최근 에러 (30분)]" >> "$REPORT"
journalctl -u app --since "30 minutes ago" \
    | grep -E "ERROR|FATAL" | tail -20 >> "$REPORT"

echo -e "\n[Nginx 5xx 에러 (최근 100건)]" >> "$REPORT"
awk '$9 >= 500' /var/log/nginx/access.log | tail -20 >> "$REPORT" 2>&1

echo -e "\n[DB 활성 쿼리]" >> "$REPORT"
psql -h localhost -U runbook -d runbook_dev -c \
    "SELECT now()-query_start AS duration, state, left(query,80)
     FROM pg_stat_activity WHERE state != 'idle'
     ORDER BY duration DESC LIMIT 5;" >> "$REPORT" 2>&1

echo "리포트 생성: $REPORT"
cat "$REPORT"
```

---

## 8. 비상 연락처

### On-Call 에스컬레이션

| 레벨 | 담당 | 연락처 | 응답 목표 |
|------|------|--------|-----------|
| L1 | 운영팀 On-Call (24/7) | 010-XXXX-XXXX | 5분 |
| L2 | 시니어 엔지니어 | 010-YYYY-YYYY | 15분 |
| L3 | 팀 리더 / 관리자 | 010-ZZZZ-ZZZZ | 30분 |

**Slack 채널**: `#ops-emergency` (P1/P2 즉시 알림)

### 장애 시 Slack 수동 알림

```bash
# 긴급 상황 알림 (SLACK_WEBHOOK_URL 설정 시)
curl -X POST -H 'Content-type: application/json' \
    --data '{"text":"🚨 [P1] Production 서비스 장애 발생 - 대응 중"}' \
    "$SLACK_WEBHOOK_URL"

# 복구 알림
curl -X POST -H 'Content-type: application/json' \
    --data '{"text":"✅ Production 서비스 복구 완료"}' \
    "$SLACK_WEBHOOK_URL"
```

### 외부 서비스

- **클라우드 (AWS)**: AWS Support Console
- **Kubernetes 클러스터 문제**: 인프라팀 (infra@company.com)
- **도메인/DNS 문제**: 네트워크팀

---

## 체크리스트

### 장애 발생 시

```
[ ] Grafana 대시보드 열기 (어떤 메트릭이 이상한지 확인)
[ ] 전체 서비스 상태 확인: systemctl status nginx app postgresql redis
[ ] 최근 배포 이력 확인: cat deployment/logs/last_deployment_production.json
[ ] 에러 로그 확인: journalctl -u app --since "10 minutes ago" | grep ERROR
[ ] 필요 시 재시작: sudo ./monitoring/scripts/restart-services.sh all
[ ] 복구 확인: curl -f http://localhost:3000/health
[ ] Slack 채널 상황 공유
[ ] 필요 시 롤백: npm run rollback:prod
[ ] 인시던트 리포트 작성
```

### 정기 점검 (주 1회)

```
[ ] Prometheus 알림 규칙 정상 동작 확인
[ ] Grafana 대시보드 패널 데이터 수집 정상 여부
[ ] /var/log/service-restart.log 재시작 빈도 검토
[ ] 백업 파일 정상 생성 여부: ls -lh backups/
[ ] SSL 인증서 만료일 확인 (30일 이내 갱신)
[ ] 디스크 사용량 트렌드 확인 (df -h)
[ ] 미해결 경고(WARNING) 알림 검토 및 처리
```

---

**문서 버전**: 2.0
**최종 수정일**: 2026-03-18
**작성자**: DevOps Team
**관련 문서**: [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md), [OPERATION.md](./OPERATION.md)
