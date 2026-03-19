# 런타임 및 운영 환경 정보

## 성능 요구사항

### 응답 시간 목표
- **API 응답**: 평균 200ms 이하
- **WebSocket 메시지**: 50ms 이하
- **페이지 로딩**: 1초 이하 (초기 로드)
- **실시간 업데이트**: 100ms 이하

### 처리량 목표
- **동시 사용자**: 최대 100명
- **API 요청**: 초당 1000 요청
- **WebSocket 연결**: 동시 100개 연결
- **메모리 사용량**: 최대 512MB

## 리소스 제약사항

### 메모리 관리
```typescript
// 메모리 사용량 모니터링
class MemoryMonitor {
  private maxTasks = 10000; // 최대 태스크 수
  private maxConnections = 100; // 최대 WebSocket 연결
  
  checkMemoryUsage(): boolean {
    const used = process.memoryUsage();
    const maxMemory = 512 * 1024 * 1024; // 512MB
    
    if (used.heapUsed > maxMemory * 0.8) {
      console.warn('Memory usage high:', used.heapUsed / 1024 / 1024, 'MB');
      return false;
    }
    return true;
  }
}
```

### CPU 사용률
- **정상 운영**: 10-30%
- **피크 시간**: 최대 70%
- **임계점**: 80% (성능 저하 시작)

### 네트워크 대역폭
- **클라이언트당**: 최대 1Mbps
- **전체 서버**: 최대 100Mbps
- **WebSocket 오버헤드**: 연결당 평균 1KB/s

## 환경 설정

### 개발 환경
```env
NODE_ENV=development
PORT=3000
LOG_LEVEL=debug
CORS_ORIGIN=http://localhost:3000
MAX_TASKS=1000
MAX_CONNECTIONS=50
```

### 프로덕션 환경
```env
NODE_ENV=production
PORT=8080
LOG_LEVEL=info
CORS_ORIGIN=https://yourdomain.com
MAX_TASKS=10000
MAX_CONNECTIONS=100
```

### 환경별 차이점
| 설정 | 개발 | 프로덕션 |
|------|------|----------|
| 포트 | 3000 | 8080 |
| 로그 레벨 | debug | info |
| 최대 태스크 | 1,000 | 10,000 |
| 최대 연결 | 50 | 100 |
| CORS | localhost | 도메인 제한 |

## 모니터링 메트릭

### 시스템 메트릭
```typescript
interface SystemMetrics {
  memory: {
    used: number;
    free: number;
    percentage: number;
  };
  cpu: {
    usage: number;
    loadAverage: number[];
  };
  connections: {
    active: number;
    total: number;
  };
  tasks: {
    count: number;
    operations: {
      create: number;
      read: number;
      update: number;
      delete: number;
    };
  };
}
```

### 성능 임계값
```typescript
const PERFORMANCE_THRESHOLDS = {
  memory: {
    warning: 0.7,  // 70%
    critical: 0.9  // 90%
  },
  cpu: {
    warning: 0.6,  // 60%
    critical: 0.8  // 80%
  },
  responseTime: {
    warning: 300,   // 300ms
    critical: 500   // 500ms
  },
  connections: {
    warning: 80,    // 80개
    critical: 95    // 95개
  }
};
```

## 캐싱 전략

### 메모리 캐싱
```typescript
// 단순 LRU 캐시 구현
class LRUCache<T> {
  private cache = new Map<string, T>();
  private maxSize = 1000;
  
  get(key: string): T | undefined {
    const value = this.cache.get(key);
    if (value) {
      // LRU: 최근 사용된 항목을 앞으로
      this.cache.delete(key);
      this.cache.set(key, value);
    }
    return value;
  }
  
  set(key: string, value: T): void {
    if (this.cache.size >= this.maxSize) {
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
    }
    this.cache.set(key, value);
  }
}
```

### 캐시 무효화
- **태스크 생성**: 전체 목록 캐시 무효화
- **태스크 수정**: 해당 태스크 및 목록 캐시 무효화
- **태스크 삭제**: 해당 태스크 및 목록 캐시 무효화

## 로깅 전략

### 로그 레벨
```typescript
enum LogLevel {
  ERROR = 0,
  WARN = 1,
  INFO = 2,
  DEBUG = 3
}

class Logger {
  constructor(private level: LogLevel) {}
  
  error(message: string, meta?: object): void {
    if (this.level >= LogLevel.ERROR) {
      console.error(`[ERROR] ${new Date().toISOString()} - ${message}`, meta);
    }
  }
  
  warn(message: string, meta?: object): void {
    if (this.level >= LogLevel.WARN) {
      console.warn(`[WARN] ${new Date().toISOString()} - ${message}`, meta);
    }
  }
  
  info(message: string, meta?: object): void {
    if (this.level >= LogLevel.INFO) {
      console.info(`[INFO] ${new Date().toISOString()} - ${message}`, meta);
    }
  }
  
  debug(message: string, meta?: object): void {
    if (this.level >= LogLevel.DEBUG) {
      console.debug(`[DEBUG] ${new Date().toISOString()} - ${message}`, meta);
    }
  }
}
```

### 로그 항목
1. **요청 로깅**: 모든 HTTP/WebSocket 요청
2. **에러 로깅**: 예외 및 오류 상황
3. **성능 로깅**: 느린 응답 시간
4. **보안 로깅**: 의심스러운 활동

## 에러 복구 전략

### 자동 재시작
```typescript
// PM2 설정 예시
module.exports = {
  apps: [{
    name: 'memory-system-app',
    script: './dist/server/app.js',
    instances: 1,
    exec_mode: 'cluster',
    max_memory_restart: '512M',
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
```

### 우아한 종료 (Graceful Shutdown)
```typescript
process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

async function gracefulShutdown(signal: string): Promise<void> {
  console.log(`Received ${signal}. Shutting down gracefully...`);
  
  // 새 연결 거부
  server.close(() => {
    console.log('HTTP server closed');
  });
  
  // WebSocket 연결 종료
  io.close(() => {
    console.log('Socket.io server closed');
  });
  
  // 진행 중인 작업 완료 대기 (최대 5초)
  setTimeout(() => {
    console.log('Force shutdown');
    process.exit(0);
  }, 5000);
}
```

## 헬스 체크

### 엔드포인트
```typescript
app.get('/health', (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.env.npm_package_version
  };
  
  res.json(health);
});
```

### 체크 항목
- [ ] HTTP 서버 응답 가능
- [ ] WebSocket 연결 가능
- [ ] 메모리 사용량 정상
- [ ] CPU 사용률 정상
- [ ] 활성 연결 수 정상

## 배포 고려사항

### 단계별 배포
1. **로컬 테스트**: 개발 환경에서 기능 확인
2. **스테이징**: 프로덕션과 유사한 환경에서 테스트
3. **프로덕션**: 실제 서비스 배포

### 롤백 계획
- **버전 관리**: Git 태그를 통한 버전 관리
- **빠른 롤백**: 이전 버전으로 즉시 전환 가능
- **데이터 백업**: 메모리 데이터는 일시적이므로 해당 없음