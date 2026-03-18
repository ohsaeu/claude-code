#!/usr/bin/env bash
# =============================================================================
# generate-docs.sh
# 모든 문서를 로컬에서 생성하는 메인 스크립트
# 사용법: ./scripts/generate-docs.sh [--html] [--open]
#   --html  : GitHub Pages용 HTML 사이트도 함께 빌드
#   --open  : 빌드 후 브라우저로 열기
# =============================================================================
set -euo pipefail

# ── 색상 출력 헬퍼 ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✓${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✗${NC}  $*" >&2; }
step()    { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }

# ── 경로 설정 ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_DIR}/../../.." && pwd)"
OPENAPI_YAML="${REPO_ROOT}/week3/Fri/api_doc/openapi.yaml"
GETTING_STARTED="${REPO_ROOT}/week3/Fri/getting_started/GETTING_STARTED.md"

# ── 옵션 파싱 ──
BUILD_HTML=false
OPEN_BROWSER=false
for arg in "$@"; do
  case $arg in
    --html)  BUILD_HTML=true ;;
    --open)  OPEN_BROWSER=true ;;
    --help)
      echo "Usage: $0 [--html] [--open]"
      echo "  --html  GitHub Pages용 HTML 사이트 빌드"
      echo "  --open  빌드 후 브라우저로 열기"
      exit 0 ;;
  esac
done

echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Documentation Generator v1.0       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""

cd "${PROJECT_DIR}"

# ── 사전 검사 ──
step "사전 요구사항 검사"

if ! command -v node &>/dev/null; then
  error "Node.js가 설치되지 않았습니다. https://nodejs.org 에서 설치하세요."
  exit 1
fi
success "Node.js $(node --version) 확인"

if [ ! -d "node_modules" ]; then
  info "의존성 설치 중..."
  npm ci --silent
fi
success "node_modules 확인"

if [ ! -f "${OPENAPI_YAML}" ]; then
  warn "openapi.yaml을 찾을 수 없습니다: ${OPENAPI_YAML}"
  warn "OpenAPI 문서 생성을 건너뜁니다."
  SKIP_OPENAPI=true
else
  SKIP_OPENAPI=false
  success "openapi.yaml 확인"
fi

# ── TypeScript 검증 ──
step "TypeScript 검증"
if npm run typecheck --silent 2>&1; then
  success "타입 체크 통과"
else
  error "타입 체크 실패. 문서 생성을 중단합니다."
  exit 1
fi

# ── TypeDoc Markdown 생성 (docs/ 폴더) ──
step "TypeDoc Markdown 생성 → docs/"
npm run docs
success "docs/ 에 Markdown 문서 생성 완료"
echo "  생성된 파일: $(find docs -name '*.md' | wc -l)개"

# ── HTML 사이트 빌드 ──
if [ "${BUILD_HTML}" = "true" ]; then
  step "HTML 사이트 빌드 → site/"

  # TypeDoc HTML
  info "TypeDoc HTML 생성 중..."
  mkdir -p site/typedoc
  npx typedoc \
    --plugin none \
    --theme default \
    --out site/typedoc \
    --name "API Documentation" \
    --includeVersion \
    --readme README.md \
    --excludePrivate \
    --excludeExternals \
    src/api/index.ts \
    src/api/types.ts \
    src/api/errors.ts \
    src/api/payment.service.ts \
    src/api/user.service.ts \
    src/api/order.service.ts
  success "TypeDoc HTML → site/typedoc/"

  # OpenAPI HTML
  if [ "${SKIP_OPENAPI}" = "false" ]; then
    info "OpenAPI HTML 생성 중 (Redoc)..."
    if ! command -v npx &>/dev/null || ! npx --yes @redocly/cli --version &>/dev/null 2>&1; then
      warn "@redocly/cli를 설치합니다..."
      npm install -g @redocly/cli
    fi
    mkdir -p site/api-reference
    npx @redocly/cli build-docs \
      "${OPENAPI_YAML}" \
      --output site/api-reference/index.html \
      --title "API Reference"
    success "OpenAPI HTML → site/api-reference/"
  fi

  # 배포 가이드 HTML
  if [ -f "${GETTING_STARTED}" ]; then
    info "배포 가이드 HTML 생성 중..."
    bash "${SCRIPT_DIR}/update-deployment-guide.sh" \
      "$(git rev-parse HEAD 2>/dev/null || echo 'local')" \
      "$(git branch --show-current 2>/dev/null || echo 'main')" \
      "$(date '+%Y-%m-%d %H:%M:%S %Z')" \
      "$(git config user.name 2>/dev/null || echo 'developer')"
    success "배포 가이드 업데이트 완료"
  else
    warn "GETTING_STARTED.md를 찾을 수 없습니다: ${GETTING_STARTED}"
  fi

  # 통합 포털
  info "통합 포털 빌드 중..."
  bash "${SCRIPT_DIR}/build-docs-site.sh" \
    "$(git rev-parse HEAD 2>/dev/null || echo 'local')" \
    "$(git branch --show-current 2>/dev/null || echo 'main')" \
    "$(date '+%Y-%m-%d %H:%M:%S %Z')" \
    "local/repository"

  success "통합 사이트 → site/"
fi

# ── 결과 요약 ──
step "생성 완료"
echo ""
echo -e "  ${GREEN}Markdown 문서:${NC}  $(pwd)/docs/"
if [ "${BUILD_HTML}" = "true" ]; then
  echo -e "  ${GREEN}HTML 사이트:${NC}    $(pwd)/site/"
  echo -e "  ${GREEN}  TypeDoc:${NC}      $(pwd)/site/typedoc/index.html"
  echo -e "  ${GREEN}  API Reference:${NC} $(pwd)/site/api-reference/index.html"
  echo -e "  ${GREEN}  Deployment:${NC}   $(pwd)/site/deployment-guide/index.html"
  echo -e "  ${GREEN}  Portal:${NC}       $(pwd)/site/index.html"
fi
echo ""
echo -e "  로컬 미리보기: ${CYAN}npm run docs:serve${NC}"
if [ "${BUILD_HTML}" = "true" ]; then
  echo -e "  HTML 미리보기: ${CYAN}npx http-server site -p 3001 -o${NC}"
fi

# ── 브라우저 열기 ──
if [ "${OPEN_BROWSER}" = "true" ] && [ "${BUILD_HTML}" = "true" ]; then
  PORTAL="${PROJECT_DIR}/site/index.html"
  if command -v xdg-open &>/dev/null; then
    xdg-open "${PORTAL}"
  elif command -v open &>/dev/null; then
    open "${PORTAL}"
  fi
fi

echo ""
success "모든 문서 생성 완료!"
