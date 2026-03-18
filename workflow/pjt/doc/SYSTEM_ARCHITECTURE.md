# CookShare 시스템 아키텍처 문서

> **버전**: 1.0.0 | **작성일**: 2026-03-18 | **모델**: C4 (Context → Container → Component → Code)

---

## 목차

1. [시스템 개요](#1-시스템-개요)
2. [C4 Level 1: System Context](#2-c4-level-1-system-context)
3. [C4 Level 2: Container Diagram](#3-c4-level-2-container-diagram)
4. [C4 Level 3: Component Diagram](#4-c4-level-3-component-diagram)
5. [C4 Level 4: Code Diagram](#5-c4-level-4-code-diagram)
6. [기술 스택](#6-기술-스택)
7. [통신 방식](#7-통신-방식)
8. [데이터 플로우](#8-데이터-플로우)
9. [보안 아키텍처](#9-보안-아키텍처)
10. [성능 전략](#10-성능-전략)
11. [배포 아키텍처](#11-배포-아키텍처)
12. [모니터링 & 운영](#12-모니터링--운영)
13. [확장성 설계](#13-확장성-설계)

---

## 1. 시스템 개요

**CookShare**는 사용자가 레시피를 작성·공유·탐색할 수 있는 커뮤니티 기반 레시피 공유 플랫폼입니다.

### 핵심 기능 (MVP)

| 분류 | 기능 |
|------|------|
| 인증 | 회원가입, 로그인, 로그아웃, JWT 토큰 관리 |
| 레시피 | 작성, 조회, 수정, 삭제, 이미지 업로드 |
| 탐색 | 검색, 카테고리 필터, 페이지네이션 |
| 소셜 | 좋아요, 조회수, 프로필 조회 |

### 아키텍처 원칙

- **레이어드 아키텍처**: Presentation → Business → Data Access → Infrastructure
- **단일 책임 원칙**: 각 모듈은 하나의 책임만 담당
- **의존성 역전**: 고수준 모듈이 저수준 모듈에 의존하지 않음
- **확장 가능한 모노리스**: MVP는 모노리스로 시작, 마이크로서비스로 전환 가능한 구조

---

## 2. C4 Level 1: System Context

> 시스템이 **누구**와 **어떤 외부 시스템**과 상호작용하는지 보여줍니다.

```mermaid
graph TB
    subgraph "사용자"
        User["👤 일반 사용자
        ─────────────────
        레시피를 등록·검색하고
        좋아요를 남기는 사람"]
        Admin["👨‍💼 관리자
        ─────────────────
        콘텐츠 관리와 사용자
        계정을 운영하는 사람"]
    end

    subgraph "CookShare [Software System]"
        CookShare["🍳 CookShare
        ─────────────────
        레시피 공유 및
        커뮤니티 플랫폼"]
    end

    subgraph "외부 시스템"
        Email["📧 이메일 서비스
        SendGrid / AWS SES
        ─────────────────
        회원가입 인증 메일
        알림 발송"]
        Storage["📁 파일 저장소
        AWS S3 / Cloudinary
        ─────────────────
        레시피 이미지 및
        프로필 사진 저장"]
        Analytics["📊 분석 서비스
        Google Analytics
        ─────────────────
        사용자 행동 데이터
        수집 및 분석"]
    end

    User        -->|"레시피 CRUD, 검색,
                    좋아요 (HTTPS)"| CookShare
    Admin       -->|"사용자 관리,
                    콘텐츠 관리 (HTTPS)"| CookShare
    CookShare   -->|"인증 메일 발송
                    (SMTP / HTTP API)"| Email
    CookShare   -->|"이미지 업로드 / 조회
                    (HTTP API)"| Storage
    CookShare   -->|"이벤트 전송
                    (HTTP API)"| Analytics

    style CookShare fill:#FF6B6B,color:#fff
    style User fill:#4ECDC4,color:#fff
    style Admin fill:#45B7D1,color:#fff
    style Email fill:#96CEB4
    style Storage fill:#FFEAA7
    style Analytics fill:#DDA0DD
```

### 사용자 역할 정의

| 역할 | 권한 | 설명 |
|------|------|------|
| `user` | 레시피 CRUD (본인), 검색, 좋아요 | 기본 가입 사용자 |
| `admin` | 전체 사용자 관리, 모든 레시피 관리 | 시스템 운영자 |

---

## 3. C4 Level 2: Container Diagram

> 시스템 내부를 **컨테이너(독립 실행 단위)** 로 분해하여 기술 선택과 통신 방식을 보여줍니다.

```mermaid
graph TB
    subgraph "외부"
        User["👤 사용자 / 관리자
        웹 브라우저"]
        Email["📧 SendGrid"]
        Storage["📁 AWS S3"]
    end

    subgraph "CookShare System"
        subgraph "Frontend [Vercel]"
            WebApp["🌐 Web Application
            ─────────────────────
            Next.js 15 + React 19
            TypeScript + Tailwind CSS
            ─────────────────────
            SSR/CSR 하이브리드 렌더링
            사용자 인터페이스 제공
            포트: 3000"]
        end

        subgraph "Backend [Railway / AWS ECS]"
            API["⚙️ API Application
            ─────────────────────
            Node.js 18 + Express.js
            TypeScript + Zod
            ─────────────────────
            RESTful API 제공
            비즈니스 로직 처리
            포트: 8080"]
        end

        subgraph "Data Layer [Managed Services]"
            DB["🗄️ PostgreSQL 15
            ─────────────────────
            사용자·레시피·좋아요
            카테고리 데이터
            포트: 5432"]
            Cache["⚡ Redis 7
            ─────────────────────
            세션, 검색 결과 캐시
            Rate Limit 카운터
            포트: 6379"]
        end
    end

    User    -->|"HTTPS (443)"| WebApp
    WebApp  -->|"REST API / JSON
                HTTPS (443)"| API
    API     -->|"SQL / TCP (5432)"| DB
    API     -->|"Key-Value / TCP (6379)"| Cache
    API     -->|"SMTP / HTTP API"| Email
    API     -->|"HTTP API (Presigned URL)"| Storage

    style WebApp fill:#61DAFB,color:#000
    style API    fill:#68A063,color:#fff
    style DB     fill:#336791,color:#fff
    style Cache  fill:#DC382D,color:#fff
```

### 컨테이너별 책임 요약

| 컨테이너 | 기술 | 주요 책임 |
|----------|------|-----------|
| Web Application | Next.js 15, React 19, TypeScript | UI 렌더링, 사용자 입력 처리, API 통신 |
| API Application | Node.js, Express.js, Prisma | 비즈니스 로직, 인증/인가, DB 접근 |
| PostgreSQL | PostgreSQL 15 | 영구 데이터 저장, 트랜잭션 보장 |
| Redis | Redis 7 | 캐싱, 세션 관리, Rate Limiting |

---

## 4. C4 Level 3: Component Diagram

### 4-1. Frontend (Next.js) 컴포넌트

```mermaid
graph TB
    subgraph "Next.js App Router"
        subgraph "Pages (Server Components)"
            HomePage["🏠 HomePage
            레시피 피드 + 검색"]
            RecipePage["🍽️ RecipeDetailPage
            레시피 상세 보기"]
            ProfilePage["👤 ProfilePage
            사용자 프로필"]
            AuthPage["🔑 AuthPage
            로그인 / 회원가입"]
        end

        subgraph "Client Components"
            RecipeForm["📝 RecipeForm
            레시피 작성/수정 폼"]
            SearchBar["🔍 SearchBar
            실시간 검색"]
            LikeButton["❤️ LikeButton
            좋아요 토글"]
            ImageUpload["📷 ImageUpload
            Drag & Drop 업로드"]
        end

        subgraph "Shared UI (shadcn/ui + Radix)"
            Button["Button"]
            Card["Card"]
            Input["Input"]
            Modal["Modal / Dialog"]
        end

        subgraph "Data Fetching"
            APIClient["🔌 API Client
            fetch + 에러 핸들링"]
            AuthStore["🔐 Auth Store
            토큰 관리 (메모리)"]
        end
    end

    HomePage    --> APIClient
    RecipeForm  --> APIClient
    LikeButton  --> APIClient
    ImageUpload --> APIClient
    APIClient   --> AuthStore

    style HomePage   fill:#61DAFB,color:#000
    style RecipePage fill:#61DAFB,color:#000
    style APIClient  fill:#FF6B6B,color:#fff
    style AuthStore  fill:#FFEAA7,color:#000
```

### 4-2. Backend (Express.js) 컴포넌트

```mermaid
graph TB
    subgraph "API Application"
        subgraph "Middleware Layer"
            Router["🛣️ Express Router
            URL 라우팅"]
            AuthMiddleware["🔐 Auth Middleware
            JWT 검증 및 사용자 추출"]
            RateLimit["⏱️ Rate Limiter
            100 req / 15분"]
            ErrorHandler["❌ Global Error Handler
            에러 응답 표준화"]
            RequestValidator["✅ Request Validator
            Zod 스키마 검증"]
        end

        subgraph "Controller Layer"
            AuthController["🔑 AuthController
            POST /auth/register
            POST /auth/login
            POST /auth/refresh
            POST /auth/logout"]
            UserController["👤 UserController
            GET  /users/:id
            PUT  /users/:id
            DELETE /users/:id"]
            RecipeController["🍳 RecipeController
            GET    /recipes
            POST   /recipes
            GET    /recipes/:id
            PUT    /recipes/:id
            DELETE /recipes/:id
            POST   /recipes/:id/like"]
            FileController["📁 FileController
            POST /files/upload
            반환: Presigned URL"]
        end

        subgraph "Service Layer"
            AuthService["🔑 AuthService
            인증 비즈니스 로직
            토큰 생성/검증"]
            UserService["👤 UserService
            사용자 비즈니스 로직
            이메일 발송 연동"]
            RecipeService["🍳 RecipeService
            레시피 비즈니스 로직
            검색/필터 처리"]
            FileService["📁 FileService
            이미지 처리 (Sharp)
            S3 업로드"]
            CacheService["⚡ CacheService
            Redis 캐시 추상화"]
        end

        subgraph "Repository Layer (Prisma ORM)"
            UserRepo["UserRepository
            Prisma.user.*"]
            RecipeRepo["RecipeRepository
            Prisma.recipe.*"]
            LikeRepo["LikeRepository
            Prisma.like.*"]
        end
    end

    subgraph "Infrastructure"
        DB["PostgreSQL"]
        Redis["Redis"]
        S3["AWS S3"]
    end

    Router --> AuthMiddleware --> RateLimit --> RequestValidator
    RequestValidator --> AuthController & UserController & RecipeController & FileController
    Router --> ErrorHandler

    AuthController  --> AuthService
    UserController  --> UserService
    RecipeController --> RecipeService
    FileController  --> FileService

    AuthService     --> UserRepo
    AuthService     --> CacheService
    UserService     --> UserRepo
    RecipeService   --> RecipeRepo
    RecipeService   --> LikeRepo
    RecipeService   --> CacheService
    FileService     --> S3

    UserRepo        --> DB
    RecipeRepo      --> DB
    LikeRepo        --> DB
    CacheService    --> Redis

    style AuthController  fill:#87CEEB
    style UserController  fill:#87CEEB
    style RecipeController fill:#87CEEB
    style FileController  fill:#87CEEB
    style AuthService     fill:#98FB98
    style UserService     fill:#98FB98
    style RecipeService   fill:#98FB98
    style FileService     fill:#98FB98
    style CacheService    fill:#98FB98
```

---

## 5. C4 Level 4: Code Diagram

> 핵심 모듈의 **클래스 구조와 인터페이스**를 보여줍니다.

### 5-1. 도메인 모델 (TypeScript Interfaces)

```typescript
// ── User 도메인 ──────────────────────────────────────────────
interface User {
  id: string;          // UUID v4
  email: string;       // 고유값, 소문자 정규화
  name: string;        // 2~100자
  role: 'user' | 'admin';
  createdAt: Date;
  updatedAt: Date;
}

// ── Recipe 도메인 ────────────────────────────────────────────
interface Recipe {
  id: string;          // UUID v4
  userId: string;      // FK → User.id
  title: string;       // 최대 200자
  description: string;
  ingredients: Ingredient[];
  instructions: Step[];
  category: string;    // FK → Category.name
  cookingTime: number; // 분 단위
  servings: number;
  mainImage: string;   // S3 URL
  images: string[];    // S3 URL 배열
  viewCount: number;
  likeCount: number;
  isPublished: boolean;
  createdAt: Date;
  updatedAt: Date;
}

interface Ingredient { name: string; amount: string; }
interface Step       { step: number; content: string; }

// ── API 응답 표준 구조 ────────────────────────────────────────
interface ApiResponse<T> {
  data: T;
  message?: string;
}

interface ApiError {
  error: string;  // 사람이 읽을 수 있는 메시지
  code: string;   // 머신 리더블 코드 (e.g. USER_NOT_FOUND)
  details?: Record<string, ValidationDetail>;
}
```

### 5-2. Repository 패턴

```typescript
// 추상 인터페이스 (의존성 역전)
interface IUserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  create(data: CreateUserDto): Promise<User>;
  update(id: string, data: UpdateUserDto): Promise<User>;
  delete(id: string): Promise<void>;
}

// Prisma 구현체
class UserRepository implements IUserRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }
  // ... 나머지 메서드
}
```

### 5-3. Service 레이어 패턴

```typescript
class AuthService {
  constructor(
    private readonly userRepo: IUserRepository,
    private readonly cacheService: CacheService,
  ) {}

  async login(email: string, password: string): Promise<TokenPair> {
    const user = await this.userRepo.findByEmail(email);
    if (!user) throw new AppError('USER_NOT_FOUND', 404);

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) throw new AppError('INVALID_CREDENTIALS', 401);

    const accessToken  = jwt.sign({ sub: user.id, role: user.role },
                                   process.env.JWT_SECRET!, { expiresIn: '15m' });
    const refreshToken = jwt.sign({ sub: user.id },
                                   process.env.JWT_REFRESH_SECRET!, { expiresIn: '7d' });

    await this.cacheService.set(`refresh:${user.id}`, refreshToken, 60 * 60 * 24 * 7);
    return { accessToken, refreshToken };
  }
}
```

### 5-4. 데이터베이스 스키마 (ERD)

```mermaid
erDiagram
    User {
        uuid    id          PK
        string  email       UK "고유 이메일"
        string  password       "bcrypt 해시"
        string  name
        string  role           "user | admin"
        string  profileImage
        text    bio
        datetime createdAt
        datetime updatedAt
    }

    Recipe {
        uuid    id          PK
        uuid    userId      FK
        string  title
        text    description
        json    ingredients    "[{name, amount}]"
        json    instructions   "[{step, content}]"
        string  category    FK
        integer cookingTime    "분 단위"
        integer servings
        string  mainImage      "S3 URL"
        json    images         "S3 URL[]"
        integer viewCount
        integer likeCount
        boolean isPublished
        datetime createdAt
        datetime updatedAt
    }

    Like {
        uuid    id          PK
        uuid    userId      FK
        uuid    recipeId    FK
        datetime createdAt
    }

    Category {
        uuid    id          PK
        string  name        UK
        text    description
        datetime createdAt
    }

    User     ||--o{ Recipe   : "작성한다 (1:N)"
    User     ||--o{ Like     : "누른다 (1:N)"
    Recipe   ||--o{ Like     : "받는다 (1:N)"
    Recipe   }o--|| Category : "속한다 (N:1)"
```

### 5-5. 인덱스 전략

```sql
-- 검색 성능 최적화
CREATE INDEX idx_recipe_title_search ON "Recipe" USING GIN (to_tsvector('korean', title));
CREATE INDEX idx_recipe_category     ON "Recipe" (category);
CREATE INDEX idx_recipe_user_id      ON "Recipe" (userId);
CREATE INDEX idx_recipe_published    ON "Recipe" (isPublished, createdAt DESC);
CREATE INDEX idx_like_composite      ON "Like" (userId, recipeId);
CREATE UNIQUE INDEX uidx_like        ON "Like" (userId, recipeId); -- 중복 좋아요 방지
```

---

## 6. 기술 스택

### Frontend

| 범주 | 기술 | 버전 | 이유 |
|------|------|------|------|
| 프레임워크 | Next.js | 15.5.2 | SSR/CSR 하이브리드, App Router |
| UI 라이브러리 | React | 19.1.1 | 최신 concurrent 기능 |
| 언어 | TypeScript | 5.9 | 타입 안전성, 런타임 에러 방지 |
| 스타일링 | Tailwind CSS | v4 | 유틸리티 우선, 번들 크기 최소화 |
| UI 컴포넌트 | Radix UI + shadcn/ui | - | 접근성 보장, 헤드리스 컴포넌트 |
| 패키지 매니저 | pnpm | 8.15 | 디스크 효율, 빠른 설치 |
| 테스트 | Jest + Playwright | 29, 1.51 | 단위/E2E 테스트 |
| 린팅 | ESLint 9 + Prettier | 9, 3.6 | 코드 품질 일관성 |

### Backend

| 범주 | 기술 | 버전 | 이유 |
|------|------|------|------|
| 런타임 | Node.js | 18 LTS | 안정성, 생태계 |
| 프레임워크 | Express.js | 4.x | 경량, 풍부한 미들웨어 |
| 언어 | TypeScript | 5.x | 타입 안전성 |
| ORM | Prisma | 5.x | 타입 안전 쿼리, 마이그레이션 |
| 인증 | JWT (jsonwebtoken) | - | Stateless 인증 |
| 비밀번호 | bcrypt | - | 단방향 해시 |
| 입력 검증 | Zod | 3.x | 런타임 타입 검증 |
| 이미지 처리 | Multer + Sharp | - | 멀티파트, WebP 변환 |
| 보안 | Helmet.js | - | HTTP 보안 헤더 |
| Rate Limit | express-rate-limit | - | API 남용 방지 |

### 인프라 & DevOps

| 범주 | 기술 | 설명 |
|------|------|------|
| 컨테이너 | Docker + Compose | 개발/프로덕션 환경 일관성 |
| CI/CD | GitHub Actions | 자동 테스트, 빌드, 배포 |
| 프론트엔드 호스팅 | Vercel | 자동 CDN, Preview 배포 |
| 백엔드 호스팅 | Railway / AWS ECS | 컨테이너 기반 배포 |
| DB | PostgreSQL 15 | ACID 보장, Full-Text Search |
| 캐시 | Redis 7 | 인메모리 캐시, Pub/Sub |
| 파일 저장 | AWS S3 | 내구성 11 9s, CDN 연동 |
| 모니터링 | Sentry + Grafana | 에러 추적, 메트릭 시각화 |
| 로깅 | Winston + CloudWatch | 구조화된 로그 수집 |

---

## 7. 통신 방식

### 7-1. Frontend ↔ Backend (REST API)

```
프로토콜: HTTPS (TLS 1.3)
형식:     JSON (Content-Type: application/json)
인증:     Authorization: Bearer <JWT>
버전:     /api/v1/
```

**API 엔드포인트 목록**

| Method | Path | 인증 | 설명 |
|--------|------|------|------|
| GET | `/health` | 없음 | 서버 상태 확인 |
| POST | `/api/users` | 없음 | 회원가입 |
| GET | `/api/users/:id` | 필요 | 사용자 조회 |
| PUT | `/api/users/:id` | 필요 (본인/admin) | 사용자 수정 |
| DELETE | `/api/users/:id` | admin | 사용자 삭제 |
| POST | `/api/auth/login` | 없음 | 로그인 |
| POST | `/api/auth/refresh` | 없음 | 토큰 갱신 |
| POST | `/api/auth/logout` | 필요 | 로그아웃 |
| GET | `/api/recipes` | 없음 | 레시피 목록 |
| POST | `/api/recipes` | 필요 | 레시피 작성 |
| GET | `/api/recipes/:id` | 없음 | 레시피 상세 |
| PUT | `/api/recipes/:id` | 필요 (작성자) | 레시피 수정 |
| DELETE | `/api/recipes/:id` | 필요 (작성자/admin) | 레시피 삭제 |
| POST | `/api/recipes/:id/like` | 필요 | 좋아요 토글 |
| POST | `/api/files/upload` | 필요 | 이미지 업로드 |

**에러 코드 체계**

| HTTP | Code | 설명 |
|------|------|------|
| 400 | `VALIDATION_ERROR` | 입력값 검증 실패 |
| 400 | `EMAIL_EXISTS` | 이미 사용 중인 이메일 |
| 401 | `NO_TOKEN` | Authorization 헤더 없음 |
| 401 | `TOKEN_EXPIRED` | 토큰 만료 |
| 401 | `INVALID_TOKEN` | 서명 검증 실패 |
| 403 | `FORBIDDEN` | 권한 없음 (본인 외 수정 시도) |
| 403 | `ADMIN_REQUIRED` | 관리자 권한 필요 |
| 404 | `USER_NOT_FOUND` | 사용자 없음 |
| 404 | `RECIPE_NOT_FOUND` | 레시피 없음 |
| 500 | `INTERNAL_ERROR` | 서버 내부 오류 |

### 7-2. Backend ↔ PostgreSQL

```
프로토콜:  TCP (포트 5432)
드라이버:  @prisma/client
방식:      Connection Pool (max: 10, min: 2)
SSL:       프로덕션 환경에서 필수
```

### 7-3. Backend ↔ Redis

```
프로토콜: TCP (포트 6379)
클라이언트: ioredis
인코딩:    JSON 직렬화
TTL 전략:
  - 검색 캐시:  5분
  - 레시피 캐시: 10분
  - Refresh 토큰: 7일
  - Rate Limit 카운터: 15분
```

### 7-4. Backend ↔ AWS S3

```
방식:     Presigned URL (보안 직접 업로드)
흐름:     API 서버가 Presigned URL 발급 → 클라이언트가 S3 직접 업로드
CDN:      CloudFront 연동으로 이미지 배포
처리:     업로드 전 Sharp로 WebP 변환, 썸네일 생성
```

---

## 8. 데이터 플로우

### 8-1. 회원가입 & 로그인 플로우

```mermaid
sequenceDiagram
    actor User
    participant FE as Frontend (Next.js)
    participant API as API Server
    participant DB as PostgreSQL
    participant Redis
    participant Mail as SendGrid

    Note over User, Mail: 회원가입 플로우
    User  ->> FE:  이메일 / 비밀번호 입력
    FE    ->> API: POST /api/users { email, name, password }
    API   ->> API: Zod 스키마 검증
    API   ->> DB:  findByEmail() — 중복 확인
    DB    -->> API: null (중복 없음)
    API   ->> API: bcrypt.hash(password, 12)
    API   ->> DB:  user.create()
    DB    -->> API: User { id, email, name, role }
    API   -->> FE: 201 Created { id, email, name, role }
    API   ->> Mail: 이메일 인증 메일 발송 (비동기)

    Note over User, Redis: 로그인 플로우
    User  ->> FE:  이메일 / 비밀번호 입력
    FE    ->> API: POST /api/auth/login
    API   ->> DB:  findByEmail()
    DB    -->> API: User (password 포함)
    API   ->> API: bcrypt.compare()
    API   ->> API: jwt.sign() → accessToken (15분)
    API   ->> API: jwt.sign() → refreshToken (7일)
    API   ->> Redis: SET refresh:{userId} refreshToken TTL=7d
    API   -->> FE: { accessToken, refreshToken }
    FE    ->> FE:  accessToken → 메모리, refreshToken → HttpOnly Cookie
```

### 8-2. 레시피 작성 플로우

```mermaid
sequenceDiagram
    actor User
    participant FE as Frontend
    participant API as API Server
    participant S3 as AWS S3
    participant DB as PostgreSQL
    participant Redis

    User  ->> FE:  레시피 양식 작성 + 이미지 선택
    FE    ->> API: POST /api/files/upload (Authorization: Bearer JWT)
    API   ->> API: JWT 검증 (AuthMiddleware)
    API   ->> S3:  Presigned URL 발급 (PUT, 5분 유효)
    API   -->> FE: { presignedUrl, fileKey }
    FE    ->> S3:  PUT <presignedUrl> (이미지 직접 업로드)
    S3    -->> FE: 200 OK
    FE    ->> API: POST /api/recipes { title, ingredients, ..., mainImage: fileKey }
    API   ->> API: Zod 검증 + JWT 검증
    API   ->> DB:  recipe.create() (userId = JWT subject)
    DB    -->> API: Recipe { id, ... }
    API   ->> Redis: DEL recipe:list:* (캐시 무효화)
    API   -->> FE: 201 Created { recipe }
    FE    -->> User: 레시피 상세 페이지로 이동
```

### 8-3. 레시피 검색 플로우 (캐시 포함)

```mermaid
sequenceDiagram
    actor User
    participant FE as Frontend
    participant API as API Server
    participant Redis
    participant DB as PostgreSQL

    User  ->> FE:  검색어 입력 + 카테고리 선택
    FE    ->> API: GET /api/recipes?search=김치&category=한식&page=1
    API   ->> Redis: GET cache:recipes:김치:한식:1

    alt 캐시 히트 (Cache Hit)
        Redis -->> API: 캐시된 JSON
        API   -->> FE: 200 OK { recipes, pagination }
    else 캐시 미스 (Cache Miss)
        Redis -->> API: null
        API   ->> DB:  SELECT + Full-Text Search + 인덱스 활용
        DB    -->> API: Recipe[]
        API   ->> Redis: SET cache:recipes:김치:한식:1 <JSON> TTL=300s
        API   -->> FE: 200 OK { recipes, pagination }
    end

    FE    -->> User: 레시피 목록 표시
```

### 8-4. 좋아요 토글 플로우

```mermaid
sequenceDiagram
    actor User
    participant FE as Frontend
    participant API as API Server
    participant DB as PostgreSQL
    participant Redis

    User  ->> FE:  좋아요 버튼 클릭
    FE    ->> FE:  Optimistic Update (UI 즉시 반영)
    FE    ->> API: POST /api/recipes/:id/like (Authorization: Bearer JWT)
    API   ->> API: JWT 검증
    API   ->> DB:  BEGIN TRANSACTION
    DB    ->> DB:  like 존재 여부 확인 (UNIQUE INDEX)

    alt 좋아요 추가
        DB    ->> DB:  INSERT INTO like
        DB    ->> DB:  UPDATE recipe SET likeCount = likeCount + 1
    else 좋아요 취소
        DB    ->> DB:  DELETE FROM like
        DB    ->> DB:  UPDATE recipe SET likeCount = likeCount - 1
    end

    DB    ->> DB:  COMMIT
    DB    -->> API: { liked: boolean, likeCount: number }
    API   ->> Redis: DEL cache:recipe:{id}
    API   -->> FE: 200 OK { liked, likeCount }
    FE    -->> User: 최종 상태 반영
```

### 8-5. 토큰 갱신 플로우

```mermaid
sequenceDiagram
    participant FE as Frontend
    participant API as API Server
    participant Redis

    Note over FE: accessToken 만료 (15분 후)
    FE    ->> API: GET /api/recipes (만료된 accessToken)
    API   -->> FE: 401 TOKEN_EXPIRED

    FE    ->> API: POST /api/auth/refresh (refreshToken via HttpOnly Cookie)
    API   ->> Redis: GET refresh:{userId}
    Redis -->> API: 저장된 refreshToken
    API   ->> API: 토큰 일치 검증
    API   ->> API: jwt.sign() → 새 accessToken
    API   -->> FE: { accessToken }
    FE    ->> FE:  새 accessToken 메모리 저장
    FE    ->> API: GET /api/recipes (새 accessToken) — 재시도
```

---

## 9. 보안 아키텍처

### 9-1. 인증 & 인가 계층

```
┌─────────────────────────────────────────────┐
│              요청 수신 (HTTPS)               │
├─────────────────────────────────────────────┤
│     Rate Limiter (100 req/15min/IP)         │
├─────────────────────────────────────────────┤
│     Helmet.js (보안 HTTP 헤더 설정)          │
│     X-Frame-Options, CSP, HSTS 등           │
├─────────────────────────────────────────────┤
│     CORS (허용 Origin 화이트리스트)          │
├─────────────────────────────────────────────┤
│     Request Body 크기 제한 (10MB)           │
├─────────────────────────────────────────────┤
│     Zod 스키마 입력 검증                     │
├─────────────────────────────────────────────┤
│     JWT 인증 미들웨어                        │
│     - 서명 검증 (HS256)                     │
│     - 만료 시간 검증                         │
│     - 사용자 존재 여부 확인                  │
├─────────────────────────────────────────────┤
│     역할 기반 인가 (RBAC)                   │
│     - user: 본인 데이터만                   │
│     - admin: 전체 데이터                    │
├─────────────────────────────────────────────┤
│              비즈니스 로직                   │
└─────────────────────────────────────────────┘
```

### 9-2. 보안 설정 요약

| 항목 | 설정 | 비고 |
|------|------|------|
| 비밀번호 해싱 | bcrypt (rounds: 12) | 브루트포스 방어 |
| Access Token | JWT HS256, TTL 15분 | 메모리에만 저장 |
| Refresh Token | JWT HS256, TTL 7일 | HttpOnly Cookie + Redis |
| HTTPS | TLS 1.3 | 전송 구간 암호화 |
| SQL Injection | Prisma ORM (파라미터 바인딩) | Raw Query 금지 |
| XSS | CSP 헤더 + 입력 이스케이프 | Helmet.js |
| CSRF | SameSite=Strict Cookie | refreshToken 보호 |
| Rate Limiting | 100 req/15min/IP | express-rate-limit |
| 파일 업로드 | Presigned URL (S3 직접 업로드) | 서버 메모리 무부하 |
| 파일 타입 검사 | MIME 타입 + magic bytes 검증 | WebP/JPG/PNG 허용 |

---

## 10. 성능 전략

### 10-1. 다층 캐싱 전략

```mermaid
graph LR
    Browser["🖥️ 브라우저
    Cache-Control
    (정적 파일)"]

    CDN["🌐 CloudFront CDN
    이미지, 정적 파일
    Edge Cache"]

    NextJS["⚛️ Next.js
    Full Route Cache
    Data Cache"]

    Redis["⚡ Redis
    API 응답 캐시
    TTL 5~10분"]

    DB["🗄️ PostgreSQL
    B-Tree / GIN 인덱스
    Connection Pool"]

    Browser --> CDN --> NextJS --> Redis --> DB
    style Redis fill:#DC382D,color:#fff
    style CDN fill:#FF9900,color:#fff
```

### 10-2. 데이터베이스 최적화

| 기법 | 적용 위치 | 효과 |
|------|-----------|------|
| B-Tree 인덱스 | `recipe.userId`, `recipe.category`, `like(userId, recipeId)` | 필터링 쿼리 속도 향상 |
| GIN 인덱스 | `recipe.title` (Full-Text Search) | 한국어 텍스트 검색 |
| Cursor 페이지네이션 | 레시피 목록 API | Offset 방식 대비 일관된 성능 |
| Eager Loading | 레시피 상세 조회 (`include: { user, likes }`) | N+1 문제 방지 |
| Connection Pool | PgPool (max 10, min 2) | DB 연결 재사용 |
| 읽기 전용 쿼리 | PostgreSQL Replica 라우팅 (확장 시) | 주 DB 부하 분산 |

### 10-3. Frontend 최적화

| 기법 | 설명 |
|------|------|
| Server Components | 초기 HTML 서버 렌더링, JS 번들 감소 |
| Code Splitting | 라우트별 자동 번들 분할 (Next.js App Router) |
| Image Optimization | `next/image` + WebP 자동 변환, Lazy Loading |
| Streaming SSR | `Suspense` 경계로 점진적 렌더링 |
| React Query | API 응답 클라이언트 캐싱 + Stale-While-Revalidate |

---

## 11. 배포 아키텍처

### 11-1. 개발 환경 (Docker Compose)

```yaml
# docker-compose.dev.yml 구성
services:
  web:       Next.js (포트 3000)
  db:        PostgreSQL 16-Alpine (포트 5432)
  redis:     Redis 7-Alpine (포트 6379)
  pgadmin:   pgAdmin 4 (포트 5050, DB 관리 UI)
  redis-ui:  RedisInsight (포트 8001, Redis 관리 UI)
```

### 11-2. CI/CD 파이프라인

```mermaid
graph LR
    Dev["👨‍💻 개발자
    git push"]

    subgraph "GitHub Actions"
        Lint["ESLint
        Prettier"]
        Test["Jest Unit
        Playwright E2E"]
        Build["Docker Build
        + Push to ECR"]
        Deploy["Deploy to
        Vercel / Railway"]
    end

    Notify["📬 Slack 알림
    성공/실패"]

    Dev --> Lint --> Test --> Build --> Deploy --> Notify

    style Lint   fill:#4CAF50,color:#fff
    style Test   fill:#2196F3,color:#fff
    style Build  fill:#FF9800,color:#fff
    style Deploy fill:#9C27B0,color:#fff
```

### 11-3. 프로덕션 환경

```mermaid
graph TB
    subgraph "DNS & CDN"
        CF["☁️ CloudFlare
        DNS, DDoS 방어, CDN"]
    end

    subgraph "Frontend [Vercel]"
        Vercel["Next.js App
        자동 글로벌 CDN
        Edge Functions"]
    end

    subgraph "Backend [AWS / Railway]"
        ALB["Application Load Balancer"]
        API1["API Server 1
        (ECS / Container)"]
        API2["API Server 2
        (ECS / Container)"]
    end

    subgraph "Data Layer"
        RDS["PostgreSQL RDS
        Multi-AZ"]
        Replica["Read Replica
        (조회 분산)"]
        EC["Redis ElastiCache
        클러스터 모드"]
        S3["S3 Bucket
        + CloudFront"]
    end

    subgraph "Observability"
        Sentry["Sentry
        에러 추적"]
        Grafana["Grafana
        메트릭 대시보드"]
        CW["CloudWatch
        로그 집계"]
    end

    CF --> Vercel
    Vercel --> ALB
    ALB --> API1 & API2
    API1 & API2 --> RDS & EC & S3
    RDS --> Replica
    API1 & API2 --> Sentry & CW
    CW --> Grafana

    style RDS    fill:#336791,color:#fff
    style EC     fill:#DC382D,color:#fff
    style S3     fill:#FF9900,color:#fff
    style Vercel fill:#000,color:#fff
```

---

## 12. 모니터링 & 운영

### 12-1. 로그 구조 (Winston)

```json
{
  "timestamp": "2026-03-18T09:00:00.000Z",
  "level": "info",
  "service": "cookshare-api",
  "traceId": "abc123",
  "userId": "uuid",
  "method": "POST",
  "path": "/api/recipes",
  "statusCode": 201,
  "responseTime": 45,
  "message": "Recipe created"
}
```

### 12-2. 알림 임계값

| 심각도 | 조건 | 대응 |
|--------|------|------|
| Critical | 서버 다운, DB 연결 실패, 에러율 > 5% | 즉시 온콜 알림 |
| Warning | 응답 시간 P99 > 2초, Redis 메모리 > 80% | 슬랙 알림 |
| Info | 배포 완료, 일일 가입자 보고 | 슬랙 알림 |

### 12-3. 주요 모니터링 메트릭

| 지표 | 목표값 |
|------|--------|
| API 응답시간 P50 | < 100ms |
| API 응답시간 P99 | < 500ms |
| 에러율 (5xx) | < 0.1% |
| 가용성 | > 99.9% |
| Redis 캐시 히트율 | > 80% |
| DB 쿼리 P99 | < 100ms |

---

## 13. 확장성 설계

### 13-1. 수평 확장 (현재 → 미래)

```mermaid
graph TB
    subgraph "현재: 모노리스"
        M_LB["Load Balancer"]
        M_API1["API Server 1"]
        M_API2["API Server 2"]
        M_DB["PostgreSQL Primary"]
        M_RD["PostgreSQL Replica"]
        M_Cache["Redis"]
    end

    subgraph "미래: 마이크로서비스"
        MQ["Message Queue
        (AWS SQS / RabbitMQ)"]
        UserSvc["User Service"]
        RecipeSvc["Recipe Service"]
        NotifySvc["Notification Service"]
        SearchSvc["Search Service
        (Elasticsearch)"]
    end

    M_LB --> M_API1 & M_API2
    M_API1 & M_API2 --> M_DB & M_Cache
    M_DB --> M_RD

    UserSvc & RecipeSvc --> MQ --> NotifySvc
    RecipeSvc --> SearchSvc
```

### 13-2. 마이크로서비스 전환 계획

| 서비스 | 분리 기준 | 독립 DB |
|--------|-----------|---------|
| User Service | 인증/인가 도메인 | PostgreSQL (users) |
| Recipe Service | 레시피 CRUD, 검색 | PostgreSQL (recipes) |
| Interaction Service | 좋아요, 댓글, 팔로우 | Redis + PostgreSQL |
| Notification Service | 이메일, 푸시 알림 | 이벤트 기반 (SQS) |
| Search Service | 전문 검색 | Elasticsearch |

---

## 결론

CookShare 아키텍처는 **MVP 단계의 개발 속도**와 **미래 확장성** 사이의 균형을 목표로 설계되었습니다.

### 핵심 설계 결정 (ADR 요약)

| 결정 | 선택 | 이유 |
|------|------|------|
| 아키텍처 패턴 | 레이어드 모노리스 | MVP 빠른 개발, 마이크로서비스 전환 용이 |
| 렌더링 전략 | Next.js SSR/CSR 하이브리드 | SEO + 인터랙티브 UX |
| 인증 방식 | JWT (Stateless) | 수평 확장 시 세션 공유 불필요 |
| ORM | Prisma | 타입 안전, 마이그레이션 관리 |
| 캐싱 | Redis + Next.js Cache | 다층 캐싱으로 DB 부하 최소화 |
| 파일 저장 | S3 Presigned URL | 서버 무부하 직접 업로드 |

```
확장 가능한 모노리스 → 서비스별 분리 → 마이크로서비스
      (현재)              (트래픽 증가 시)    (대규모 운영 시)
```
