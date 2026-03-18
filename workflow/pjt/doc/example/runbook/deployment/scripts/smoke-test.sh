#!/bin/bash

# Smoke test script for all environments
# Usage: ./smoke-test.sh [environment]

ENVIRONMENT=${1:-development}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Environment-specific URLs
case $ENVIRONMENT in
    development)
        BASE_URL="http://localhost:3000"
        ;;
    staging)
        BASE_URL="http://staging.runbook-api.com"
        ;;
    production)
        BASE_URL="https://api.runbook.com"
        ;;
    *)
        error "Invalid environment: $ENVIRONMENT"
        ;;
esac

log "Starting smoke tests for $ENVIRONMENT environment"
log "Base URL: $BASE_URL"

FAILED_TESTS=0

# Test 1: Basic API endpoint
log "Test 1: Basic API endpoint"
response=$(curl -s -w "HTTPSTATUS:%{http_code}" "${BASE_URL}/api/v1/ping")
http_code=$(echo "$response" | grep "HTTPSTATUS:" | cut -d: -f2)
body=$(echo "$response" | grep -v "HTTPSTATUS:")

if [[ "$http_code" -eq 200 ]] && echo "$body" | grep -q "pong"; then
    success "✓ Basic API endpoint working"
else
    error "✗ Basic API endpoint failed (HTTP $http_code)"
    ((FAILED_TESTS++))
fi

# Test 2: Database connection
log "Test 2: Database operations"
# Create test record
create_response=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{"name":"smoke-test-'$TIMESTAMP'","type":"test"}' \
    -w "HTTPSTATUS:%{http_code}" \
    "${BASE_URL}/api/v1/test-records")

create_code=$(echo "$create_response" | grep "HTTPSTATUS:" | cut -d: -f2)
create_body=$(echo "$create_response" | grep -v "HTTPSTATUS:")

if [[ "$create_code" -eq 201 ]]; then
    success "✓ Database create operation working"
    
    # Extract ID for cleanup
    test_id=$(echo "$create_body" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    
    # Test read operation
    read_response=$(curl -s -w "HTTPSTATUS:%{http_code}" "${BASE_URL}/api/v1/test-records/${test_id}")
    read_code=$(echo "$read_response" | grep "HTTPSTATUS:" | cut -d: -f2)
    
    if [[ "$read_code" -eq 200 ]]; then
        success "✓ Database read operation working"
        
        # Cleanup test record
        delete_response=$(curl -s -X DELETE -w "HTTPSTATUS:%{http_code}" "${BASE_URL}/api/v1/test-records/${test_id}")
        delete_code=$(echo "$delete_response" | grep "HTTPSTATUS:" | cut -d: -f2)
        
        if [[ "$delete_code" -eq 200 ]]; then
            success "✓ Database delete operation working"
        else
            warning "Database cleanup failed (non-critical)"
        fi
    else
        error "✗ Database read operation failed"
        ((FAILED_TESTS++))
    fi
else
    error "✗ Database create operation failed (HTTP $create_code)"
    ((FAILED_TESTS++))
fi

# Test 3: Authentication flow
log "Test 3: Authentication flow"
auth_response=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{"username":"smoketest","password":"test123"}' \
    -w "HTTPSTATUS:%{http_code}" \
    "${BASE_URL}/api/v1/auth/login")

auth_code=$(echo "$auth_response" | grep "HTTPSTATUS:" | cut -d: -f2)
auth_body=$(echo "$auth_response" | grep -v "HTTPSTATUS:")

if [[ "$auth_code" -eq 200 ]] && echo "$auth_body" | grep -q "token"; then
    success "✓ Authentication working"
    
    # Extract token for protected endpoint test
    token=$(echo "$auth_body" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    # Test protected endpoint
    protected_response=$(curl -s -H "Authorization: Bearer $token" \
        -w "HTTPSTATUS:%{http_code}" \
        "${BASE_URL}/api/v1/protected/profile")
    
    protected_code=$(echo "$protected_response" | grep "HTTPSTATUS:" | cut -d: -f2)
    
    if [[ "$protected_code" -eq 200 ]]; then
        success "✓ Protected endpoint access working"
    else
        error "✗ Protected endpoint access failed"
        ((FAILED_TESTS++))
    fi
else
    error "✗ Authentication failed (HTTP $auth_code)"
    ((FAILED_TESTS++))
fi

# Test 4: Cache operations (Redis)
log "Test 4: Cache operations"
cache_key="smoke-test-$TIMESTAMP"
cache_value="test-value-$TIMESTAMP"

# Set cache
cache_set_response=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"key\":\"$cache_key\",\"value\":\"$cache_value\",\"ttl\":60}" \
    -w "HTTPSTATUS:%{http_code}" \
    "${BASE_URL}/api/v1/cache")

cache_set_code=$(echo "$cache_set_response" | grep "HTTPSTATUS:" | cut -d: -f2)

if [[ "$cache_set_code" -eq 200 ]]; then
    success "✓ Cache set operation working"
    
    # Get cache
    cache_get_response=$(curl -s -w "HTTPSTATUS:%{http_code}" "${BASE_URL}/api/v1/cache/${cache_key}")
    cache_get_code=$(echo "$cache_get_response" | grep "HTTPSTATUS:" | cut -d: -f2)
    cache_get_body=$(echo "$cache_get_response" | grep -v "HTTPSTATUS:")
    
    if [[ "$cache_get_code" -eq 200 ]] && echo "$cache_get_body" | grep -q "$cache_value"; then
        success "✓ Cache get operation working"
        
        # Delete cache
        curl -s -X DELETE "${BASE_URL}/api/v1/cache/${cache_key}" > /dev/null
    else
        error "✗ Cache get operation failed"
        ((FAILED_TESTS++))
    fi
else
    error "✗ Cache set operation failed"
    ((FAILED_TESTS++))
fi

# Test 5: File upload (if endpoint exists)
log "Test 5: File upload"
temp_file=$(mktemp)
echo "Smoke test file content" > "$temp_file"

upload_response=$(curl -s -X POST -F "file=@$temp_file" \
    -w "HTTPSTATUS:%{http_code}" \
    "${BASE_URL}/api/v1/upload")

upload_code=$(echo "$upload_response" | grep "HTTPSTATUS:" | cut -d: -f2)

if [[ "$upload_code" -eq 200 ]]; then
    success "✓ File upload working"
elif [[ "$upload_code" -eq 404 ]]; then
    log "File upload endpoint not available (skipped)"
else
    error "✗ File upload failed (HTTP $upload_code)"
    ((FAILED_TESTS++))
fi

rm -f "$temp_file"

# Test 6: WebSocket connection (if supported)
log "Test 6: WebSocket connection"
if command -v wscat &> /dev/null; then
    ws_url="${BASE_URL/http/ws}/ws"
    timeout 5 wscat -c "$ws_url" -x '{"type":"ping"}' 2>/dev/null | grep -q "pong"
    if [[ $? -eq 0 ]]; then
        success "✓ WebSocket connection working"
    else
        warning "WebSocket connection test failed (non-critical)"
    fi
else
    log "wscat not available, skipping WebSocket test"
fi

# Test 7: Rate limiting
log "Test 7: Rate limiting"
rate_limit_failures=0
for i in {1..10}; do
    rate_response=$(curl -s -w "HTTPSTATUS:%{http_code}" "${BASE_URL}/api/v1/ping")
    rate_code=$(echo "$rate_response" | grep "HTTPSTATUS:" | cut -d: -f2)
    if [[ "$rate_code" -eq 429 ]]; then
        success "✓ Rate limiting working (received 429 after $i requests)"
        break
    fi
    sleep 0.1
done

# Test 8: Error handling
log "Test 8: Error handling"
error_response=$(curl -s -w "HTTPSTATUS:%{http_code}" "${BASE_URL}/api/v1/nonexistent")
error_code=$(echo "$error_response" | grep "HTTPSTATUS:" | cut -d: -f2)

if [[ "$error_code" -eq 404 ]]; then
    success "✓ 404 error handling working"
else
    warning "Unexpected response for non-existent endpoint: HTTP $error_code"
fi

# Test 9: CORS headers (if applicable)
log "Test 9: CORS headers"
cors_response=$(curl -s -H "Origin: https://example.com" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: X-Requested-With" \
    -X OPTIONS \
    -I "${BASE_URL}/api/v1/ping")

if echo "$cors_response" | grep -q "Access-Control-Allow-Origin"; then
    success "✓ CORS headers present"
else
    log "CORS headers not found (may not be configured)"
fi

# Test 10: Environment-specific test
case $ENVIRONMENT in
    production)
        log "Test 10: Production-specific checks"
        
        # Check HTTPS redirect
        http_response=$(curl -s -w "HTTPSTATUS:%{http_code}" "http://api.runbook.com/health")
        http_code=$(echo "$http_response" | grep "HTTPSTATUS:" | cut -d: -f2)
        
        if [[ "$http_code" -eq 301 || "$http_code" -eq 302 ]]; then
            success "✓ HTTP to HTTPS redirect working"
        else
            warning "HTTP to HTTPS redirect may not be configured"
        fi
        
        # Check security headers
        security_headers=$(curl -s -I "${BASE_URL}/api/v1/ping")
        if echo "$security_headers" | grep -q "X-Frame-Options\|Content-Security-Policy"; then
            success "✓ Security headers present"
        else
            warning "Security headers not found"
        fi
        ;;
    *)
        log "Test 10: Environment-specific tests (skipped for $ENVIRONMENT)"
        ;;
esac

# Final smoke test summary
log "Smoke tests completed"
if [[ $FAILED_TESTS -eq 0 ]]; then
    success "All smoke tests passed! 🚀"
    exit 0
else
    error "$FAILED_TESTS smoke test(s) failed"
    exit 1
fi