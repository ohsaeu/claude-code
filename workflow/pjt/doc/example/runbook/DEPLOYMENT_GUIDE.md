# 배포 가이드 (Deployment Guide)

**프로젝트**: runbook-api
**버전**: 1.0.0
**작성일**: 2026-03-18
**대상 독자**: 개발팀, DevOps팀

---

## 목차

1. [시스템 구성 개요](#1-시스템-구성-개요)
2. [환경 변수 설정](#2-환경-변수-설정)
3. [사전 체크리스트](#3-사전-체크리스트)
4. [환경별 배포 절차](#4-환경별-배포-절차)
   - [개발(Development)](#41-개발development-환경)
   - [스테이징(Staging)](#42-스테이징staging-환경)
   - [프로덕션(Production)](#43-프로덕션production-환경)
5. [배포 후 검증](#5-배포-후-검증)
6. [롤백 방법](#6-롤백-방법)
7. [트러블슈팅](#7-트러블슈팅)

---

## 1. 시스템 구성 개요

### 인프라 스택

| 구성 요소 | 개발 | 스테이징 | 프로덕션 |
|-----------|------|----------|----------|
| 런타임 | PM2 (로컬) | Docker | Kubernetes |
| 포트 | 3000 | 3001 | 80/443 (Nginx LB) |
| 데이터베이스 | PostgreSQL (로컬) | PostgreSQL (Docker) | PostgreSQL (클러스터) |
| 캐시 | Redis (로컬) | Redis (Docker) | Redis (클러스터) |
| URL | http://localhost:3000 | http://staging.runbook-api.com | https://api.runbook.com |

### 주요 런타임 요구사항

```
Node.js >= 18.0.0
npm    >= 8.0.0
```

### 의존 서비스

- **데이터베이스**: PostgreSQL 15 (포트: 5432/5433/5434)
- **캐시**: Redis 7 (포트: 6379/6380/6381)
- **모니터링**: Prometheus (9090) + Grafana (3003)
- **로드밸런서**: Nginx (프로덕션 전용)

---

## 2. 환경 변수 설정

환경 파일 위치: `deployment/config/.env.<environment>`

### 2.1 공통 필수 변수

아래 4개 변수는 **모든 환경에서 반드시 설정**해야 합니다. 누락 시 배포 스크립트가 즉시 중단됩니다.

```bash
# 실행 환경 (development | staging | production)
NODE_ENV=<environment>

# 앱 리스닝 포트
PORT=3000

# 데이터베이스 연결 URL
DATABASE_URL=postgresql://runbook:<password>@<host>:5432/runbook_<env>

# Redis 연결 URL
REDIS_URL=redis://<host>:6379
```

### 2.2 개발 환경 (.env.development)

```bash
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://runbook:dev_password@localhost:5432/runbook_dev
REDIS_URL=redis://localhost:6379
DEBUG=app:*

# 선택사항
SLACK_WEBHOOK_URL=         # 알림 비활성화 시 비워 둠
```

### 2.3 스테이징 환경 (.env.staging)

```bash
NODE_ENV=staging
PORT=3000
DATABASE_URL=postgresql://runbook:<staging_password>@db-staging:5432/runbook_staging
REDIS_URL=redis://redis-staging:6379

# Docker 네트워크 내부 호스트명 사용
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...   # 선택사항
```

### 2.4 프로덕션 환경 (.env.production)

```bash
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://runbook:<prod_password>@db-prod:5432/runbook_prod
REDIS_URL=redis://redis-prod:6379

# 보안 관련
JWT_SECRET=<강력한_랜덤_값>
BCRYPT_ROUNDS=12

# 알림 (권장)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

> **보안 주의**: `.env.production`은 절대 Git에 커밋하지 마십시오.
> 프로덕션 비밀값은 Kubernetes Secret 또는 AWS Secrets Manager를 사용하세요.

### 2.5 환경 변수 검증 방법

```bash
# 배포 전 필수 변수 확인
source deployment/config/.env.<environment>
for var in NODE_ENV PORT DATABASE_URL REDIS_URL; do
    echo "$var=${!var}"
done
```

---

## 3. 사전 체크리스트

### 3.1 공통 체크리스트 (모든 환경)

배포 시작 전 아래 항목을 순서대로 확인하세요.

```
[ ] Node.js >= 18.0.0 설치 확인
    $ node --version

[ ] npm >= 8.0.0 설치 확인
    $ npm --version

[ ] 올바른 Git 브랜치에 있는지 확인
    $ git branch --show-current

[ ] 최신 코드 동기화 완료
    $ git pull origin <branch>

[ ] 환경 파일 존재 여부 확인
    $ ls deployment/config/.env.<environment>

[ ] 배포 스크립트 실행 권한 확인
    $ ls -la deployment/scripts/

[ ] 의존성 보안 취약점 확인
    $ npm audit --audit-level high

[ ] 린트 통과 확인
    $ npm run lint

[ ] 테스트 전체 통과 확인
    $ npm test
```

### 3.2 스테이징 추가 체크리스트

```
[ ] Docker 데몬 실행 중 확인
    $ docker info

[ ] 기존 스테이징 컨테이너 상태 확인
    $ docker ps | grep runbook-staging

[ ] 포트 3001 사용 가능 여부 확인
    $ lsof -i :3001
```

### 3.3 프로덕션 추가 체크리스트

```
[ ] 팀 배포 승인 완료 (PR 리뷰 + 승인)

[ ] 스테이징에서 동일 버전 검증 완료

[ ] 데이터베이스 마이그레이션 계획 확인
    (스키마 변경이 있을 경우)

[ ] kubectl 클러스터 연결 확인
    $ kubectl cluster-info
    $ kubectl get nodes

[ ] 프로덕션 네임스페이스 접근 권한 확인
    $ kubectl get pods -n production

[ ] 현재 배포 버전 기록
    $ kubectl rollout history deployment/runbook-api -n production

[ ] DB 백업 공간 충분 여부 확인
    $ df -h ./backups

[ ] 배포 시간대 확인 (트래픽 저점 권장)

[ ] 모니터링 대시보드 열어 두기
    http://grafana:3003
```

---

## 4. 환경별 배포 절차

### 4.1 개발(Development) 환경

**배포 방식**: PM2 프로세스 매니저로 로컬 서비스 재시작

#### 빠른 시작

```bash
# npm 스크립트로 한 번에 배포
npm run deploy:dev
```

#### 단계별 수동 배포

```bash
# 1. 의존성 설치 (devDependencies 포함)
npm ci --production=false

# 2. 코드 품질 검사
npm run lint

# 3. 테스트 실행
npm test

# 4. 보안 감사
npm audit --audit-level high

# 5. PM2로 서비스 재시작/시작
pm2 reload ecosystem.config.js --env development \
    || pm2 start ecosystem.config.js --env development

# 6. 헬스체크 (서비스 기동 후 30초 대기)
sleep 30
npm run health-check development

# 7. 스모크 테스트
npm run smoke-test development
```

#### Docker를 사용하는 경우 (선택사항)

```bash
# 개발용 이미지 빌드 (hot reload 포함)
npm run docker:build:dev

# 컨테이너 실행
npm run docker:run:dev

# 또는 docker-compose 사용
docker-compose -f deployment/docker/docker-compose.yml up app-dev db-dev redis-dev
```

#### 배포 성공 확인

```bash
curl http://localhost:3000/health
# 기대 응답: {"status":"healthy", ...}
```

---

### 4.2 스테이징(Staging) 환경

**배포 방식**: 프로덕션용 Docker 이미지를 빌드하여 컨테이너로 실행

#### 빠른 시작

```bash
# npm 스크립트로 한 번에 배포
npm run deploy:staging
```

#### 단계별 수동 배포

```bash
# 1. 사전 검증 (lint + test + audit 포함)
npm run pre-deploy

# 2. 프로덕션용 Docker 이미지 빌드
#    (내부적으로 테스트 실행 후 멀티스테이지 빌드)
docker build -f deployment/docker/Dockerfile.prod \
    -t runbook-api:staging .

# 3. 기존 스테이징 컨테이너 교체
docker stop runbook-staging  || true
docker rm   runbook-staging  || true

docker run -d \
    --name runbook-staging \
    -p 3001:3000 \
    --env-file deployment/config/.env.staging \
    runbook-api:staging

# 4. 서비스 기동 대기
sleep 30

# 5. 헬스체크
npm run health-check staging

# 6. 스모크 테스트
npm run smoke-test staging
```

#### docker-compose 사용

```bash
docker-compose -f deployment/docker/docker-compose.yml \
    up -d app-staging db-staging redis-staging
```

#### 배포 성공 확인

```bash
curl http://staging.runbook-api.com/health
# 기대 응답: {"status":"healthy", ...}
```

#### 리소스 제한 (docker-compose 기준)

| 리소스 | 제한값 |
|--------|--------|
| Memory | 512 MB |
| CPU    | 0.5 core |

---

### 4.3 프로덕션(Production) 환경

**배포 방식**: Kubernetes Rolling Update
**주의**: 반드시 스테이징 검증 완료 후 진행하세요.

#### 빠른 시작

```bash
# npm 스크립트로 한 번에 배포
npm run deploy:prod
```

#### 단계별 수동 배포

```bash
# 1. 사전 검증 (lint + test + audit)
npm run pre-deploy

# 2. 데이터베이스 백업 (자동 실행되나 수동으로도 확인)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
npm run backup:db
# 백업 파일: ./backups/db_backup_${TIMESTAMP}.sql

# 3. Kubernetes 매니페스트 적용
npm run k8s:deploy:prod
# 또는
kubectl apply -f deployment/k8s/prod/

# 4. 롤아웃 완료 대기 (타임아웃: 300초)
kubectl rollout status deployment/runbook-api \
    -n production --timeout=300s

# 5. 헬스체크 (30초 대기 후)
sleep 30
npm run health-check production

# 6. 스모크 테스트
npm run smoke-test production
```

#### 배포 상태 모니터링

```bash
# 파드 상태 확인
kubectl get pods -n production -l app=runbook-api

# 롤아웃 이력 확인
kubectl rollout history deployment/runbook-api -n production

# 실시간 로그 확인
npm run logs:tail
# 또는
kubectl logs -f deployment/runbook-api -n production
```

#### 배포 성공 확인

```bash
# 메인 API 엔드포인트
curl https://api.runbook.com/health

# 개별 인스턴스 확인 (로드밸런서 뒤)
for i in 1 2 3; do
    curl https://api-${i}.runbook.com/health
done
```

#### 프로덕션 리소스 제한

| 리소스 | 제한값 | 비고 |
|--------|--------|------|
| Memory | 1 GB | Kubernetes limit |
| CPU    | 1.0 core | Kubernetes limit |
| Replicas | 2 | Rolling update |

#### Slack 알림

배포 완료 시 `SLACK_WEBHOOK_URL` 환경 변수가 설정되어 있으면 자동으로 알림이 발송됩니다.

```
✅ Deployment to production completed successfully!
```

---

## 5. 배포 후 검증

### 5.1 헬스체크 항목

`npm run health-check <environment>` 실행 시 자동으로 아래를 검사합니다.

| 검사 항목 | 엔드포인트 | 성공 기준 |
|-----------|------------|-----------|
| 기본 상태 | `GET /health` | HTTP 200 + `"status":"healthy"` |
| API 상태 | `GET /api/v1/status` | HTTP 200 |
| 메트릭 | `GET /api/v1/metrics` | HTTP 200 |
| DB 연결 | `GET /api/v1/db-check` | `"database":"connected"` |
| Redis 연결 | `GET /api/v1/cache-check` | `"cache":"connected"` |

**프로덕션 추가 검사**:
- 메모리 사용률 85% 미만
- CPU 사용률 80% 미만
- 각 인스턴스(api-1, api-2, api-3) 응답 확인
- SSL 인증서 유효성 확인

### 5.2 스모크 테스트 항목

`npm run smoke-test <environment>` 실행 시 자동으로 아래를 검증합니다.

| 테스트 | 내용 | 비고 |
|--------|------|------|
| 1. 기본 API | `GET /api/v1/ping` → `pong` 응답 | 필수 |
| 2. DB CRUD | 레코드 생성/조회/삭제 | 필수 |
| 3. 인증 | 로그인 → JWT 토큰 → 보호 엔드포인트 접근 | 필수 |
| 4. Redis 캐시 | 캐시 쓰기/읽기/삭제 | 필수 |
| 5. 파일 업로드 | 멀티파트 폼 업로드 | 엔드포인트 없으면 건너뜀 |
| 6. WebSocket | 연결 및 ping/pong | wscat 설치 시 |
| 7. Rate Limiting | 429 응답 확인 | 경고만 |
| 8. 에러 처리 | 존재하지 않는 경로 → 404 | 필수 |
| 9. CORS | OPTIONS 요청 → CORS 헤더 | 필수 |
| 10. 프로덕션 전용 | HTTP→HTTPS 리다이렉트, 보안 헤더 | 프로덕션만 |

### 5.3 배포 로그 위치

모든 배포/롤백 기록은 아래 위치에 저장됩니다.

```
deployment/logs/
├── deploy_development_YYYYMMDD_HHMMSS.log   # 배포 실행 로그
├── deploy_staging_YYYYMMDD_HHMMSS.log
├── deploy_production_YYYYMMDD_HHMMSS.log
├── last_deployment_development.json          # 최근 배포 상태 (JSON)
├── last_deployment_staging.json
└── last_deployment_production.json
```

최근 배포 상태 확인:

```bash
cat deployment/logs/last_deployment_production.json
# {
#   "timestamp": "20260318_143000",
#   "environment": "production",
#   "version": "<git-sha>",
#   "deployed_by": "devops",
#   "status": "success"
# }
```

---

## 6. 롤백 방법

> 배포 후 이상 감지 시 즉시 롤백을 진행하세요.
> 프로덕션 롤백은 인터랙티브 확인 프롬프트가 표시됩니다.

### 6.1 빠른 롤백 명령어

```bash
# 개발 환경
npm run rollback:dev

# 스테이징 환경
npm run rollback:staging

# 프로덕션 환경
npm run rollback:prod
```

### 6.2 개발 환경 롤백 (Git 기반)

```bash
# 1. 롤백 스크립트 실행 (버전 목록 표시 후 선택)
./deployment/scripts/rollback.sh development

# 또는 직접 버전 지정
./deployment/scripts/rollback.sh development <git-tag-or-sha>

# 내부 동작:
# git checkout <VERSION>
# npm ci
# pm2 reload ecosystem.config.js --env development
```

### 6.3 스테이징 환경 롤백 (Docker 이미지 기반)

```bash
# 1. 사용 가능한 이미지 목록 확인
docker images runbook-api

# 2. 특정 태그로 롤백
./deployment/scripts/rollback.sh staging <image-tag>

# 내부 동작:
# docker stop runbook-staging
# docker rm runbook-staging
# docker run -d --name runbook-staging -p 3001:3000 \
#     --env-file deployment/config/.env.staging \
#     runbook-api:<VERSION>
```

### 6.4 프로덕션 환경 롤백 (Kubernetes 기반)

#### 일반 롤백 (코드만)

```bash
# 1. 롤아웃 이력 확인
kubectl rollout history deployment/runbook-api -n production

# 2. 이전 버전으로 즉시 롤백
kubectl rollout undo deployment/runbook-api -n production

# 3. 특정 리비전으로 롤백
./deployment/scripts/rollback.sh production <revision-number>

# 4. 롤백 완료 확인 (타임아웃: 300초)
kubectl rollout status deployment/runbook-api -n production --timeout=300s
```

#### DB 포함 롤백 (스키마 변경이 있었던 경우)

```bash
# 주의: 데이터 손실 가능성이 있습니다. 반드시 사전 확인 후 실행하세요.
./deployment/scripts/rollback.sh production <revision> --with-db

# 실행 시:
# 1. 현재 상태 DB 백업 자동 생성
# 2. 복원할 백업 파일 경로 입력 프롬프트 표시
# 3. DB 복원 후 앱 롤백
```

### 6.5 롤백 후 검증

롤백 스크립트는 완료 후 자동으로 아래를 실행합니다.

```bash
# 자동으로 실행됨
sleep 30                                           # 안정화 대기
./deployment/scripts/health-check.sh <environment>  # 헬스체크
./deployment/scripts/smoke-test.sh <environment>    # 스모크 테스트
```

**프로덕션 롤백 시 추가 조치**:
- 롤백 후 1시간 동안 강화 모니터링 플래그 활성화 (`deployment/logs/monitoring_flag`)
- Grafana 대시보드에서 에러율, 응답시간 집중 모니터링
- Slack에 자동 알림 발송 (`⚠️ Rollback in production to version X completed!`)

### 6.6 롤백 결정 기준

아래 상황에서는 즉시 롤백을 고려하세요.

| 상황 | 기준 | 권장 조치 |
|------|------|-----------|
| 에러율 급증 | 5xx 응답 > 5% | 즉시 롤백 |
| 응답 시간 저하 | p99 > 3초 | 원인 파악 후 결정 |
| 헬스체크 실패 | `/health` 미응답 | 즉시 롤백 |
| DB 연결 오류 | 연속 3회 이상 | 즉시 롤백 |
| 스모크 테스트 실패 | 필수 테스트 실패 | 즉시 롤백 |

---

## 7. 트러블슈팅

### 7.1 자주 발생하는 문제

#### 환경 파일 없음

```
[ERROR] Environment file not found: ./deployment/config/.env.production
```

**해결**:
```bash
# 환경 파일 생성 (템플릿 참고)
cp deployment/config/.env.example deployment/config/.env.production
# 값 채운 후 배포 재시도
```

#### 필수 환경 변수 누락

```
[ERROR] Required environment variable DATABASE_URL is not set
```

**해결**: `.env.<environment>` 파일에서 해당 변수 설정 확인

#### npm audit 실패

```
npm audit found high severity vulnerabilities
```

**해결**:
```bash
npm audit fix
# 자동 수정 불가 시
npm audit fix --force   # 주의: 브레이킹 체인지 가능
```

#### Docker 빌드 중 테스트 실패

```
RUN npm run test && npm run build
```

`Dockerfile.prod`는 빌드 시 테스트를 실행합니다. 테스트 실패 시 이미지가 생성되지 않습니다.

```bash
# 먼저 로컬에서 테스트 통과 확인
npm test
```

#### Kubernetes 롤아웃 타임아웃

```
error: timed out waiting for the condition
```

**해결**:
```bash
# 파드 상태 상세 확인
kubectl describe pods -n production -l app=runbook-api

# 파드 로그 확인
kubectl logs -n production -l app=runbook-api --previous

# 강제 롤백
kubectl rollout undo deployment/runbook-api -n production
```

### 7.2 유용한 명령어 모음

```bash
# 실시간 로그 확인
npm run logs:tail

# 헬스체크 단독 실행
npm run health-check <environment>

# 스모크 테스트 단독 실행
npm run smoke-test <environment>

# DB 수동 백업
npm run backup:db

# 모니터링 설정
npm run monitoring:setup

# Docker 이미지 빌드 (prod)
npm run docker:build:prod

# Kubernetes 배포 상태 확인
kubectl rollout status deployment/runbook-api -n production
kubectl get pods -n production -l app=runbook-api
```

---

## 부록: 환경별 URL 및 포트 요약

| 항목 | 개발 | 스테이징 | 프로덕션 |
|------|------|----------|----------|
| API | http://localhost:3000 | http://staging.runbook-api.com | https://api.runbook.com |
| 헬스체크 | localhost:3000/health | staging.runbook-api.com/health | api.runbook.com/health |
| PostgreSQL | localhost:5432 | localhost:5433 | 5434 (내부) |
| Redis | localhost:6379 | localhost:6380 | 6381 (내부) |
| Prometheus | - | - | localhost:9090 |
| Grafana | - | - | localhost:3003 |

---

**문서 버전**: 1.0
**최종 수정일**: 2026-03-18
**작성자**: DevOps Team
**관련 문서**: [RUNBOOK.md](./RUNBOOK.md), [OPERATION.md](./OPERATION.md)
