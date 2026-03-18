# CookShare Getting Started Guide

레시피 공유 플랫폼 **CookShare**를 로컬 환경에서 실행하기 위한 단계별 안내서입니다.

---

## 목차

1. [시스템 요구사항](#1-시스템-요구사항)
2. [설치 과정](#2-설치-과정)
3. [환경 설정](#3-환경-설정)
4. [첫 실행](#4-첫-실행)
5. [기본 사용 예제](#5-기본-사용-예제)
6. [자주 발생하는 문제와 해결 방법](#6-자주-발생하는-문제와-해결-방법)

---

## 1. 시스템 요구사항

### 필수 요소

| 소프트웨어 | 최소 버전 | 권장 버전 | 확인 방법 |
|---|---|---|---|
| Node.js | 20.x | 22.x LTS | `node -v` |
| pnpm | 8.15.0 | 8.15.x | `pnpm -v` |
| Docker | 24.x | 최신 | `docker -v` |
| Docker Compose | 2.x | 최신 | `docker compose version` |
| Git | 2.x | 최신 | `git --version` |

> **참고**: 이 프로젝트는 pnpm 8.15.0을 패키지 매니저로 고정(`packageManager` 필드)하고 있어 npm 또는 yarn 사용 시 오류가 발생합니다.

### 운영체제

- macOS 13 (Ventura) 이상
- Ubuntu 22.04 이상
- Windows 11 + WSL2 (Windows는 반드시 WSL2 환경에서 실행)

### 하드웨어

- RAM: 8GB 이상 (Docker 컨테이너 포함 권장)
- 디스크: 5GB 이상 여유 공간

---

## 2. 설치 과정

### 2-1. Node.js 설치

Node.js 버전 관리 도구인 `nvm`을 사용하는 것을 권장합니다.

```bash
# nvm 설치
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# 터미널 재시작 후 Node.js 22 설치
nvm install 22
nvm use 22
node -v  # v22.x.x 확인
```

### 2-2. pnpm 설치

```bash
# corepack을 통한 설치 (권장)
corepack enable
corepack prepare pnpm@8.15.0 --activate

# 또는 npm을 통한 설치
npm install -g pnpm@8.15.0

pnpm -v  # 8.15.0 확인
```

### 2-3. Docker Desktop 설치

[Docker 공식 사이트](https://docs.docker.com/get-docker/)에서 운영체제에 맞는 버전을 설치한 후 실행합니다.

```bash
docker -v           # Docker version 확인
docker compose version  # Docker Compose version 확인
```

### 2-4. 저장소 클론

```bash
git clone <repository-url>
cd cookshare
```

### 2-5. 의존성 설치

```bash
# 루트에서 실행 — pnpm workspace가 모든 패키지를 한 번에 설치
pnpm install
```

설치 후 생성되는 구조:

```
cookshare/
├── apps/
│   └── web/          # Next.js 15 프론트엔드 (@cookshare/web)
├── packages/
│   ├── shared/       # 공통 유틸리티 (@cookshare/shared)
│   ├── types/        # TypeScript 타입 정의 (@cookshare/types)
│   └── ui/           # UI 컴포넌트 라이브러리 (@cookshare/ui)
└── node_modules/
```

---

## 3. 환경 설정

### 3-1. 환경 변수 파일 생성

프로젝트 루트에 `.env.local` 파일을 생성합니다.

```bash
cp .env.development .env.local   # 템플릿이 있는 경우
# 또는 직접 생성
touch .env.local
```

`.env.local` 최소 설정:

```env
# API 서버 주소 (백엔드가 없을 경우 기본값 유지)
NEXT_PUBLIC_API_URL=http://localhost:3001/api

# 개발 환경 (변경 불필요)
NODE_ENV=development

# 데이터베이스 (Docker 사용 시 자동 설정됨)
DATABASE_URL=postgresql://cookshare:cookshare_dev_password@localhost:5432/cookshare_dev

# Redis (Docker 사용 시 자동 설정됨)
REDIS_URL=redis://localhost:6379
```

> **주의**: `NEXT_PUBLIC_` 접두사가 붙은 변수만 브라우저에 노출됩니다. 민감한 정보에는 이 접두사를 사용하지 마세요.

### 3-2. Docker 서비스 확인

개발 환경은 다음 서비스를 Docker로 실행합니다:

| 서비스 | 포트 | 용도 |
|---|---|---|
| Next.js Web | 3000 | 프론트엔드 앱 |
| PostgreSQL 16 | 5432 | 메인 데이터베이스 |
| Redis 7 | 6379 | 캐시 |
| pgAdmin 4 | 5050 | DB 관리 UI |
| RedisInsight | 8001 | Redis 관리 UI |

---

## 4. 첫 실행

### 방법 A: Docker로 전체 스택 실행 (권장)

```bash
# 개발 환경 시작 (PostgreSQL, Redis, Next.js 모두 포함)
pnpm docker:dev

# 로그 확인
pnpm docker:logs

# 중지
pnpm docker:stop
```

`pnpm docker:dev`는 내부적으로 `scripts/dev.sh start`를 실행하며:
1. Docker 실행 여부 확인
2. `.env.local` 자동 생성 (없는 경우)
3. `docker-compose.dev.yml` 기반으로 모든 서비스 시작
4. 서비스 접속 주소 출력

실행 완료 후 접속 주소:
```
Web App  → http://localhost:3000
pgAdmin  → http://localhost:5050  (admin@cookshare.dev / admin)
Redis UI → http://localhost:8001
```

### 방법 B: 로컬에서 Next.js만 실행

Docker 없이 프론트엔드만 빠르게 확인하려는 경우:

```bash
# Turbopack 기반 개발 서버 시작
pnpm dev
```

브라우저에서 `http://localhost:3000` 접속

> **참고**: 이 방법은 백엔드(PostgreSQL, Redis) 없이 실행되므로 API 호출이 필요한 기능은 동작하지 않습니다.

### 방법 C: 프로덕션 빌드 테스트

```bash
# 전체 빌드 (packages → web 순서로 빌드)
pnpm build

# 프로덕션 서버 시작
pnpm start
```

---

## 5. 기본 사용 예제

### 개발 워크플로우

```bash
# 1. 의존성 설치
pnpm install

# 2. 개발 서버 시작
pnpm dev                    # 로컬 Next.js만
# 또는
pnpm docker:dev             # 전체 Docker 스택

# 3. 코드 품질 검사
pnpm lint                   # ESLint 검사
pnpm lint:fix               # 자동 수정
pnpm format                 # Prettier 포맷팅

# 4. 타입 체크
pnpm type-check

# 5. 테스트 실행
pnpm test                   # 전체 단위 테스트
pnpm test:watch             # 변경 감지 모드
pnpm test:coverage          # 커버리지 리포트
pnpm test:e2e               # Playwright E2E 테스트
```

### 특정 패키지만 작업

```bash
# UI 패키지 테스트만 실행
pnpm test:ui

# Web 앱 테스트만 실행
pnpm test:web

# E2E 테스트 UI 모드로 실행
pnpm test:e2e:ui
```

### 데이터베이스 관리

```bash
# 시드 데이터 투입 (개발용 초기 데이터)
pnpm docker:seed

# 데이터베이스 초기화
pnpm docker:reset

# Docker 리소스 전체 정리
pnpm docker:clean
```

### 컴포넌트 임포트 패턴

이 프로젝트는 모노레포 구조로 내부 패키지를 workspace로 참조합니다:

```typescript
// UI 컴포넌트 사용
import { Button } from '@cookshare/ui';

// 공통 타입 사용
import type { User, Recipe } from '@cookshare/types';

// 공유 유틸리티 사용
import { formatDate } from '@cookshare/shared';

// Next.js 앱 내부 경로 별칭
import { cn } from '@/lib/utils';
import { config } from '@/lib/config';
```

---

## 6. 자주 발생하는 문제와 해결 방법

### 문제 1: pnpm 버전 불일치

**증상**
```
ERROR: This project requires pnpm 8.15.0
```

**해결**
```bash
# 정확한 버전으로 설치
npm install -g pnpm@8.15.0

# 또는 corepack 사용
corepack prepare pnpm@8.15.0 --activate
```

---

### 문제 2: Docker가 시작되지 않음

**증상**
```
[ERROR] Docker is not running. Please start Docker and try again.
```

**해결**
```bash
# Docker Desktop 실행 확인
docker info

# Linux의 경우 Docker 데몬 재시작
sudo systemctl restart docker
sudo systemctl enable docker
```

---

### 문제 3: 포트 충돌

**증상**
```
Error: bind: address already in use 0.0.0.0:3000
```

**해결**
```bash
# 사용 중인 프로세스 확인
lsof -i :3000
lsof -i :5432
lsof -i :6379

# 프로세스 종료
kill -9 <PID>

# 또는 Docker 컨테이너 전체 정리 후 재시작
pnpm docker:clean
pnpm docker:dev
```

---

### 문제 4: workspace 패키지 참조 오류

**증상**
```
Module not found: Can't resolve '@cookshare/ui'
```

**해결**
```bash
# node_modules 및 빌드 캐시 전체 초기화
pnpm clean

# 의존성 재설치
pnpm install

# 패키지 선빌드 (web 이전에 packages 빌드 필요)
pnpm --filter=@cookshare/types build
pnpm --filter=@cookshare/shared build
pnpm --filter=@cookshare/ui build
```

---

### 문제 5: TypeScript 컴파일 오류

**증상**
```
Type error: Property 'x' does not exist on type 'Y'
```

**해결**
```bash
# 타입 체크 실행으로 전체 오류 확인
pnpm type-check

# .next 캐시 초기화 후 재빌드
pnpm --filter=@cookshare/web clean
pnpm build
```

---

### 문제 6: PostgreSQL 연결 실패

**증상**
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```

**해결**
```bash
# 컨테이너 상태 확인
docker ps | grep postgres

# 헬스체크 로그 확인
docker logs cookshare-postgres-dev

# 재시작
pnpm docker:restart
```

> 개발 DB 기본 접속 정보:
> Host: `localhost:5432` | DB: `cookshare_dev` | User: `cookshare` | Password: `cookshare_dev_password`

---

### 문제 7: Husky pre-commit hook 실패

**증상**
```
lint-staged: ESLint error in staged files
```

**해결**
```bash
# ESLint 오류 자동 수정
pnpm lint:fix

# Prettier 포맷 적용
pnpm format

# 수정 후 다시 스테이징하여 커밋
git add .
git commit -m "fix: resolve lint errors"
```

커밋 메시지는 Conventional Commits 형식을 따라야 합니다:
```
feat: 새 기능 추가
fix: 버그 수정
docs: 문서 수정
chore: 빌드/설정 변경
refactor: 리팩토링
test: 테스트 추가
```

---

### 문제 8: Windows WSL2 파일 감시 오작동

**증상**: 코드를 수정해도 개발 서버가 자동으로 리로드되지 않음

**해결**

Docker Compose 개발 설정에 이미 폴링 모드가 활성화되어 있습니다:

```yaml
# docker-compose.dev.yml (기존 설정)
environment:
  - CHOKIDAR_USEPOLLING=true
  - WATCHPACK_POLLING=true
```

로컬 실행 시에는 `.env.local`에 추가:
```env
CHOKIDAR_USEPOLLING=true
WATCHPACK_POLLING=true
```

---

## 빠른 참조

```bash
# 전체 개발 환경 시작
pnpm docker:dev

# 로컬 개발 서버만
pnpm dev

# 테스트
pnpm test

# 빌드
pnpm build

# 정리 및 재설치
pnpm clean && pnpm install
```

---

*문의 및 기여는 프로젝트 이슈 트래커를 이용해 주세요.*
