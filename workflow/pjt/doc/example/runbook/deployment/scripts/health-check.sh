#!/bin/bash

# Health check script for all environments
# Usage: ./health-check.sh [environment]

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

log "Starting health check for $ENVIRONMENT environment"
log "Base URL: $BASE_URL"

# Health check endpoints
ENDPOINTS=(
    "/health"
    "/api/v1/status"
    "/api/v1/metrics"
)

FAILED_CHECKS=0

# Check each endpoint
for endpoint in "${ENDPOINTS[@]}"; do
    url="${BASE_URL}${endpoint}"
    log "Checking: $url"
    
    response=$(curl -s -w "HTTPSTATUS:%{http_code}\nTIME:%{time_total}" "$url" || echo "CURL_ERROR")
    
    if [[ "$response" == "CURL_ERROR" ]]; then
        error "Failed to connect to $url"
        ((FAILED_CHECKS++))
        continue
    fi
    
    http_code=$(echo "$response" | grep "HTTPSTATUS:" | cut -d: -f2)
    time_total=$(echo "$response" | grep "TIME:" | cut -d: -f2)
    body=$(echo "$response" | grep -v "HTTPSTATUS:\|TIME:")
    
    if [[ "$http_code" -eq 200 ]]; then
        success "✓ $endpoint (${http_code}) - ${time_total}s"
        
        # Additional checks for specific endpoints
        if [[ "$endpoint" == "/health" ]]; then
            if echo "$body" | grep -q '"status":"healthy"'; then
                success "  Health status: OK"
            else
                warning "  Health status check failed"
                ((FAILED_CHECKS++))
            fi
        fi
    else
        error "✗ $endpoint failed (HTTP $http_code)"
        ((FAILED_CHECKS++))
    fi
done

# Database connectivity check
log "Checking database connectivity..."
if curl -s "${BASE_URL}/api/v1/db-check" | grep -q '"database":"connected"'; then
    success "✓ Database connection: OK"
else
    error "✗ Database connection: FAILED"
    ((FAILED_CHECKS++))
fi

# Redis connectivity check  
log "Checking Redis connectivity..."
if curl -s "${BASE_URL}/api/v1/cache-check" | grep -q '"cache":"connected"'; then
    success "✓ Redis connection: OK"
else
    error "✗ Redis connection: FAILED"
    ((FAILED_CHECKS++))
fi

# Memory and CPU usage check (production only)
if [[ "$ENVIRONMENT" == "production" ]]; then
    log "Checking system resources..."
    metrics_response=$(curl -s "${BASE_URL}/api/v1/metrics")
    
    memory_usage=$(echo "$metrics_response" | grep -o '"memory_usage":[0-9.]*' | cut -d: -f2)
    cpu_usage=$(echo "$metrics_response" | grep -o '"cpu_usage":[0-9.]*' | cut -d: -f2)
    
    if (( $(echo "$memory_usage > 85" | bc -l) )); then
        warning "High memory usage: ${memory_usage}%"
        ((FAILED_CHECKS++))
    else
        success "✓ Memory usage: ${memory_usage}%"
    fi
    
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        warning "High CPU usage: ${cpu_usage}%"
        ((FAILED_CHECKS++))
    else
        success "✓ CPU usage: ${cpu_usage}%"
    fi
fi

# Load balancer health check (production)
if [[ "$ENVIRONMENT" == "production" ]]; then
    log "Checking load balancer endpoints..."
    
    # Check multiple instances if available
    for i in {1..3}; do
        instance_url="https://api-${i}.runbook.com/health"
        if curl -s --max-time 5 "$instance_url" | grep -q '"status":"healthy"'; then
            success "✓ Instance $i: OK"
        else
            warning "Instance $i: Not responding"
        fi
    done
fi

# SSL certificate check (production)
if [[ "$ENVIRONMENT" == "production" ]]; then
    log "Checking SSL certificate..."
    cert_info=$(echo | openssl s_client -servername api.runbook.com -connect api.runbook.com:443 2>/dev/null | openssl x509 -noout -dates)
    
    if echo "$cert_info" | grep -q "notAfter"; then
        not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
        success "✓ SSL certificate valid until: $not_after"
    else
        error "✗ SSL certificate check failed"
        ((FAILED_CHECKS++))
    fi
fi

# Log aggregation check
log "Checking log aggregation..."
if [[ "$ENVIRONMENT" == "production" ]]; then
    # Check if logs are being properly aggregated
    recent_logs=$(kubectl logs deployment/runbook-api -n production --since=5m 2>/dev/null | wc -l)
    if [[ "$recent_logs" -gt 0 ]]; then
        success "✓ Log aggregation: $recent_logs recent log entries"
    else
        warning "No recent logs found"
    fi
fi

# Final health check summary
log "Health check completed"
if [[ $FAILED_CHECKS -eq 0 ]]; then
    success "All health checks passed! 🎉"
    exit 0
else
    error "$FAILED_CHECKS health check(s) failed"
    exit 1
fi