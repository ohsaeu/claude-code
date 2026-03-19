### API 응답 시간이 느린 문제를 단계별로 해결해줘.
- 단계 1: 현재 응답 시간 측정 및 병목 지점 식별
- 단계 2: 데이터베이스 쿼리 성능 분석
- 단계 3: 네트워크 지연 요인 검토
- 단계 4: 캐싱 전략 검토 및 개선안 제시
- 단계 5: 최적화 솔루션 구현 및 검증


### 마이크로서비스를 단계별로 분리해줘
1. 먼저 서비스 경계 식별 (완료 후 확인)
2. 데이터베이스 분리 계획 (1단계 기반)
3. API 게이트웨이 설정 (2단계 완료 필요)
4. 서비스 간 통신 구현 (3단계 의존)
5. 트랜잭션 관리 구현 (모든 서비스 준비 후)
각 단계의 산출물을 다음 단계의 입력으로 사용해


### 최적의 데이터베이스 설계를 찾아줘
- 경로 1: NoSQL (MongDB)
 - 장점 분석
 - 단점 분석
 - 적합성 점수
- 경로 2: SQL (PostgreSQL)
 - 장점 분석
 - 단점 분석
 - 적합성 점수
- 경로 3: 하이브리드
 - 구현 복잡도
 - 성능 이득
 - 유지보수성
- 모든 경로를 평가한 후 최종 추천


### API 엔드포인트를 구현하고 반복 개선해줘
반복 1: 기본 기능 구현
 - 자체 평가: 동작하지만 에러 처리 부족
반복 2: 에러 처리 추가
 - 자체 평가: 안정적이지만 성능 이슈 가능
반복 3: 캐싱과 최적화 적용
 - 자체 평가: 성능 좋지만 보안 고려 필요
반복 4: 보안 강화
 - 최종 평가 및 완료


###  .claude/settings.json
{
  "env": {
     "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "4096",
     "MAX_MCP_OUTPUT_TOKENS": "25000"
   }
}


###  예외 처리
echo "node_modules/" >> .claudeignore
echo "*.log" >> .claudeignore
echo "dist/" >> .claudeignore

### 이 작업엔 memory/10-architecture.md와 memory/30-standards.md를 참고해

#### 메모리 파일 분리 전략
.claude/
  memory/
    00-brief.md		# 프로젝트 개요, 목표
    10-architecture.md	# 아키텍쳐 결정 (ADR)
    20-glossary.yaml		# 용어집
    30-standards.md		# 코딩 규칙, 리뷰 체크리스트
    40-runtime.md		# 성능/리소스 제약
    90-known-issues.md	# 반복되는 문제 & 우회책

#### cat CLAUDE.md
이 프로젝트에서 참조할 메모리 파일 목록:
- 프로젝트 개요: memory/00-brief.md		
- 아키텍쳐 결정: memory/10-architecture.md	
- 용어집: memory/20-glossary.yaml		
- 코딩 규칙: memory/30-standards.md		
- 성능 제약: memory/40-runtime.md		
- 알려진 문제: memory/90-known-issues.md	


