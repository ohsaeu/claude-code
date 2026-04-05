
### useful link
https://github.com/kiliczsh/claude-cmd

### built in commands
- /security-review
- /reviewe
- /install-github-app
- /init
- /help

### temp
```txt
#!/bin/sh
# 현재 브랜치 이름 가져오기
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 최신 리모트 가져오기
git fetch origin $BRANCH

# 로컬 vs 리모트 diff 추출
git diff origin/$BRANCH..$BRANCH > diff.txt

# Continue AI 리뷰 실행
continue review diff.txt
```
