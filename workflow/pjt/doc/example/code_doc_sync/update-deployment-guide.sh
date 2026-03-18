#!/usr/bin/env bash
# =============================================================================
# update-deployment-guide.sh
# GETTING_STARTED.md 하단의 "최근 배포 정보" 섹션을 자동으로 갱신하고
# HTML 버전을 site/deployment-guide/index.html 에 생성합니다.
#
# 사용법:
#   ./scripts/update-deployment-guide.sh <commit_sha> <branch> <datetime> <actor>
#
# 예시:
#   ./scripts/update-deployment-guide.sh abc1234 main "2024-01-15 09:00:00 UTC" "octocat"
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
success() { echo -e "${GREEN}✓${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✗${NC}  $*" >&2; }

# ── 인수 파싱 ──
COMMIT_SHA="${1:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}"
BRANCH="${2:-$(git branch --show-current 2>/dev/null || echo 'main')}"
BUILD_DATETIME="${3:-$(date '+%Y-%m-%d %H:%M:%S %Z')}"
ACTOR="${4:-$(git config user.name 2>/dev/null || echo 'unknown')}"

# 짧은 커밋 해시 (7자)
SHORT_SHA="${COMMIT_SHA:0:7}"

# ── 경로 설정 ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_DIR}/../../.." && pwd)"
GUIDE_SOURCE="${REPO_ROOT}/week3/Fri/getting_started/GETTING_STARTED.md"
GUIDE_DEST_DIR="${PROJECT_DIR}/site/deployment-guide"
GUIDE_DEST="${GUIDE_DEST_DIR}/index.html"

# ── GETTING_STARTED.md 최근 배포 정보 갱신 ──
if [ ! -f "${GUIDE_SOURCE}" ]; then
  warn "GETTING_STARTED.md 를 찾을 수 없습니다: ${GUIDE_SOURCE}"
  warn "배포 가이드 업데이트를 건너뜁니다."
  exit 0
fi

# 최근 배포 정보 섹션 마커
MARKER_START="<!-- DEPLOYMENT_INFO_START -->"
MARKER_END="<!-- DEPLOYMENT_INFO_END -->"

# 최근 커밋 로그 (최대 5개) - git이 없을 경우 대비
if command -v git &>/dev/null && git -C "${REPO_ROOT}" rev-parse HEAD &>/dev/null 2>&1; then
  RECENT_COMMITS=$(git -C "${REPO_ROOT}" log --oneline -5 2>/dev/null \
    | sed 's/^/    - /' || echo "    - (커밋 히스토리 없음)")
else
  RECENT_COMMITS="    - (커밋 히스토리 없음)"
fi

# 삽입할 배포 정보 블록
DEPLOYMENT_BLOCK="${MARKER_START}
<!-- 이 섹션은 CI/CD에 의해 자동으로 갱신됩니다. 수동으로 수정하지 마세요. -->

## 최근 배포 정보

| 항목 | 값 |
|------|-----|
| **빌드 시각** | ${BUILD_DATETIME} |
| **브랜치** | \`${BRANCH}\` |
| **커밋** | \`${SHORT_SHA}\` |
| **배포자** | ${ACTOR} |

### 최근 변경 사항 (최근 5 커밋)

${RECENT_COMMITS}

${MARKER_END}"

# 기존 배포 정보 섹션이 있으면 교체, 없으면 파일 끝에 추가
if grep -q "${MARKER_START}" "${GUIDE_SOURCE}"; then
  # Python을 이용해 마커 사이 내용 교체 (macOS/Linux 호환)
  python3 - "${GUIDE_SOURCE}" "${MARKER_START}" "${MARKER_END}" "${DEPLOYMENT_BLOCK}" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
start_marker = sys.argv[2]
end_marker = sys.argv[3]
new_block = sys.argv[4]

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 마커 사이의 내용을 새 블록으로 교체
pattern = re.escape(start_marker) + r'.*?' + re.escape(end_marker)
new_content = re.sub(pattern, new_block, content, flags=re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("배포 정보 섹션 갱신 완료")
PYEOF
else
  # 마커가 없으면 파일 끝에 추가
  echo "" >> "${GUIDE_SOURCE}"
  echo "${DEPLOYMENT_BLOCK}" >> "${GUIDE_SOURCE}"
fi

success "GETTING_STARTED.md 배포 정보 갱신: ${SHORT_SHA} @ ${BUILD_DATETIME}"

# ── HTML 생성 (Python 스크립트를 임시 파일로 작성 후 실행) ──
mkdir -p "${GUIDE_DEST_DIR}"
TMPPY="$(mktemp /tmp/md2html.XXXXXX.py)"
trap 'rm -f "${TMPPY}"' EXIT

cat > "${TMPPY}" << 'PYEOF'
import sys, re, html as html_mod

src, dest, dt, sha, branch = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

with open(src, 'r', encoding='utf-8') as f:
    md = f.read()

lines = md.split('\n')
body_lines = []
in_code = False
in_table = False

for line in lines:
    if line.startswith('```'):
        if in_code:
            body_lines.append('</code></pre>')
            in_code = False
        else:
            lang = line[3:].strip()
            body_lines.append(f'<pre><code class="language-{lang}">')
            in_code = True
        continue
    if in_code:
        body_lines.append(html_mod.escape(line))
        continue
    line = re.sub(r'<!--.*?-->', '', line).rstrip()
    if line.startswith('#### '): body_lines.append(f'<h4>{line[5:]}</h4>')
    elif line.startswith('### '): body_lines.append(f'<h3>{line[4:]}</h3>')
    elif line.startswith('## '): body_lines.append(f'<h2>{line[3:]}</h2>')
    elif line.startswith('# '): body_lines.append(f'<h1>{line[2:]}</h1>')
    elif line.startswith('|'):
        if not in_table:
            body_lines.append('<table>')
            in_table = True
        cells = [c.strip() for c in line.strip('|').split('|')]
        if all(re.match(r'^[-:]+$', c) for c in cells if c):
            continue
        body_lines.append('<tr>' + ''.join(f'<td>{c}</td>' for c in cells) + '</tr>')
    else:
        if in_table:
            body_lines.append('</table>')
            in_table = False
        line = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', line)
        line = re.sub(r'`(.+?)`', r'<code>\1</code>', line)
        line = re.sub(r'\[(.+?)\]\((.+?)\)', r'<a href="\2">\1</a>', line)
        if line.startswith('- '): body_lines.append(f'<li>{line[2:]}</li>')
        elif line.strip() == '': body_lines.append('<br>')
        else: body_lines.append(f'<p>{line}</p>')

if in_table: body_lines.append('</table>')
body = '\n'.join(body_lines)

page = f"""<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Deployment Guide</title>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8f9fa; color: #212529; }}
    nav {{ background: #24292e; padding: 0.8rem 2rem; display: flex; align-items: center; gap: 1.5rem; position: sticky; top: 0; z-index: 100; }}
    nav .logo {{ color: #fff; font-weight: 700; font-size: 1.1rem; margin-right: auto; }}
    nav a {{ color: #58a6ff; text-decoration: none; font-size: 0.9rem; }}
    nav a:hover {{ color: #79c0ff; }}
    .container {{ max-width: 960px; margin: 0 auto; padding: 2rem 1.5rem; }}
    .meta-bar {{ background: #e8f4fd; border-left: 4px solid #0366d6; padding: 0.8rem 1rem; margin-bottom: 2rem; border-radius: 0 4px 4px 0; font-size: 0.85rem; color: #444; display: flex; gap: 1.5rem; flex-wrap: wrap; }}
    .meta-bar span {{ display: flex; align-items: center; gap: 0.4rem; }}
    h1, h2, h3, h4 {{ margin: 1.5rem 0 0.8rem; color: #1a1a2e; }}
    h1 {{ border-bottom: 2px solid #e1e4e8; padding-bottom: 0.5rem; font-size: 2rem; }}
    h2 {{ border-bottom: 1px solid #e1e4e8; padding-bottom: 0.3rem; font-size: 1.5rem; }}
    p {{ margin: 0.6rem 0; line-height: 1.7; }}
    pre {{ background: #1e1e2e; color: #cdd6f4; padding: 1.2rem; border-radius: 8px; overflow-x: auto; margin: 1rem 0; }}
    code {{ font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', monospace; font-size: 0.88em; }}
    p code, li code {{ background: #f0f0f0; padding: 0.15em 0.4em; border-radius: 3px; color: #e83e8c; }}
    table {{ border-collapse: collapse; width: 100%; margin: 1rem 0; }}
    th, td {{ border: 1px solid #dfe2e5; padding: 0.5rem 1rem; text-align: left; }}
    th {{ background: #f6f8fa; font-weight: 600; }}
    tr:nth-child(even) {{ background: #f9f9f9; }}
    li {{ margin: 0.3rem 0 0.3rem 1.5rem; line-height: 1.6; }}
    a {{ color: #0366d6; }}
    a:hover {{ text-decoration: underline; }}
  </style>
</head>
<body>
  <nav>
    <span class="logo">📚 Docs Portal</span>
    <a href="../index.html">Home</a>
    <a href="../typedoc/index.html">TypeDoc</a>
    <a href="../api-reference/index.html">API Reference</a>
    <a href="index.html">Deployment Guide</a>
  </nav>
  <div class="container">
    <div class="meta-bar">
      <span>🕐 빌드: {dt}</span>
      <span>🔀 브랜치: <code>{branch}</code></span>
      <span>📌 커밋: <code>{sha}</code></span>
    </div>
    {body}
  </div>
</body>
</html>"""

with open(dest, 'w', encoding='utf-8') as f:
    f.write(page)
print(f"HTML 생성 완료: {dest}")
PYEOF

python3 "${TMPPY}" \
  "${GUIDE_SOURCE}" "${GUIDE_DEST}" \
  "${BUILD_DATETIME}" "${SHORT_SHA}" "${BRANCH}"

success "배포 가이드 HTML 생성 완료: ${GUIDE_DEST}"
