# 프린트 모드
사용자 개입 없이 결과를 출력하는 모드

```bash
# 기본 프린트 모드 실행
$ claude --print "테스트를 실행하고 실패한 부분을 수정해줘"

# 짧은 형태
$ claude --print "코드 리뷰 수행" > review.md

# json 포맷으로 출력
$ claude --print --output-format json "테스트 결과 요약" > result.json
```

### CI/CD 통합 예시

```bash
# .github/workflows/claude-review.yml

name: cluade code review

on: [pull_request]

jobs:
  claude-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: setup claude code
        run: |
          npm install -g @anthropic/claude-code

      - name: run claude code review
        run: |
           claude --print "pr의 모든 변경 사항을 검토하고 개선점을 제안해줘" > review.md

      - name: comment pr
        uses: actions/github-script@v6
        with:
          script: |
             const fs = require('fs');
             const review = fs.readFileSync('review.md', 'utf-8');
             github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: review});

```
