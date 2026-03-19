# 아키텍처 및 기술 결정 (Architecture Decision Records)

## 아키텍처 개요

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Client    │    │   Express.js    │    │  Memory Store   │
│   (Frontend)    │◄──►│    Server       │◄──►│   (In-Memory)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         └──── WebSocket ────────┘
```

## 기술 스택

### Backend
- **Runtime**: Node.js 18+
- **Framework**: Express.js 4.x
- **WebSocket**: Socket.io
- **Language**: TypeScript
- **Data**: 메모리 기반 저장 (Map/Array)

### Frontend
- **Language**: Vanilla JavaScript (ES6+)
- **Styling**: CSS3 (Flexbox/Grid)
- **WebSocket**: Socket.io Client
- **Build**: 없음 (개발 단순성)

## ADR (Architecture Decision Records)

### ADR-001: TypeScript 선택

**결정**: TypeScript를 주 개발 언어로 사용

**근거**:
- 타입 안전성으로 런타임 오류 최소화
- 코드 자동완성 및 리팩터링 도구 지원
- 대규모 프로젝트 확장성
- Express.js와 Socket.io의 훌륭한 타입 지원

**대안 고려**:
- JavaScript: 단순하지만 타입 안전성 부족
- Python (FastAPI): 학습 곡선 및 Node.js 생태계 활용도

### ADR-002: 메모리 기반 데이터 저장

**결정**: 데이터베이스 대신 메모리 기반 저장소 사용

**근거**:
- 예제 프로젝트 특성상 단순성 우선
- 설정 복잡도 최소화
- 빠른 개발 및 테스트
- 메모리 시스템 학습에 집중

**제약사항**:
- 서버 재시작 시 데이터 소실
- 메모리 사용량 제한
- 동시성 제어 수동 구현 필요

### ADR-003: Socket.io 선택

**결정**: WebSocket 라이브러리로 Socket.io 사용

**근거**:
- 폴백 메커니즘 (Long polling 등)
- 간단한 API와 풍부한 기능
- 브라우저 호환성
- 개발 도구 및 문서화 우수

**대안**:
- 네이티브 WebSocket: 기본 기능만 제공
- ws 라이브러리: 더 가벼우나 기능 제한

### ADR-004: Vanilla JavaScript Frontend

**결정**: React/Vue 대신 Vanilla JavaScript 사용

**근거**:
- 학습 곡선 최소화
- 빌드 도구 설정 불필요
- 메모리 시스템에 집중
- 가벼운 프로젝트 구조

**제약사항**:
- 복잡한 상태 관리 시 불편
- 재사용성 제한
- 개발 생산성 상대적 저하

## 디렉토리 구조

```
memory_system/
├── memory/              # 메모리 시스템
├── src/
│   ├── server/         # Express.js 서버
│   │   ├── app.ts      # 메인 앱
│   │   ├── routes/     # API 라우트
│   │   ├── models/     # 데이터 모델
│   │   └── services/   # 비즈니스 로직
│   └── client/         # 프론트엔드
│       ├── index.html
│       ├── app.js
│       └── styles.css
├── package.json
├── tsconfig.json
└── CLAUDE.md
```

## 데이터 모델

```typescript
interface Task {
  id: string;
  title: string;
  description?: string;
  completed: boolean;
  createdAt: Date;
  updatedAt: Date;
}

interface TaskStore {
  tasks: Map<string, Task>;
  getAll(): Task[];
  create(task: Omit<Task, 'id' | 'createdAt' | 'updatedAt'>): Task;
  update(id: string, updates: Partial<Task>): Task | null;
  delete(id: string): boolean;
}
```

## API 설계

### REST Endpoints
- `GET /api/tasks` - 모든 태스크 조회
- `POST /api/tasks` - 새 태스크 생성
- `PUT /api/tasks/:id` - 태스크 업데이트
- `DELETE /api/tasks/:id` - 태스크 삭제

### WebSocket Events
- `task:created` - 새 태스크 생성됨
- `task:updated` - 태스크 업데이트됨
- `task:deleted` - 태스크 삭제됨