#!/usr/bin/env bash
# =============================================================================
# build-docs-site.sh
# site/ 디렉터리에 통합 문서 포털 index.html을 생성합니다.
# TypeDoc, OpenAPI, 배포 가이드를 한 곳에서 탐색할 수 있는 랜딩 페이지.
#
# 사용법:
#   ./scripts/build-docs-site.sh <commit_sha> <branch> <datetime> <repository>
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
success() { echo -e "${GREEN}✓${NC}  $*"; }

# ── 인수 파싱 ──
COMMIT_SHA="${1:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}"
BRANCH="${2:-$(git branch --show-current 2>/dev/null || echo 'main')}"
BUILD_DATETIME="${3:-$(date '+%Y-%m-%d %H:%M:%S %Z')}"
REPOSITORY="${4:-local/repository}"
SHORT_SHA="${COMMIT_SHA:0:7}"

# ── 경로 설정 ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SITE_DIR="${PROJECT_DIR}/site"

mkdir -p "${SITE_DIR}"

# ── 각 섹션 존재 여부 확인 ──
HAS_TYPEDOC="false"
HAS_API_REF="false"
HAS_DEPLOY_GUIDE="false"
[ -d "${SITE_DIR}/typedoc" ]            && HAS_TYPEDOC="true"
[ -f "${SITE_DIR}/api-reference/index.html" ] && HAS_API_REF="true"
[ -f "${SITE_DIR}/deployment-guide/index.html" ] && HAS_DEPLOY_GUIDE="true"

# ── 카드 HTML 조각 생성 ──
typedoc_card=""
if [ "${HAS_TYPEDOC}" = "true" ]; then
  typedoc_card='<a href="typedoc/index.html" class="card card-blue">
          <div class="card-icon">📘</div>
          <div class="card-body">
            <h2>TypeDoc API 문서</h2>
            <p>TypeScript 소스 코드에서 자동 생성된 API 레퍼런스.<br>
               클래스, 인터페이스, 함수의 시그니처와 설명을 제공합니다.</p>
            <span class="card-link">문서 보기 →</span>
          </div>
        </a>'
fi

api_ref_card=""
if [ "${HAS_API_REF}" = "true" ]; then
  api_ref_card='<a href="api-reference/index.html" class="card card-green">
          <div class="card-icon">🔌</div>
          <div class="card-body">
            <h2>OpenAPI Reference</h2>
            <p>REST API 엔드포인트, 요청/응답 스키마, 인증 방식을<br>
               인터랙티브 Redoc UI로 탐색할 수 있습니다.</p>
            <span class="card-link">API 탐색 →</span>
          </div>
        </a>'
fi

deploy_card=""
if [ "${HAS_DEPLOY_GUIDE}" = "true" ]; then
  deploy_card='<a href="deployment-guide/index.html" class="card card-orange">
          <div class="card-icon">🚀</div>
          <div class="card-body">
            <h2>배포 가이드</h2>
            <p>시작하기부터 프로덕션 배포까지의 단계별 가이드.<br>
               최신 빌드 정보와 변경 사항이 자동으로 반영됩니다.</p>
            <span class="card-link">가이드 보기 →</span>
          </div>
        </a>'
fi

# ── index.html 생성 ──
cat > "${SITE_DIR}/index.html" << HTMLEOF
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="API Documentation Portal - TypeDoc, OpenAPI, Deployment Guide">
  <title>API Documentation Portal</title>
  <style>
    /* ── Reset & Base ── */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif;
      background: #0d1117;
      color: #e6edf3;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }

    /* ── Navigation ── */
    nav {
      background: #161b22;
      border-bottom: 1px solid #30363d;
      padding: 0.75rem 2rem;
      display: flex;
      align-items: center;
      gap: 1.5rem;
      position: sticky;
      top: 0;
      z-index: 100;
    }
    .nav-logo {
      font-weight: 700;
      font-size: 1.05rem;
      color: #f0f6fc;
      display: flex;
      align-items: center;
      gap: 0.5rem;
      margin-right: auto;
      text-decoration: none;
    }
    nav a {
      color: #8b949e;
      text-decoration: none;
      font-size: 0.875rem;
      transition: color 0.2s;
    }
    nav a:hover { color: #58a6ff; }

    /* ── Hero ── */
    .hero {
      background: linear-gradient(135deg, #1a1f2e 0%, #0d1117 60%);
      border-bottom: 1px solid #30363d;
      padding: 4rem 2rem 3rem;
      text-align: center;
      position: relative;
      overflow: hidden;
    }
    .hero::before {
      content: '';
      position: absolute;
      top: -50%;
      left: -50%;
      width: 200%;
      height: 200%;
      background: radial-gradient(ellipse at center, rgba(88,166,255,0.08) 0%, transparent 60%);
      pointer-events: none;
    }
    .hero-badge {
      display: inline-block;
      background: rgba(88,166,255,0.15);
      color: #58a6ff;
      border: 1px solid rgba(88,166,255,0.3);
      border-radius: 20px;
      padding: 0.25rem 0.9rem;
      font-size: 0.8rem;
      font-weight: 600;
      letter-spacing: 0.05em;
      margin-bottom: 1.2rem;
      text-transform: uppercase;
    }
    .hero h1 {
      font-size: clamp(1.8rem, 5vw, 2.8rem);
      font-weight: 800;
      color: #f0f6fc;
      margin-bottom: 0.8rem;
      letter-spacing: -0.02em;
    }
    .hero h1 span { color: #58a6ff; }
    .hero p {
      font-size: 1.05rem;
      color: #8b949e;
      max-width: 560px;
      margin: 0 auto 2rem;
      line-height: 1.6;
    }

    /* ── Build Metadata ── */
    .build-meta {
      display: flex;
      justify-content: center;
      gap: 1.5rem;
      flex-wrap: wrap;
      margin-top: 1rem;
    }
    .meta-pill {
      background: #161b22;
      border: 1px solid #30363d;
      border-radius: 6px;
      padding: 0.3rem 0.8rem;
      font-size: 0.8rem;
      color: #8b949e;
      display: flex;
      align-items: center;
      gap: 0.4rem;
    }
    .meta-pill code {
      color: #79c0ff;
      font-family: 'SFMono-Regular', Consolas, monospace;
      font-size: 0.85em;
    }

    /* ── Cards Grid ── */
    .cards-section {
      max-width: 1100px;
      margin: 0 auto;
      padding: 3rem 2rem;
      flex: 1;
    }
    .cards-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 1.5rem;
    }
    .card {
      background: #161b22;
      border: 1px solid #30363d;
      border-radius: 12px;
      padding: 2rem;
      text-decoration: none;
      color: inherit;
      display: flex;
      align-items: flex-start;
      gap: 1.2rem;
      transition: border-color 0.2s, transform 0.2s, box-shadow 0.2s;
      cursor: pointer;
    }
    .card:hover {
      transform: translateY(-3px);
      box-shadow: 0 8px 24px rgba(0,0,0,0.4);
    }
    .card-blue:hover  { border-color: #58a6ff; }
    .card-green:hover { border-color: #3fb950; }
    .card-orange:hover { border-color: #f0883e; }
    .card-purple:hover { border-color: #d2a8ff; }

    .card-icon {
      font-size: 2.5rem;
      line-height: 1;
      flex-shrink: 0;
    }
    .card-body h2 {
      font-size: 1.15rem;
      font-weight: 700;
      color: #f0f6fc;
      margin-bottom: 0.5rem;
    }
    .card-body p {
      font-size: 0.875rem;
      color: #8b949e;
      line-height: 1.6;
      margin-bottom: 1rem;
    }
    .card-link {
      font-size: 0.875rem;
      font-weight: 600;
    }
    .card-blue  .card-link { color: #58a6ff; }
    .card-green .card-link { color: #3fb950; }
    .card-orange .card-link { color: #f0883e; }

    /* ── Pipeline Section ── */
    .pipeline-section {
      background: #161b22;
      border-top: 1px solid #30363d;
      border-bottom: 1px solid #30363d;
      padding: 2.5rem 2rem;
    }
    .pipeline-inner {
      max-width: 1100px;
      margin: 0 auto;
    }
    .pipeline-inner h3 {
      font-size: 1.1rem;
      font-weight: 700;
      color: #f0f6fc;
      margin-bottom: 1.5rem;
      text-align: center;
    }
    .pipeline-steps {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 0;
      flex-wrap: wrap;
    }
    .pipeline-step {
      background: #0d1117;
      border: 1px solid #30363d;
      border-radius: 8px;
      padding: 0.6rem 1.2rem;
      font-size: 0.82rem;
      color: #8b949e;
      text-align: center;
      min-width: 120px;
    }
    .pipeline-step .step-icon { display: block; font-size: 1.4rem; margin-bottom: 0.2rem; }
    .pipeline-step .step-label { color: #f0f6fc; font-weight: 600; font-size: 0.8rem; }
    .pipeline-arrow {
      color: #30363d;
      font-size: 1.5rem;
      padding: 0 0.3rem;
    }

    /* ── Footer ── */
    footer {
      background: #161b22;
      border-top: 1px solid #30363d;
      padding: 1.5rem 2rem;
      text-align: center;
      font-size: 0.8rem;
      color: #484f58;
    }
    footer a { color: #58a6ff; text-decoration: none; }
    footer a:hover { text-decoration: underline; }

    @media (max-width: 600px) {
      .hero { padding: 2.5rem 1rem 2rem; }
      .cards-section { padding: 2rem 1rem; }
      .pipeline-steps { flex-direction: column; }
      .pipeline-arrow { transform: rotate(90deg); }
    }
  </style>
</head>
<body>
  <!-- Navigation -->
  <nav>
    <a class="nav-logo" href="index.html">📚 Docs Portal</a>
    <a href="typedoc/index.html">TypeDoc</a>
    <a href="api-reference/index.html">API Reference</a>
    <a href="deployment-guide/index.html">Deployment</a>
    <a href="https://github.com/${REPOSITORY}" target="_blank" rel="noopener">GitHub ↗</a>
  </nav>

  <!-- Hero -->
  <header class="hero">
    <div class="hero-badge">Auto-generated Documentation</div>
    <h1>API <span>Documentation</span> Portal</h1>
    <p>코드 변경 시 GitHub Actions가 자동으로 빌드하여 배포하는 통합 문서 포털입니다.</p>
    <div class="build-meta">
      <div class="meta-pill">🕐 빌드 시각: ${BUILD_DATETIME}</div>
      <div class="meta-pill">🔀 브랜치: <code>${BRANCH}</code></div>
      <div class="meta-pill">📌 커밋: <code>${SHORT_SHA}</code></div>
    </div>
  </header>

  <!-- Documentation Cards -->
  <main class="cards-section">
    <div class="cards-grid">
      ${typedoc_card}
      ${api_ref_card}
      ${deploy_card}
    </div>
  </main>

  <!-- CI/CD Pipeline Diagram -->
  <section class="pipeline-section">
    <div class="pipeline-inner">
      <h3>⚙️ 문서 자동화 파이프라인</h3>
      <div class="pipeline-steps">
        <div class="pipeline-step">
          <span class="step-icon">📝</span>
          <span class="step-label">코드 변경</span>
          push to main
        </div>
        <span class="pipeline-arrow">→</span>
        <div class="pipeline-step">
          <span class="step-icon">✅</span>
          <span class="step-label">검증</span>
          typecheck + test
        </div>
        <span class="pipeline-arrow">→</span>
        <div class="pipeline-step">
          <span class="step-icon">📘</span>
          <span class="step-label">TypeDoc</span>
          HTML 생성
        </div>
        <span class="pipeline-arrow">→</span>
        <div class="pipeline-step">
          <span class="step-icon">🔌</span>
          <span class="step-label">OpenAPI</span>
          Redoc 빌드
        </div>
        <span class="pipeline-arrow">→</span>
        <div class="pipeline-step">
          <span class="step-icon">🚀</span>
          <span class="step-label">배포 가이드</span>
          자동 갱신
        </div>
        <span class="pipeline-arrow">→</span>
        <div class="pipeline-step">
          <span class="step-icon">🌐</span>
          <span class="step-label">GitHub Pages</span>
          자동 배포
        </div>
      </div>
    </div>
  </section>

  <!-- Footer -->
  <footer>
    <p>
      자동 생성 문서 &bull;
      <a href="https://github.com/${REPOSITORY}" target="_blank" rel="noopener">
        github.com/${REPOSITORY}
      </a>
      &bull; 빌드: ${BUILD_DATETIME}
    </p>
  </footer>
</body>
</html>
HTMLEOF

success "통합 포털 생성 완료: ${SITE_DIR}/index.html"

# ── .nojekyll (GitHub Pages Jekyll 비활성화) ──
touch "${SITE_DIR}/.nojekyll"
success ".nojekyll 생성 완료"

# ── 사이트 구조 출력 ──
echo ""
echo "  site/ 구조:"
find "${SITE_DIR}" -maxdepth 2 \( -name "*.html" -o -name ".nojekyll" \) \
  | sort | sed "s|${SITE_DIR}|    |"
