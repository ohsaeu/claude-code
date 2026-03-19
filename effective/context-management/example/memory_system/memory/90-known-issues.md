# 알려진 문제 및 해결책

## 자주 발생하는 문제들

### 1. WebSocket 연결 문제

#### 문제 설명
클라이언트에서 WebSocket 연결이 간헐적으로 실패하거나 끊어짐

#### 원인
- 네트워크 불안정
- 방화벽/프록시 설정
- 브라우저별 WebSocket 구현 차이
- Socket.io 버전 호환성

#### 해결책
```javascript
// 클라이언트: 재연결 로직 구현
const socket = io({
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionAttempts: 5,
  timeout: 20000,
  transports: ['websocket', 'polling']
});

socket.on('disconnect', (reason) => {
  console.log('Disconnected:', reason);
  if (reason === 'io server disconnect') {
    socket.connect();
  }
});

socket.on('reconnect', (attemptNumber) => {
  console.log('Reconnected after', attemptNumber, 'attempts');
  // 데이터 재동기화
  fetchTasks();
});
```

#### 예방책
- Socket.io 폴백 메커니즘 활용
- 연결 상태 UI 표시
- 오프라인 모드 지원 고려

---

### 2. 메모리 누수

#### 문제 설명
장시간 서버 운영 시 메모리 사용량이 지속적으로 증가

#### 원인
- WebSocket 연결 객체가 적절히 정리되지 않음
- 태스크 데이터가 계속 누적
- 이벤트 리스너가 제거되지 않음

#### 해결책
```typescript
// 서버: 연결 정리 및 가비지 컬렉션
class ConnectionManager {
  private connections = new Map<string, Socket>();
  
  addConnection(socket: Socket): void {
    this.connections.set(socket.id, socket);
    
    socket.on('disconnect', () => {
      this.connections.delete(socket.id);
      console.log(`Connection ${socket.id} removed`);
    });
  }
  
  cleanup(): void {
    // 5분마다 비활성 연결 정리
    setInterval(() => {
      for (const [id, socket] of this.connections) {
        if (!socket.connected) {
          this.connections.delete(id);
        }
      }
    }, 5 * 60 * 1000);
  }
}

// 태스크 수 제한
class TaskStore {
  private maxTasks = 10000;
  
  create(task: CreateTaskRequest): Task {
    if (this.tasks.size >= this.maxTasks) {
      // 오래된 완료된 태스크 삭제
      this.cleanupOldTasks();
    }
    // ... 태스크 생성 로직
  }
  
  private cleanupOldTasks(): void {
    const completedTasks = Array.from(this.tasks.values())
      .filter(task => task.completed)
      .sort((a, b) => a.updatedAt.getTime() - b.updatedAt.getTime());
      
    const toDelete = completedTasks.slice(0, 1000);
    toDelete.forEach(task => this.tasks.delete(task.id));
  }
}
```

#### 모니터링
```typescript
// 메모리 사용량 주기적 체크
setInterval(() => {
  const usage = process.memoryUsage();
  const mbUsage = {
    rss: Math.round(usage.rss / 1024 / 1024),
    heapUsed: Math.round(usage.heapUsed / 1024 / 1024),
    heapTotal: Math.round(usage.heapTotal / 1024 / 1024)
  };
  
  if (mbUsage.heapUsed > 400) {
    console.warn('High memory usage:', mbUsage);
  }
}, 30000);
```

---

### 3. CORS 오류

#### 문제 설명
프론트엔드에서 API 호출 시 CORS 에러 발생

#### 원인
- 잘못된 CORS 설정
- 환경별 설정 차이
- Preflight 요청 처리 미흡

#### 해결책
```typescript
// 환경별 CORS 설정
const corsOptions = {
  origin: (origin: string | undefined, callback: Function) => {
    const allowedOrigins = process.env.NODE_ENV === 'production' 
      ? ['https://yourdomain.com']
      : ['http://localhost:3000', 'http://127.0.0.1:3000'];
      
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
};

app.use(cors(corsOptions));
```

---

### 4. 동시성 문제

#### 문제 설명
여러 클라이언트가 동시에 같은 태스크를 수정할 때 데이터 불일치

#### 원인
- 메모리 기반 저장소의 동시성 제어 부재
- 낙관적 잠금 미구현
- 실시간 업데이트 충돌

#### 해결책
```typescript
// 간단한 버전 기반 동시성 제어
interface TaskWithVersion extends Task {
  version: number;
}

class TaskService {
  update(id: string, updates: Partial<Task>, expectedVersion?: number): Task | null {
    const existing = this.tasks.get(id);
    if (!existing) return null;
    
    // 버전 체크
    if (expectedVersion && existing.version !== expectedVersion) {
      throw new Error('Task has been modified by another user');
    }
    
    const updated = {
      ...existing,
      ...updates,
      version: existing.version + 1,
      updatedAt: new Date()
    };
    
    this.tasks.set(id, updated);
    return updated;
  }
}
```

#### 클라이언트 처리
```javascript
async function updateTask(taskId, updates, version) {
  try {
    const response = await fetch(`/api/tasks/${taskId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...updates, version })
    });
    
    if (response.status === 409) {
      alert('Task has been modified by another user. Please refresh.');
      return;
    }
    
    const result = await response.json();
    return result;
  } catch (error) {
    console.error('Update failed:', error);
  }
}
```

---

### 5. TypeScript 컴파일 오류

#### 문제 설명
빌드 시 TypeScript 타입 오류 발생

#### 자주 발생하는 케이스
```typescript
// 문제: any 타입 사용
socket.on('task:create', (data: any) => {
  // 타입 안전성 없음
});

// 해결: 타입 정의
interface CreateTaskData {
  title: string;
  description?: string;
}

socket.on('task:create', (data: CreateTaskData) => {
  // 타입 안전성 확보
});

// 문제: 선택적 체이닝 누락
const taskTitle = task.title.trim(); // task가 undefined일 수 있음

// 해결: 안전한 접근
const taskTitle = task?.title?.trim() ?? '';
```

#### tsconfig.json 권장 설정
```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

---

## 트러블슈팅 가이드

### 디버깅 도구

#### 서버 로깅 확장
```typescript
// 디버깅용 상세 로깅
class DebugLogger {
  static logRequest(req: Request): void {
    console.log(`[REQ] ${req.method} ${req.path}`, {
      headers: req.headers,
      body: req.body,
      query: req.query,
      timestamp: new Date().toISOString()
    });
  }
  
  static logResponse(res: Response, data: any): void {
    console.log(`[RES] ${res.statusCode}`, {
      data,
      timestamp: new Date().toISOString()
    });
  }
  
  static logSocketEvent(event: string, data: any): void {
    console.log(`[SOCKET] ${event}`, {
      data,
      timestamp: new Date().toISOString()
    });
  }
}
```

#### 클라이언트 디버깅
```javascript
// 브라우저 개발자 도구 활용
window.debugTasks = {
  logState: () => console.table(tasks),
  logConnections: () => console.log('Socket connected:', socket.connected),
  simulateError: () => socket.emit('invalid-event', 'test'),
  clearTasks: () => {
    tasks.length = 0;
    renderTasks();
  }
};
```

### 성능 프로파일링

#### 서버 측 프로파일링
```typescript
// 응답 시간 측정
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (duration > 200) {
      console.warn(`Slow request: ${req.method} ${req.path} took ${duration}ms`);
    }
  });
  
  next();
});
```

#### 메모리 프로파일링
```bash
# Node.js 내장 프로파일러 사용
node --inspect --prof ./dist/server/app.js

# Chrome DevTools 연결
# chrome://inspect
```

### 일반적인 해결 순서

1. **문제 재현**: 최소한의 케이스로 문제 재현
2. **로그 확인**: 서버/클라이언트 로그 분석
3. **네트워크 확인**: 브라우저 개발자 도구 Network 탭
4. **메모리 확인**: `process.memoryUsage()` 출력
5. **코드 검토**: 최근 변경사항 확인
6. **환경 비교**: 개발/프로덕션 환경 차이 분석

### 예방 조치

#### 코드 품질
- ESLint + Prettier 사용
- 단위 테스트 작성
- 타입스크립트 strict 모드
- 코드 리뷰 필수

#### 모니터링
- 애플리케이션 메트릭 수집
- 에러 추적 시스템 (선택사항)
- 헬스 체크 엔드포인트
- 로그 집계 및 분석

#### 문서화
- 메모리 시스템 지속 업데이트
- API 변경사항 기록
- 운영 절차 문서화
- 인시던트 사후 분석