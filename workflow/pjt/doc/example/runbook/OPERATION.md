# 배포 운영 가이드 (Deployment Operations Guide)

## 목차
- [개요](#개요)
- [환경 구성](#환경-구성)
- [사전 준비사항](#사전-준비사항)
- [배포 절차](#배포-절차)
- [환경별 배포 가이드](#환경별-배포-가이드)
- [롤백 절차](#롤백-절차)
- [모니터링 및 건강성 검사](#모니터링-및-건강성-검사)
- [트러블슈팅](#트러블슈팅)
- [보안 및 백업](#보안-및-백업)

## 개요

이 문서는 Node.js 애플리케이션의 완전한 배포 및 운영 가이드를 제공합니다. 개발, 스테이징, 프로덕션 환경에서의 배포 절차, 환경 변수 설정, 사전 체크리스트, 롤백 방법을 포함합니다.

### 지원 환경
- **Development**: 로컬 개발 환경
- **Staging**: 테스트 및 검증 환경  
- **Production**: 실제 서비스 환경

## 환경 구성

### 디렉토리 구조
```
runbook/
├── deployment/
│   ├── config/
│   │   ├── .env.development
│   │   ├── .env.staging
│   │   └── .env.production
│   ├── docker/
│   │   ├── Dockerfile.dev
│   │   ├── Dockerfile.prod
│   │   └── docker-compose.yml
│   ├── scripts/
│   │   ├── deploy.sh
│   │   ├── rollback.sh
│   │   ├── health-check.sh
│   │   └── smoke-test.sh
│   └── logs/
├── package.json
└── OPERATION.md (이 문서)
```

### 필수 도구
- Node.js (≥18.0.0)
- npm (≥8.0.0)
- Docker & Docker Compose
- kubectl (프로덕션 환경)
- curl
- git

## 사전 준비사항

### 1. 환경 변수 설정

각 환경별 `.env` 파일을 검토하고 필요한 값들을 설정하세요:

#### 🔴 프로덕션 환경 필수 변경 항목
```bash
# deployment/config/.env.production
DATABASE_URL=postgres://user:CHANGE_THIS_PASSWORD@host:5432/db
JWT_SECRET=CHANGE_THIS_TO_COMPLEX_SECRET_MINIMUM_64_CHARACTERS_LONG
REDIS_PASSWORD=CHANGE_THIS_PASSWORD
EMAIL_API_KEY=CHANGE_THIS_SENDGRID_API_KEY
AWS_ACCESS_KEY_ID=CHANGE_THIS_AWS_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=CHANGE_THIS_AWS_SECRET_KEY
```

#### 개발 환경
```bash
# deployment/config/.env.development
NODE_ENV=development
PORT=3000
DATABASE_URL=postgres://runbook:dev_password@localhost:5432/runbook_dev
REDIS_URL=redis://localhost:6379
```

#### 스테이징 환경
```bash
# deployment/config/.env.staging
NODE_ENV=staging
PORT=3000
DATABASE_URL=postgres://runbook:staging_password@db-staging:5432/runbook_staging
REDIS_URL=redis://redis-staging:6379
```

### 2. 인프라 설정 확인

#### 데이터베이스 설정
```bash
# PostgreSQL 연결 확인
psql -h localhost -U runbook -d runbook_dev -c "\l"

# Redis 연결 확인
redis-cli ping
```

#### Docker 환경 확인
```bash
docker --version
docker-compose --version
```

### 3. 보안 설정

#### SSL 인증서 (프로덕션)
```bash
# SSL 인증서 위치 확인
ls -la /etc/ssl/certs/production.crt
ls -la /etc/ssl/private/production.key
```

#### 방화벽 설정
```bash
# 필요한 포트 오픈 확인
sudo ufw status
# 3000 (앱), 5432 (PostgreSQL), 6379 (Redis), 443 (HTTPS)
```

## 배포 절차

### 사전 체크리스트

#### ✅ 배포 전 필수 확인사항

**코드 품질**
- [ ] 모든 테스트 통과 (`npm test`)
- [ ] 린트 검사 통과 (`npm run lint`)
- [ ] 보안 감사 통과 (`npm audit`)
- [ ] 코드 리뷰 완료

**환경 설정**
- [ ] 환경 변수 파일 검증
- [ ] 데이터베이스 연결 확인
- [ ] Redis 연결 확인
- [ ] 외부 서비스 연결 확인

**인프라**
- [ ] 서버 리소스 확인 (CPU, 메모리, 디스크)
- [ ] SSL 인증서 유효성 확인 (프로덕션)
- [ ] 백업 시스템 동작 확인
- [ ] 모니터링 시스템 확인

**팀 커뮤니케이션**
- [ ] 배포 일정 팀 공지
- [ ] 롤백 계획 수립
- [ ] 긴급 연락망 확인

### 기본 배포 명령어

```bash
# 개발 환경 배포
npm run deploy:dev

# 스테이징 환경 배포
npm run deploy:staging

# 프로덕션 환경 배포
npm run deploy:prod
```

## 환경별 배포 가이드

### 🟢 개발 환경 (Development)

**특징:**
- 로컬 개발 환경
- 핫 리로드 지원
- 디버깅 모드 활성화

**배포 단계:**
```bash
# 1. 의존성 설치 및 빌드
npm ci
npm run build

# 2. 개발 서버 시작/재시작
npm run deploy:dev

# 3. 건강성 검사
npm run health-check
```

**Docker를 사용한 개발 환경:**
```bash
# Docker 개발 환경 실행
docker-compose up app-dev db-dev redis-dev

# 또는 단일 명령으로
npm run docker:run:dev
```

### 🟡 스테이징 환경 (Staging)

**특징:**
- 프로덕션 환경 시뮬레이션
- Docker 컨테이너 배포
- 통합 테스트 수행

**배포 단계:**
```bash
# 1. 사전 검증
npm run pre-deploy

# 2. Docker 이미지 빌드
npm run docker:build:prod

# 3. 스테이징 배포
npm run deploy:staging

# 4. 스모크 테스트 실행
npm run smoke-test

# 5. 통합 테스트
npm run test:integration
```

**수동 Docker 배포:**
```bash
# 이미지 빌드
docker build -f deployment/docker/Dockerfile.prod -t runbook-api:staging .

# 기존 컨테이너 중지 및 제거
docker stop runbook-staging || true
docker rm runbook-staging || true

# 새 컨테이너 실행
docker run -d --name runbook-staging \
  -p 3001:3000 \
  --env-file deployment/config/.env.staging \
  runbook-api:staging
```

### 🔴 프로덕션 환경 (Production)

**특징:**
- Kubernetes 오케스트레이션
- 고가용성 구성
- 자동 스케일링
- 무중단 배포

**배포 단계:**
```bash
# 1. 사전 검증 (필수)
npm run pre-deploy

# 2. 데이터베이스 백업
npm run backup:db

# 3. 프로덕션 배포
npm run deploy:prod

# 4. 건강성 검사
npm run health-check

# 5. 스모크 테스트
npm run smoke-test

# 6. 모니터링 확인
npm run monitoring:setup
```

**Kubernetes 수동 배포:**
```bash
# 현재 배포 상태 확인
kubectl get deployments -n production

# 새 배포 적용
kubectl apply -f deployment/k8s/prod/

# 배포 상태 모니터링
kubectl rollout status deployment/runbook-api -n production --timeout=300s

# 파드 상태 확인
kubectl get pods -n production -l app=runbook-api
```

## 롤백 절차

### 🚨 긴급 롤백 시나리오

**언제 롤백해야 하는가:**
- 치명적인 버그 발견
- 성능 심각한 저하
- 보안 취약점 발견
- 데이터 손실 위험
- 서비스 중단

### 환경별 롤백 방법

#### 개발 환경 롤백
```bash
# Git 기반 롤백
npm run rollback:dev

# 특정 버전으로 롤백
./deployment/scripts/rollback.sh development v1.2.3

# 수동 Git 롤백
git checkout v1.2.3
npm ci
pm2 reload ecosystem.config.js --env development
```

#### 스테이징 환경 롤백
```bash
# Docker 이미지 기반 롤백
npm run rollback:staging

# 특정 이미지 태그로 롤백
./deployment/scripts/rollback.sh staging v1.2.3

# 수동 Docker 롤백
docker stop runbook-staging
docker rm runbook-staging
docker run -d --name runbook-staging \
  -p 3001:3000 \
  --env-file deployment/config/.env.staging \
  runbook-api:v1.2.3
```

#### 🚨 프로덕션 환경 롤백
```bash
# Kubernetes 롤백
npm run rollback:prod

# 특정 리비전으로 롤백
./deployment/scripts/rollback.sh production 3

# 수동 Kubernetes 롤백
kubectl rollout undo deployment/runbook-api -n production
kubectl rollout status deployment/runbook-api -n production

# 데이터베이스 롤백 (주의!)
./deployment/scripts/rollback.sh production 3 --with-db
```

### 롤백 후 검증

```bash
# 1. 건강성 검사
./deployment/scripts/health-check.sh production

# 2. 스모크 테스트
./deployment/scripts/smoke-test.sh production

# 3. 로그 확인
./deployment/scripts/tail-logs.sh production

# 4. 메트릭 모니터링
curl -s https://api.runbook.com/api/v1/metrics | jq .
```

## 모니터링 및 건강성 검사

### 건강성 검사 엔드포인트

#### 기본 엔드포인트
```bash
# 기본 건강성 검사
curl https://api.runbook.com/health

# 상세 상태 정보
curl https://api.runbook.com/api/v1/status

# 메트릭 정보
curl https://api.runbook.com/api/v1/metrics
```

#### 검사 항목
- **애플리케이션 상태**: HTTP 200 응답
- **데이터베이스 연결**: PostgreSQL 연결 상태
- **캐시 연결**: Redis 연결 상태
- **메모리 사용량**: < 85%
- **CPU 사용량**: < 80%
- **디스크 사용량**: < 90%

### 자동화된 건강성 검사

```bash
# 모든 환경 건강성 검사
for env in development staging production; do
  echo "Checking $env..."
  ./deployment/scripts/health-check.sh $env
done

# 지속적 모니터링 (10분 간격)
while true; do
  ./deployment/scripts/health-check.sh production
  sleep 600
done
```

### 모니터링 도구 설정

#### Prometheus 메트릭
```yaml
# deployment/config/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'runbook-api'
    static_configs:
      - targets: ['app:3000']
```

#### Grafana 대시보드
- **시스템 메트릭**: CPU, 메모리, 디스크
- **애플리케이션 메트릭**: 응답 시간, 에러율, 처리량
- **비즈니스 메트릭**: 활성 사용자, API 호출 수

## 트러블슈팅

### 일반적인 문제 및 해결책

#### 1. 배포 실패
```bash
# 로그 확인
tail -f deployment/logs/deploy_production_$(date +%Y%m%d).log

# 권한 문제
chmod +x deployment/scripts/*.sh

# 의존성 문제
rm -rf node_modules package-lock.json
npm install
```

#### 2. 데이터베이스 연결 실패
```bash
# 연결 테스트
pg_isready -h db-host -p 5432

# 연결 풀 초기화
kubectl delete pods -n production -l app=runbook-api

# 연결 문자열 확인
echo $DATABASE_URL
```

#### 3. Redis 연결 실패
```bash
# Redis 상태 확인
redis-cli -h redis-host ping

# Redis 메모리 확인
redis-cli info memory

# 연결 재시작
kubectl restart deployment/redis -n production
```

#### 4. SSL/TLS 문제
```bash
# 인증서 확인
openssl x509 -in /etc/ssl/certs/production.crt -text -noout

# 인증서 만료일 확인
openssl x509 -in /etc/ssl/certs/production.crt -noout -dates

# SSL 연결 테스트
openssl s_client -connect api.runbook.com:443
```

#### 5. 메모리/CPU 과부하
```bash
# 리소스 사용량 확인
kubectl top pods -n production

# 수평적 스케일링
kubectl scale deployment runbook-api --replicas=5 -n production

# 수직적 스케일링
kubectl patch deployment runbook-api -n production -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"app","resources":{"limits":{"memory":"2Gi","cpu":"1000m"}}}]}}}}'
```

### 긴급 대응 절차

#### 🚨 서비스 중단 시
1. **즉시 상황 파악**
   ```bash
   kubectl get pods -n production
   kubectl logs -f deployment/runbook-api -n production
   ```

2. **긴급 복구 시도**
   ```bash
   kubectl rollout restart deployment/runbook-api -n production
   ```

3. **롤백 실행** (복구 불가능 시)
   ```bash
   ./deployment/scripts/rollback.sh production
   ```

4. **팀 알림**
   ```bash
   # Slack 알림
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"🚨 Production service outage - Rolling back"}' \
     $SLACK_WEBHOOK_URL
   ```

## 보안 및 백업

### 보안 모범 사례

#### 1. 환경 변수 보안
```bash
# 프로덕션 환경 변수 암호화
gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
    --s2k-digest-algo SHA512 --s2k-count 65536 --symmetric \
    deployment/config/.env.production

# 환경 변수 권한 설정
chmod 600 deployment/config/.env.*
```

#### 2. 컨테이너 보안
```bash
# 취약점 스캔
docker scan runbook-api:latest

# 비root 사용자 실행 확인
docker inspect runbook-api:latest | jq '.[0].Config.User'
```

#### 3. 네트워크 보안
```bash
# 방화벽 규칙 확인
sudo ufw status numbered

# SSL/TLS 설정 검증
testssl.sh https://api.runbook.com
```

### 백업 및 복구

#### 데이터베이스 백업
```bash
# 자동 백업 실행
npm run backup:db

# 수동 백업
pg_dump -h db-host -U username -d database_name > backup_$(date +%Y%m%d_%H%M%S).sql

# S3에 백업 업로드
aws s3 cp backup.sql s3://runbook-prod-backups/$(date +%Y%m%d)/
```

#### 백업 복구
```bash
# 데이터베이스 복구
./deployment/scripts/restore-db.sh backup_20231201_143000.sql

# 복구 검증
psql -h db-host -U username -d database_name -c "SELECT COUNT(*) FROM users;"
```

#### 정기 백업 설정
```bash
# crontab 설정
echo "0 2 * * * /path/to/deployment/scripts/backup-db.sh" | crontab -

# 백업 보존 정책 (30일)
find ./backups -name "*.sql" -mtime +30 -delete
```

### 재해 복구 계획

#### RTO/RPO 목표
- **RTO (Recovery Time Objective)**: 4시간
- **RPO (Recovery Point Objective)**: 1시간

#### 복구 시나리오
1. **부분 장애**: 자동 재시작 + 로드밸런서 재라우팅
2. **전체 장애**: 백업 데이터센터 활성화
3. **데이터 손실**: 최신 백업으로 복구

## 성능 최적화

### 모니터링 메트릭
```bash
# 응답 시간 측정
curl -w "@curl-format.txt" -s -o /dev/null https://api.runbook.com/api/v1/ping

# 처리량 테스트
ab -n 1000 -c 10 https://api.runbook.com/api/v1/ping
```

### 최적화 기법
- **CDN 활용**: 정적 자산 캐싱
- **데이터베이스 인덱싱**: 쿼리 성능 향상
- **Redis 캐싱**: 자주 사용되는 데이터 캐싱
- **가로 스케일링**: 트래픽 증가 시 인스턴스 추가

## 운영 자동화

### CI/CD 파이프라인
```yaml
# .github/workflows/deploy.yml
name: Deploy to Production
on:
  push:
    tags:
      - 'v*'
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm ci
      - run: npm run test
      - run: ./deployment/scripts/deploy.sh production
```

### 정기 작업 스케줄링
```bash
# 건강성 검사 (5분마다)
*/5 * * * * /path/to/deployment/scripts/health-check.sh production

# 로그 로테이션 (매일 자정)
0 0 * * * /usr/sbin/logrotate /etc/logrotate.d/runbook-api

# 백업 정리 (주간)
0 3 * * 0 find /backups -mtime +30 -delete
```

## 문서 유지보수

이 문서는 다음 상황에서 업데이트되어야 합니다:
- 새로운 환경 추가
- 배포 절차 변경
- 새로운 보안 요구사항
- 인프라 변경
- 도구 버전 업그레이드

---

**마지막 업데이트**: 2024-01-01  
**문서 버전**: 1.0  
**담당자**: DevOps 팀  
**리뷰 주기**: 월 1회