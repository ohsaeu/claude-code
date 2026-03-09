# 카페 예약 시스템 - CLAUDE.md

## 프로젝트 개요

카페 예약 시스템으로, 고객이 온라인으로 카페 좌석/공간을 예약하고 관리자가 예약을 관리할 수 있는 웹 애플리케이션입니다.

- **기간**: 3개월
- **팀**: 개발자 2명, 디자이너 1명

## 주요 기능

- 회원가입 / 로그인 (JWT 인증)
- 카페 좌석 및 공간 조회
- 날짜/시간 기반 예약 생성, 수정, 취소
- 예약 현황 실시간 확인
- 관리자 대시보드 (예약 관리, 좌석 설정, 통계)
- 예약 확인 이메일 알림

## 기술 스택

### 프론트엔드
- React 18 + TypeScript
- Vite (빌드 도구)
- React Query (서버 상태 관리)
- Zustand (클라이언트 상태 관리)
- React Router v6 (라우팅)
- Tailwind CSS (스타일링)
- React Hook Form + Zod (폼 유효성 검사)

### 백엔드
- Node.js + Express + TypeScript
- Prisma ORM
- PostgreSQL
- JWT (인증)
- Nodemailer (이메일)

### 개발 도구
- pnpm (패키지 매니저)
- ESLint + Prettier
- Husky + lint-staged (커밋 훅)
- Vitest (프론트엔드 테스트)
- Jest + Supertest (백엔드 테스트)

## 디렉터리 구조

```
pjt1/
├── client/                  # 프론트엔드 (React)
│   ├── src/
│   │   ├── api/             # API 호출 함수
│   │   ├── components/      # 공통 컴포넌트
│   │   │   ├── ui/          # 기본 UI 컴포넌트 (Button, Input 등)
│   │   │   └── layout/      # 레이아웃 컴포넌트
│   │   ├── features/        # 기능별 모듈
│   │   │   ├── auth/
│   │   │   ├── reservation/
│   │   │   └── admin/
│   │   ├── hooks/           # 커스텀 훅
│   │   ├── pages/           # 라우트 페이지 컴포넌트
│   │   ├── store/           # Zustand 스토어
│   │   ├── types/           # 공유 타입 정의
│   │   └── utils/           # 유틸리티 함수
│   └── ...
├── server/                  # 백엔드 (Node.js)
│   ├── src/
│   │   ├── controllers/     # 요청 핸들러
│   │   ├── middlewares/     # Express 미들웨어
│   │   ├── routes/          # 라우트 정의
│   │   ├── services/        # 비즈니스 로직
│   │   ├── prisma/          # Prisma 스키마 및 마이그레이션
│   │   └── utils/           # 유틸리티 함수
│   └── ...
└── CLAUDE.md
```

## 자주 사용하는 명령어

### 개발 서버 실행
```bash
# 프론트엔드
cd client && pnpm dev

# 백엔드
cd server && pnpm dev

# 루트에서 동시 실행 (concurrently 설정 시)
pnpm dev
```

### 빌드
```bash
cd client && pnpm build
cd server && pnpm build
```

### 테스트
```bash
# 프론트엔드
cd client && pnpm test
cd client && pnpm test:coverage

# 백엔드
cd server && pnpm test
cd server && pnpm test:e2e
```

### 린트 / 포맷
```bash
pnpm lint          # ESLint 검사
pnpm lint:fix      # ESLint 자동 수정
pnpm format        # Prettier 포맷
```

### 데이터베이스
```bash
cd server
pnpm prisma migrate dev       # 개발 마이그레이션 실행
pnpm prisma migrate deploy    # 프로덕션 마이그레이션 실행
pnpm prisma studio            # Prisma Studio (DB GUI) 실행
pnpm prisma generate          # Prisma 클라이언트 재생성
pnpm prisma db seed           # 시드 데이터 삽입
```

## 코딩 컨벤션

### 공통
- 들여쓰기: 스페이스 2칸
- 세미콜론: 사용 안 함
- 따옴표: 작은따옴표(`'`) 사용
- 줄 길이: 최대 100자
- `any` 타입 사용 금지 — 명확한 타입 또는 `unknown` 사용
- 함수는 가능하면 순수 함수로 작성

### 네이밍 규칙
| 대상 | 규칙 | 예시 |
|------|------|------|
| 컴포넌트 | PascalCase | `ReservationCard.tsx` |
| 훅 | camelCase, `use` 접두사 | `useReservation.ts` |
| 유틸리티 함수 | camelCase | `formatDate.ts` |
| 타입/인터페이스 | PascalCase | `ReservationType` |
| 상수 | UPPER_SNAKE_CASE | `MAX_SEATS` |
| API 함수 | camelCase, 동사 시작 | `fetchReservations` |
| CSS 클래스 | Tailwind 사용, 커스텀 시 kebab-case | |

### React 컴포넌트 작성 규칙
- 함수형 컴포넌트만 사용
- Props 타입은 `interface`로 정의하고 파일 상단에 위치
- 컴포넌트당 파일 하나, 파일명 = 컴포넌트명
- 비즈니스 로직은 커스텀 훅으로 분리
- `features/` 내부 컴포넌트는 해당 기능 폴더 안에서만 import

```tsx
// 권장 컴포넌트 구조
interface ReservationCardProps {
  reservation: ReservationType
  onCancel: (id: string) => void
}

export function ReservationCard({ reservation, onCancel }: ReservationCardProps) {
  // ...
}
```

### API 응답 형식 (백엔드)
```ts
// 성공
{ success: true, data: T }

// 실패
{ success: false, error: { code: string, message: string } }
```

## 팀 협업 규칙

### Git 브랜치 전략
```
main          # 프로덕션 배포 브랜치 (직접 push 금지)
develop       # 개발 통합 브랜치
feature/*     # 기능 개발 (예: feature/reservation-form)
fix/*         # 버그 수정 (예: fix/date-validation)
chore/*       # 설정/도구 변경 (예: chore/eslint-setup)
```

### 커밋 메시지 규칙 (Conventional Commits)
```
feat: 예약 취소 기능 추가
fix: 날짜 선택 시 과거 날짜 선택 방지
chore: ESLint 규칙 업데이트
docs: API 명세 문서 추가
refactor: 예약 서비스 로직 분리
test: 예약 생성 API 테스트 추가
style: 버튼 컴포넌트 스타일 수정
```

### PR(Pull Request) 규칙
- `develop` 브랜치로 PR 생성
- PR 제목은 커밋 메시지 규칙과 동일하게 작성
- 최소 1명의 리뷰어 승인 후 머지
- PR 당 변경 파일 20개 이하 권장
- 머지 방식: Squash and Merge

### 코드 리뷰 규칙
- `nit:` 접두사: 사소한 의견 (반드시 수정 불필요)
- `blocking:` 접두사: 반드시 수정 필요
- 리뷰어는 48시간 내 리뷰 완료
- 본인 PR은 본인이 머지

### 이슈 관리
- 작업 시작 전 이슈 생성 후 브랜치 연결
- 이슈 라벨: `feature`, `bug`, `chore`, `question`
- 완료된 이슈는 PR 머지 시 자동 close (`Closes #이슈번호`)

## 환경 변수

### client/.env
```
VITE_API_BASE_URL=http://localhost:4000/api
```

### server/.env
```
DATABASE_URL=postgresql://user:password@localhost:5432/cafe_reservation
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=7d
PORT=4000
MAIL_HOST=smtp.example.com
MAIL_PORT=587
MAIL_USER=your@email.com
MAIL_PASS=your-password
```

> `.env` 파일은 절대 Git에 커밋하지 않습니다. `.env.example` 파일을 참고하세요.

## 주의사항

- `main` 브랜치에 직접 push 금지
- 커밋 전 `pnpm lint`와 `pnpm test` 통과 확인 (Husky가 자동 실행)
- API 스펙 변경 시 반드시 팀원에게 공유 후 진행
- 디자이너와 협의 없이 UI 컴포넌트 임의 변경 금지
- 새 패키지 추가 시 팀원과 사전 논의
