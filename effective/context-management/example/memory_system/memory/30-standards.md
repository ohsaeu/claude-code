# 코딩 표준 및 리뷰 체크리스트

## TypeScript 코딩 규칙

### 기본 원칙
1. **타입 명시적 선언**: `any` 타입 사용 금지
2. **함수 반환 타입**: 복잡한 함수는 반환 타입 명시
3. **인터페이스 우선**: 객체 구조 정의 시 interface 사용
4. **Enum 활용**: 상수 집합은 enum으로 정의

### 네이밍 컨벤션
```typescript
// 좋은 예
interface TaskResponse {
  success: boolean;
  data?: Task;
  error?: string;
}

const MAX_RETRY_COUNT = 3;
let currentTaskId: string;

// 나쁜 예  
interface taskresponse {
  Success: Boolean;
  Data?: any;
}

const max_retry_count = 3;
let CurrentTaskId: String;
```

### 함수 작성 규칙
```typescript
// 좋은 예: 단일 책임, 타입 명시
async function createTask(taskData: CreateTaskRequest): Promise<TaskResponse> {
  if (!taskData.title?.trim()) {
    return { success: false, error: 'Title is required' };
  }
  
  const task = await taskService.create(taskData);
  return { success: true, data: task };
}

// 나쁜 예: 다중 책임, 타입 미명시
function handleTask(data: any) {
  // validation, creation, response 모두 처리
}
```

## Express.js 패턴

### 라우터 구조
```typescript
// routes/tasks.ts
import { Router, Request, Response } from 'express';
import { TaskService } from '../services/task-service';

const router = Router();
const taskService = new TaskService();

router.get('/', async (req: Request, res: Response) => {
  try {
    const tasks = await taskService.getAll();
    res.json({ success: true, data: tasks });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch tasks' 
    });
  }
});

export default router;
```

### 에러 처리
1. **Try-Catch**: 모든 비동기 함수에 에러 처리
2. **HTTP 상태 코드**: 적절한 상태 코드 반환
3. **일관된 응답**: 성공/실패 응답 형식 통일
4. **로깅**: 에러 발생 시 적절한 로그 기록

### 미들웨어 사용
```typescript
// JSON 파싱
app.use(express.json({ limit: '10mb' }));

// CORS 설정
app.use(cors({
  origin: process.env.CLIENT_URL || 'http://localhost:3000',
  methods: ['GET', 'POST', 'PUT', 'DELETE']
}));

// 요청 로깅
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});
```

## Socket.io 패턴

### 이벤트 처리
```typescript
// 좋은 예: 타입 안전한 이벤트 처리
interface ServerToClientEvents {
  'task:created': (task: Task) => void;
  'task:updated': (task: Task) => void;
  'task:deleted': (taskId: string) => void;
}

interface ClientToServerEvents {
  'task:create': (data: CreateTaskRequest) => void;
  'task:update': (id: string, data: UpdateTaskRequest) => void;
}

const io: Server<ClientToServerEvents, ServerToClientEvents> = new Server(server);
```

### 네임스페이스 활용
```typescript
// 기능별 네임스페이스 분리
const taskNamespace = io.of('/tasks');
const adminNamespace = io.of('/admin');

taskNamespace.on('connection', (socket) => {
  socket.on('task:create', handleTaskCreate);
});
```

## 프론트엔드 JavaScript 규칙

### DOM 조작
```javascript
// 좋은 예: 함수형, 재사용 가능
function createElement(tag, className, textContent) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (textContent) element.textContent = textContent;
  return element;
}

// 나쁜 예: 직접 DOM 조작 반복
document.getElementById('taskList').innerHTML += `<div class="task">...</div>`;
```

### 이벤트 처리
```javascript
// 좋은 예: 이벤트 위임 활용
document.getElementById('taskList').addEventListener('click', (event) => {
  if (event.target.matches('.delete-btn')) {
    const taskId = event.target.dataset.taskId;
    deleteTask(taskId);
  }
});

// 나쁜 예: 개별 이벤트 리스너
tasks.forEach(task => {
  const btn = document.getElementById(`delete-${task.id}`);
  btn.addEventListener('click', () => deleteTask(task.id));
});
```

## 코드 리뷰 체크리스트

### ✅ 기본 검증
- [ ] TypeScript 컴파일 오류 없음
- [ ] ESLint 규칙 통과
- [ ] 모든 함수/클래스에 적절한 타입 선언
- [ ] `any` 타입 사용 없음 (불가피한 경우 주석 설명)

### ✅ 아키텍처 준수
- [ ] 계층별 역할 분리 (Router → Service → Model)
- [ ] 의존성 주입 패턴 적용
- [ ] 단일 책임 원칙 준수
- [ ] 인터페이스 기반 설계

### ✅ 에러 처리
- [ ] 모든 비동기 함수에 try-catch 적용
- [ ] 적절한 HTTP 상태 코드 반환
- [ ] 사용자 친화적 에러 메시지
- [ ] 에러 로깅 구현

### ✅ 보안
- [ ] 입력 데이터 검증 (title 필수, 길이 제한)
- [ ] SQL 인젝션 방지 (메모리 저장소이므로 해당 없음)
- [ ] XSS 방지 (사용자 입력 이스케이핑)
- [ ] CORS 적절한 설정

### ✅ 성능
- [ ] 불필요한 데이터베이스 호출 최소화
- [ ] 메모리 누수 방지
- [ ] 적절한 캐싱 전략
- [ ] WebSocket 연결 관리

### ✅ 테스트 가능성
- [ ] 순수 함수로 구현
- [ ] 의존성 주입을 통한 모킹 가능
- [ ] 단위 테스트 작성 용이성
- [ ] 통합 테스트 고려

### ✅ 문서화
- [ ] 복잡한 로직에 주석 설명
- [ ] API 엔드포인트 문서화
- [ ] 메모리 시스템 업데이트
- [ ] README 업데이트 (필요시)

## Linting 설정

### ESLint 규칙 (.eslintrc.json)
```json
{
  "extends": [
    "@typescript-eslint/recommended",
    "prettier"
  ],
  "rules": {
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/explicit-function-return-type": "warn",
    "prefer-const": "error",
    "no-var": "error"
  }
}
```

### Prettier 설정 (.prettierrc)
```json
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 80,
  "tabWidth": 2
}
```

## Git Commit 컨벤션

```
type(scope): description

feat(task): add real-time task updates via WebSocket
fix(api): handle empty task title validation
docs(memory): update architecture decision records
refactor(service): extract task validation logic
test(api): add integration tests for task endpoints
```

### 타입 정의
- `feat`: 새로운 기능
- `fix`: 버그 수정  
- `docs`: 문서 업데이트
- `refactor`: 코드 리팩터링
- `test`: 테스트 코드
- `chore`: 빌드/설정 관련